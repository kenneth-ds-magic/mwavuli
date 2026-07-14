import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/camera/photo_capture.dart';
import '../../core/id/identification_service.dart';
import '../../core/location/location_service.dart';
import '../../core/location/nominatim_geocode.dart';
import '../../core/offline/sync_service.dart';
import '../../core/prefs/user_prefs.dart';
import '../../data/models/species.dart';
import '../../data/models/tree.dart';
import '../../data/repositories/explore_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/tree_repository.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/map/map_tile_layer.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../../widgets/tree_photo.dart';

/// Five-step capture flow: photo → identify → describe → location → success.
class LogFlow extends ConsumerStatefulWidget {
  const LogFlow({super.key});
  @override
  ConsumerState<LogFlow> createState() => _LogFlowState();
}

class _LogFlowState extends ConsumerState<LogFlow> {
  int _step = 0; // 0..4
  bool _identifying = false;
  bool _submitting = false;
  String? _identifyError;
  List<SpeciesCandidate> _candidates = const [];
  IdentifySource? _identifySource;
  bool _manualId = false;
  int _selected = 0;
  final List<CapturedPhoto> _photos = [];
  LogSubmitResult? _result;

  final _commonNameCtrl = TextEditingController();
  final _scientificCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Form state
  TreeHealth _health = TreeHealth.healthy;
  double _height = 12;
  final Set<String> _features = {};
  bool _fuzzy = true;
  TreeVisibility _visibility = TreeVisibility.public;
  LatLng? _location;
  double? _locationAccuracyM;
  /// Preview-only fuzz point for the map circle (never submitted as lat/lng).
  LatLng? _previewPublishPoint;
  bool _loadingLocation = false;
  /// How the current pin was set: gps | lastKnown | map | search
  String _locationSource = 'gps';
  final _locMapController = MapController();
  final _placeSearchCtrl = TextEditingController();
  static const _defaultMapCenter = LatLng(43.6489, -79.3817);

  static const _organOptions = [
    ('whole', '🌳 Tree'),
    ('bark', '🪵 Bark'),
    ('leaf', '🍃 Leaf'),
    ('flower', '🌸 Flower'),
    ('fruit', '🌰 Fruit'),
  ];

  static const _featureOptions = [
    ('Flowering', '🌸 Flowering'),
    ('Fruiting', '🌰 Fruiting'),
    ('Hollow', '🕳️ Hollow'),
    ('Heritage', '🏛️ Heritage'),
    ('Wildlife habitat', '🦉 Wildlife habitat'),
  ];

  static const _labels = [
    'Step 1 of 5 · Capture photos',
    'Step 2 of 5 · Confirm the ID',
    'Step 3 of 5 · Describe the tree',
    'Step 4 of 5 · Location & privacy',
    'All done!',
  ];

  @override
  void initState() {
    super.initState();
    Future(() async {
      final v = await ref.read(userPrefsProvider).defaultFuzzyLocation();
      if (mounted) setState(() => _fuzzy = v);
    });
  }

  @override
  void dispose() {
    _commonNameCtrl.dispose();
    _scientificCtrl.dispose();
    _notesCtrl.dispose();
    _placeSearchCtrl.dispose();
    _locMapController.dispose();
    super.dispose();
  }

  bool get _authenticated =>
      ref.read(authControllerProvider) == AuthStatus.authenticated;

  Future<void> _identify() async {
    if (!_authenticated) {
      _promptLogin();
      return;
    }
    if (_photos.isEmpty) {
      setState(() => _identifyError = 'Add at least one photo first.');
      return;
    }
    setState(() {
      _step = 1;
      _identifying = true;
      _identifyError = null;
      _manualId = false;
      _identifySource = null;
      _candidates = const [];
    });
    try {
      final res =
          await ref.read(identificationServiceProvider).identifyPhotos(_photos);
      if (!mounted) return;
      setState(() {
        _candidates = res.candidates;
        _identifySource = res.source;
        _selected = 0;
        _identifying = false;
        _manualId = res.candidates.isEmpty;
        if (res.candidates.isNotEmpty) {
          _commonNameCtrl.text = res.candidates[0].commonName;
          _scientificCtrl.text = res.candidates[0].scientificName;
        } else {
          _commonNameCtrl.clear();
          _scientificCtrl.clear();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _identifying = false;
        _candidates = const [];
        _identifySource = IdentifySource.unavailable;
        _manualId = true;
        _identifyError =
            'Could not reach the identification service. Enter the species manually or try again.';
      });
    }
  }

  /// Capture (or pick) a photo and strip EXIF on-device. Identification runs
  /// only when the user taps Continue on step 1.
  Future<void> _capturePhoto({bool fromGallery = false, String? organ}) async {
    if (!_authenticated) {
      _promptLogin();
      return;
    }
    final nextOrgan = organ ??
        (_photos.isEmpty
            ? 'whole'
            : (_photos.length == 1 ? 'bark' : 'leaf'));
    try {
      final photo = await ref
          .read(photoCaptureProvider)
          .pick(organ: nextOrgan, fromGallery: fromGallery);
      if (photo == null) return;
      setState(() {
        _photos.add(photo);
        _identifyError = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access camera or gallery.')),
        );
      }
    }
  }

  Future<void> _loadLocation({bool force = false}) async {
    if (_loadingLocation) return;
    if (!force && _location != null) return;
    setState(() => _loadingLocation = true);
    final svc = ref.read(locationServiceProvider);
    final gps = await svc.currentFix();
    final fix = gps ?? await svc.lastKnownFix();
    if (!mounted) return;
    setState(() => _loadingLocation = false);
    if (fix != null) {
      _setLocation(
        fix,
        source: gps != null ? 'gps' : 'lastKnown',
      );
    }
  }

  void _setLocation(DeviceLocation fix, {required String source}) {
    final svc = ref.read(locationServiceProvider);
    setState(() {
      _location = fix.point;
      _locationAccuracyM = fix.accuracyM;
      _locationSource = source;
      _previewPublishPoint =
          _fuzzy ? svc.fuzz(fix.point) : fix.point;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _locMapController.move(fix.point, _fuzzy ? 14.5 : 16);
      } catch (_) {}
    });
  }

  void _setLocationFromPoint(LatLng point, {required String source}) {
    _setLocation(DeviceLocation(point), source: source);
  }

  void _refreshFuzzyPreview() {
    final loc = _location;
    if (loc == null) return;
    final svc = ref.read(locationServiceProvider);
    setState(() {
      _previewPublishPoint = _fuzzy ? svc.fuzz(loc) : loc;
    });
  }

  String _coordLabel(LatLng loc) {
    if (_fuzzy) {
      // Do not show full precision while fuzzy publishing is on.
      return '${loc.latitude.toStringAsFixed(2)}°, '
          '${loc.longitude.toStringAsFixed(2)}° (±500 m)';
    }
    return '${loc.latitude.toStringAsFixed(5)}°, '
        '${loc.longitude.toStringAsFixed(5)}°';
  }

  String get _locationSourceLabel => switch (_locationSource) {
        'lastKnown' => 'Last known',
        'map' => 'Map pin',
        'search' => 'Search',
        _ => 'GPS',
      };

  void _promptLogin() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log in required'),
        content: const Text(
            'Create an account or log in to identify and submit trees.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/login');
            },
            child: const Text('Log in'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_authenticated) {
      _promptLogin();
      return;
    }
    if (_submitting) return;

    final commonName = _commonNameCtrl.text.trim();
    if (commonName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a species name before submitting.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final offline = ref.read(offlineModeProvider);
    final cand = _candidates.isNotEmpty
        ? _candidates[_selected]
        : SpeciesCandidate(
            commonName: commonName,
            scientificName: _scientificCtrl.text.trim(),
            confidence: 0,
            photoTag: speciesPhotoTag(commonName),
          );
    final loc = _location;
    DeviceLocation? resolved;
    if (loc == null) {
      final svc = ref.read(locationServiceProvider);
      resolved = await svc.currentFix() ?? await svc.lastKnownFix();
      if (resolved != null && mounted) {
        _setLocation(
          resolved,
          source: 'gps',
        );
      }
    }
    final submitLoc = _location ?? resolved?.point;
    final submitAccuracy = _locationAccuracyM ?? resolved?.accuracyM;
    if (submitLoc == null) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Set a location: enable GPS, use last known, search a place, '
              'or tap the map.',
            ),
          ),
        );
      }
      return;
    }

    final body = <String, dynamic>{
      'commonName': commonName,
      if (_scientificCtrl.text.trim().isNotEmpty)
        'scientificName': _scientificCtrl.text.trim(),
      'health': _health.name,
      if (_height > 0) 'heightM': _height.round(),
      'features': _features.toList(),
      if (cand.confidence > 0) 'confidence': cand.confidence,
      if (_notesCtrl.text.trim().isNotEmpty) 'description': _notesCtrl.text.trim(),
      'visibility': _visibility.name,
      'isFuzzy': _fuzzy,
      'lat': submitLoc.latitude,
      'lng': submitLoc.longitude,
      if (submitAccuracy != null) 'accuracyM': submitAccuracy,
      'photos': _photos
          .map((p) => {'organ': p.organ, 'contentType': p.contentType})
          .toList(),
    };

    try {
      if (offline) {
        await _queue(body);
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _result = LogSubmitResult(
            treeId: '',
            commonName: commonName,
            queued: true,
            isFuzzy: _fuzzy,
            visibility: _visibility,
          );
          _step = 4;
        });
        return;
      }

      final res = await ref.read(apiClientProvider).createTree(body);
      final uploads = (res['uploads'] as List?) ?? const [];
      final api = ref.read(apiClientProvider);
      var uploaded = 0;
      for (var i = 0; i < uploads.length && i < _photos.length; i++) {
        final upload = (uploads[i] as Map).cast<String, dynamic>();
        final photoId = upload['photoId'] as String?;
        if (photoId == null) continue;
        // Full-resolution capture bytes — PlantNet thumbnails are never
        // written back into [_photos].
        await api.uploadPhoto(
          photoId,
          _photos[i].bytes,
          contentType: _photos[i].contentType,
        );
        uploaded++;
      }
      if (uploads.isNotEmpty && uploaded == 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tree saved, but photos failed to upload. Try again later.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      final tree = (res['tree'] as Map).cast<String, dynamic>();
      final rewards = LogRewards.fromApi(
          (res['rewards'] as Map?)?.cast<String, dynamic>());
      ref.invalidate(profileProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(exploreProvider);
      ref.invalidate(exploreFeedProvider);
      ref.invalidate(mapFeedProvider);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = LogSubmitResult(
          treeId: tree['id'] as String,
          commonName: tree['commonName'] as String? ?? commonName,
          rewards: rewards,
          isFuzzy: _fuzzy,
          visibility: _visibility,
        );
        _step = 4;
      });
    } catch (e) {
      // Prefer surfacing upload/create failures over silent offline queue
      // when we already reached the API for identify earlier in the session.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save tree: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      try {
        await _queue(body);
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _result = LogSubmitResult(
            treeId: '',
            commonName: commonName,
            queued: true,
            isFuzzy: _fuzzy,
            visibility: _visibility,
          );
          _step = 4;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _queue(Map<String, dynamic> body) async {
    final cache = ref.read(photoCacheProvider);
    final paths = <String>[];
    for (final p in _photos) {
      paths.add(await cache.save(p.bytes));
    }
    final n = await ref.read(syncServiceProvider).enqueue(body, paths);
    ref.read(syncQueueProvider.notifier).state = n;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth == AuthStatus.unauthenticated) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.eco_outlined, size: 56, color: Palette.green700),
                const SizedBox(height: 16),
                Text('Log in to record a tree',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text(
                  'Tree logs are tied to your account so you can earn points and '
                  'keep your collection.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Log in'),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_step == 3 && _location == null && !_loadingLocation) {
      _loadLocation();
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(child: _stepBody(context)),
            if (_step >= 0 && _step <= 3) _actions(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close_rounded)),
            Text(_step == 4 ? 'Success' : 'Log a tree',
                style: Theme.of(context).textTheme.titleLarge),
          ]),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Container(
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i < _step
                          ? Palette.green500
                          : i == _step
                              ? Palette.green700
                              : Palette.cream200,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Text(_labels[_step],
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF77694F))),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(BuildContext context) {
    return switch (_step) {
      0 => _capture(context),
      1 => _identifyStep(context),
      2 => _describe(context),
      3 => _locationStep(context),
      _ => _success(context),
    };
  }

  // ---- Step 1: capture -------------------------------------------------
  Widget _capture(BuildContext context) {
    final preview = _photos.isNotEmpty ? _photos.last.bytes : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      child: Column(children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: const Color(0xFF1F4715),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              if (preview != null)
                Positioned.fill(
                  child: Image.memory(preview, fit: BoxFit.cover),
                )
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Palette.green600, Palette.green900]),
                  ),
                ),
              const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: _Hint('Fit the whole tree in the frame'),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final (key, label) in _organOptions)
                        _Organ(
                          label,
                          got: _photos.any((p) => p.organ == key),
                        ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
        if (_identifyError != null) ...[
          const SizedBox(height: 10),
          Text(_identifyError!,
              style: const TextStyle(color: Palette.danger, fontSize: 12.5)),
        ],
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundBtn(Icons.photo_library_outlined,
                () => _capturePhoto(fromGallery: true)),
            const SizedBox(width: 34),
            _Shutter(onTap: () => _capturePhoto()),
            const SizedBox(width: 34),
            _RoundBtn(Icons.add_a_photo_outlined,
                () => _capturePhoto(fromGallery: true, organ: 'leaf')),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Capture the whole tree, then close-ups of bark, a leaf and any '
          'flowers or fruit. More angles = a more confident ID.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: context.earth.ink3, height: 1.5),
        ),
      ]),
    );
  }

  // ---- Step 2: identify ------------------------------------------------
  Widget _identifyStep(BuildContext context) {
    if (_identifying) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Identifying with Pl@ntNet…'),
          ],
        ),
      );
    }

    final earth = context.earth;
    final showManual = _manualId || _candidates.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      children: [
        if (_photos.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(_photos.first.bytes,
                height: 150, width: double.infinity, fit: BoxFit.cover),
          )
        else
          TreePhoto(
            _candidates.isNotEmpty
                ? _candidates[_selected].photoTag
                : speciesPhotoTag(_commonNameCtrl.text),
            height: 150,
            borderRadius: BorderRadius.circular(16),
          ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
              color: Palette.green50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.green100)),
          child: const Row(children: [
            Icon(Icons.auto_awesome, size: 16, color: Palette.green800),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Suggestions from Pl@ntNet. Pick the best match, or enter '
                  'the species yourself if none fit.',
                  style: TextStyle(fontSize: 12, color: Palette.green800)),
            ),
          ]),
        ),
        if (_identifySource == IdentifySource.stub)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8C98A)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF8A5A00)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Demo IDs only — Pl@ntNet is not configured on this server. '
                  'Confirm carefully or enter the species manually.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A5A00)),
                ),
              ),
            ]),
          ),
        if (_identifySource == IdentifySource.unavailable &&
            _candidates.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFFCEEEA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8B4A8)),
            ),
            child: Row(children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 18, color: Palette.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _identifyError ??
                      'No matches returned. Enter the species manually, or go back and try again.',
                  style: const TextStyle(fontSize: 12, color: Palette.danger),
                ),
              ),
            ]),
          ),
        if (_candidates.isNotEmpty && !showManual) ...[
          for (var i = 0; i < _candidates.length; i++)
            _CandidateTile(
              c: _candidates[i],
              selected: _selected == i,
              onTap: () => setState(() {
                _selected = i;
                _manualId = false;
                _commonNameCtrl.text = _candidates[i].commonName;
                _scientificCtrl.text = _candidates[i].scientificName;
              }),
            ),
          TextButton(
            onPressed: () => setState(() {
              _manualId = true;
              _commonNameCtrl.clear();
              _scientificCtrl.clear();
            }),
            child: Text('None of these — enter manually',
                style: TextStyle(
                    color: earth.ink2, fontWeight: FontWeight.w700)),
          ),
        ],
        if (showManual) ...[
          if (_candidates.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  _manualId = false;
                  _commonNameCtrl.text = _candidates[_selected].commonName;
                  _scientificCtrl.text = _candidates[_selected].scientificName;
                }),
                child: const Text('Back to suggestions',
                    style: TextStyle(
                        color: Palette.green700, fontWeight: FontWeight.w700)),
              ),
            ),
          _field('Common name', _commonNameCtrl),
          _field('Scientific name', _scientificCtrl, italic: true),
          Text(
            'You can refine these again on the next step.',
            style: TextStyle(fontSize: 12, color: earth.ink3),
          ),
        ],
      ],
    );
  }

  // ---- Step 3: describe ------------------------------------------------
  Widget _describe(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      children: [
        _field('Common name', _commonNameCtrl),
        _field('Scientific name', _scientificCtrl, italic: true),
        const SizedBox(height: 16),
        const _Label('Health'),
        _Segmented<TreeHealth>(
          value: _health,
          options: const {
            TreeHealth.healthy: '🌿 Healthy',
            TreeHealth.stressed: '🥀 Stressed',
            TreeHealth.dead: '🪵 Dead',
          },
          onChanged: (v) => setState(() => _health = v),
        ),
        const SizedBox(height: 16),
        _Label('Estimated height — ${_height.round()} m'),
        Slider(
          value: _height,
          min: 1,
          max: 40,
          activeColor: Palette.green600,
          onChanged: (v) => setState(() => _height = v),
        ),
        const _Label('Notable features'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (key, label) in _featureOptions)
              _FeatureChip(
                label: label,
                selected: _features.contains(key),
                onTap: () => setState(() {
                  _features.contains(key)
                      ? _features.remove(key)
                      : _features.add(key);
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _Label('Notes'),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Anything memorable about this tree?',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  // ---- Step 4: location ------------------------------------------------
  Widget _locationStep(BuildContext context) {
    final offline = ref.watch(offlineModeProvider);
    final loc = _location;
    final publishPoint = _previewPublishPoint ?? loc;
    final mapCenter = loc ?? _defaultMapCenter;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      children: [
        LocationAutocompleteField(
          controller: _placeSearchCtrl,
          hintText: 'Search a place if GPS is unavailable',
          onPlaceSelected: (PlaceSuggestion place) {
            _setLocationFromPoint(place.point, source: 'search');
            FocusScope.of(context).unfocus();
          },
          onUseCurrentLocation: () => _loadLocation(force: true),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 200,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _locMapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: loc == null ? 3 : (_fuzzy ? 14.5 : 16),
                    onTap: (tap, point) {
                      _setLocationFromPoint(point, source: 'map');
                    },
                  ),
                  children: [
                    const MwavuliTileLayer(),
                    if (loc != null && _fuzzy && publishPoint != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: publishPoint,
                            radius: 500,
                            useRadiusInMeter: true,
                            color: Palette.green600.withValues(alpha: 0.18),
                            borderColor: Palette.green700.withValues(alpha: 0.7),
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    if (loc != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: loc,
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.place_rounded,
                              color: _fuzzy
                                  ? Palette.green700.withValues(alpha: 0.55)
                                  : Palette.green700,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (_loadingLocation)
                  const ColoredBox(
                    color: Color(0x66FFFFFF),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Text(
                    loc == null
                        ? 'Tap the map to drop a pin, or search above'
                        : 'Tap map to adjust · pin is exact (server fuzzes if enabled)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: const [
                        Shadow(blurRadius: 6, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.my_location_rounded,
              size: 16, color: Palette.green700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loc == null
                  ? (_loadingLocation
                      ? 'Detecting GPS…'
                      : 'No location yet — search, tap the map, or refresh GPS')
                  : '$_locationSourceLabel · ${_coordLabel(loc)}'
                      '${_locationAccuracyM != null ? ' · ±${_locationAccuracyM!.round()} m GPS' : ''}',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          if (!_loadingLocation)
            TextButton(
              onPressed: () => _loadLocation(force: true),
              child: const Text('Refresh'),
            ),
        ]),
        const SizedBox(height: 14),
        _PrivacyCard(
          fuzzy: _fuzzy,
          onChanged: (v) async {
            setState(() => _fuzzy = v);
            _refreshFuzzyPreview();
            await ref.read(userPrefsProvider).setDefaultFuzzyLocation(v);
          },
        ),
        const SizedBox(height: 16),
        const _Label('Who can see this entry'),
        _Segmented<TreeVisibility>(
          value: _visibility,
          options: const {
            TreeVisibility.public: '🌍 Public',
            TreeVisibility.followers: '👥 Followers',
            TreeVisibility.private: '🔒 Private',
          },
          onChanged: (v) => setState(() => _visibility = v),
        ),
        const SizedBox(height: 14),
        _Note(
          icon: Icons.verified_user_outlined,
          bg: Palette.green50,
          fg: Palette.green800,
          text: 'GPS metadata is stripped from public photos. Exact coordinates '
              'are stored privately; when fuzzy is on, the map shows ±500 m.',
        ),
        if (offline) ...[
          const SizedBox(height: 10),
          const _Note(
            icon: Icons.cloud_off_rounded,
            bg: Color(0xFFEFE2CF),
            fg: Palette.brown700,
            text: 'You\'re offline. This entry will be saved securely on-device '
                'and synced automatically when you reconnect. Use last known '
                'GPS or drop a map pin if a fresh fix is unavailable.',
          ),
        ],
      ],
    );
  }

  // ---- Step 5: success -------------------------------------------------
  Widget _success(BuildContext context) {
    final result = _result;
    final queued = result?.queued ?? false;
    final rewards = result?.rewards;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Palette.green50),
            child: const Icon(Icons.check_rounded,
                size: 52, color: Palette.green700),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(queued ? 'Saved offline' : 'Tree logged!',
              style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            queued
                ? 'Queued and will sync automatically when you reconnect.'
                : '${result?.commonName ?? 'Your tree'} was added to the map.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.earth.ink2),
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Palette.green50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.green100),
            ),
            child: Text(
              [
                result.isFuzzy
                    ? 'Location published as ±500 m (exact kept private)'
                    : 'Exact location published on the map',
                switch (result.visibility) {
                  TreeVisibility.public => 'Visible to everyone',
                  TreeVisibility.followers => 'Visible to followers only',
                  TreeVisibility.private => 'Only you can see this entry',
                },
                if (queued) 'Waiting to sync',
              ].join(' · '),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: Palette.green800,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (rewards != null && !queued) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                  colors: [Colors.white, Palette.gold100]),
              border: Border.all(color: Palette.gold400),
            ),
            child: Row(children: [
              const CircleAvatar(
                  radius: 26,
                  backgroundColor: Palette.gold500,
                  child: Icon(Icons.star_rounded, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('+${rewards.pointsEarned} points',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Palette.gold700,
                            fontSize: 14.5)),
                    Text(
                        'Level ${rewards.level} · ${rewards.levelName} · '
                        '${rewards.totalPoints} total',
                        style: const TextStyle(
                            fontSize: 12, color: Palette.brown600)),
                  ],
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: ElevatedButton(
                onPressed: result != null &&
                        result.treeId.isNotEmpty &&
                        !queued
                    ? () => context.push('/tree/${result.treeId}')
                    : () => context.go('/map'),
                child: Text(result != null &&
                        result.treeId.isNotEmpty &&
                        !queued
                    ? 'View tree'
                    : 'View on map')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
                onPressed: () => setState(() {
                      _step = 0;
                      _candidates = const [];
                      _identifySource = null;
                      _manualId = false;
                      _identifyError = null;
                      _photos.clear();
                      _result = null;
                      _commonNameCtrl.clear();
                      _scientificCtrl.clear();
                      _notesCtrl.clear();
                      _placeSearchCtrl.clear();
                      _location = null;
                      _locationAccuracyM = null;
                      _previewPublishPoint = null;
                      _locationSource = 'gps';
                    }),
                child: const Text('Log another')),
          ),
        ]),
      ],
    );
  }

  // ---- sticky actions --------------------------------------------------
  Widget _actions(BuildContext context) {
    final offline = ref.watch(offlineModeProvider);
    final nextLabel = switch (_step) {
      0 => 'Identify →',
      1 => 'Add details →',
      2 => 'Set location →',
      3 => offline ? 'Save offline →' : 'Submit tree',
      _ => '',
    };
    final canProceed = switch (_step) {
      0 => _photos.isNotEmpty && !_identifying,
      1 => !_identifying,
      _ => true,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      color: Palette.cream50,
      child: Row(children: [
        OutlinedButton(
          onPressed: _submitting || _identifying
              ? null
              : () {
                  if (_step == 0) {
                    context.pop();
                  } else {
                    setState(() => _step -= 1);
                  }
                },
          style: OutlinedButton.styleFrom(minimumSize: const Size(52, 48)),
          child: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: _submitting || _identifying || !canProceed
                ? null
                : () {
                    if (_step == 0) {
                      _identify();
                    } else if (_step == 3) {
                      _submit();
                    } else if (_step == 1) {
                      if (_commonNameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Choose a match or enter a common name.')),
                        );
                        return;
                      }
                      setState(() => _step += 1);
                    } else {
                      setState(() => _step += 1);
                    }
                  },
            child: _submitting || (_identifying && _step == 0)
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(nextLabel),
          ),
        ),
      ]),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {bool italic = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label(label),
            TextFormField(
              controller: controller,
              style: italic
                  ? const TextStyle(fontStyle: FontStyle.italic)
                  : null,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
      );
}

// ============================ small widgets ============================

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
}

class _Organ extends StatelessWidget {
  const _Organ(this.label, {this.got = false});
  final String label;
  final bool got;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: got ? Palette.green500 : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Text(got ? '$label ✓' : label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600)),
      );
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Palette.green600, width: 5),
          ),
          child: Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Palette.green600),
            ),
          ),
        ),
      );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(
            side: BorderSide(color: Color(0x24241D14))),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: Palette.green800, size: 24),
          ),
        ),
      );
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile(
      {required this.c, required this.selected, required this.onTap});
  final SpeciesCandidate c;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Palette.green50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? Palette.green600 : const Color(0x24241D14),
              width: 1.5),
        ),
        child: Row(children: [
          TreePhoto(c.photoTag,
              height: 52, borderRadius: BorderRadius.circular(10),
              child: const SizedBox(width: 52)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.commonName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: Palette.green900)),
                Text(c.scientificName,
                    style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Palette.brown600,
                        fontSize: 12)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: c.confidence / 100,
                    minHeight: 6,
                    backgroundColor: Palette.cream200,
                    valueColor:
                        const AlwaysStoppedAnimation(Palette.green600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${c.confidence}%',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Palette.green800,
                  fontSize: 14)),
          const SizedBox(width: 8),
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Palette.green700 : const Color(0x80241D14)),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented(
      {required this.value, required this.options, required this.onChanged});
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Palette.cream100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == entry.key ? Colors.white : null,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: value == entry.key
                        ? const [
                            BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 3,
                                offset: Offset(0, 1))
                          ]
                        : null,
                  ),
                  child: Text(entry.value,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: value == entry.key
                              ? Palette.green800
                              : const Color(0xFF4F4536))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Palette.green700 : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? Palette.green700 : const Color(0x24241D14)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF4F4536))),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.fuzzy, required this.onChanged});
  final bool fuzzy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x24241D14))),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('🔒 Fuzzy location',
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text(
                  'Publish an approximate point (±500 m) so rare or vulnerable '
                  'trees can\'t be pinpointed. Exact coordinates stay private.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF77694F))),
            ],
          ),
        ),
        Switch(value: fuzzy, onChanged: onChanged),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(
      {required this.icon,
      required this.bg,
      required this.fg,
      required this.text});
  final IconData icon;
  final Color bg;
  final Color fg;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: fg),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: fg, height: 1.5)),
        ),
      ]),
    );
  }
}
