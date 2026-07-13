import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/location/location_service.dart';
import '../../core/location/nominatim_geocode.dart';
import '../../data/models/tree.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/tree_repository.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../../widgets/tree_photo.dart';
import 'map_filter_sheet.dart';
import 'map_tile_layer.dart';

/// Open-source (OpenStreetMap) map with custom, category-coloured tree pins.
/// Tapping a pin raises a preview sheet; "Details" opens the full record.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  Timer? _bboxDebounce;
  Tree? _selected;
  LatLng? _userLocation;
  bool _located = false;
  bool _autoCentered = false;
  bool _searchLocating = false;
  String? _publishedBbox;

  static const _defaultCenter = LatLng(43.6489, -79.3817);
  static const _bboxDebounceMs = 800;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToMyLocation());
  }

  @override
  void dispose() {
    _bboxDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    if (_publishedBbox == null) _scheduleBboxUpdate();
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) _scheduleBboxUpdate();
  }

  void _scheduleBboxUpdate() {
    _bboxDebounce?.cancel();
    _bboxDebounce =
        Timer(const Duration(milliseconds: _bboxDebounceMs), _updateBbox);
  }

  void _updateBbox() {
    if (!mounted) return;
    try {
      final bounds = _mapController.camera.visibleBounds;
      final raw =
          '${bounds.west},${bounds.south},${bounds.east},${bounds.north}';
      final bbox = normalizeMapBbox(raw);
      if (bbox == null || bbox == _publishedBbox) return;
      _publishedBbox = bbox;
      ref.read(mapBboxProvider.notifier).state = bbox;
    } catch (_) {}
  }

  Future<void> _goToMyLocation() async {
    final loc = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    if (loc != null) {
      setState(() {
        _userLocation = loc;
        _located = true;
      });
      _mapController.move(loc, 14);
      _scheduleBboxUpdate();
    } else if (!_located) {
      _mapController.move(_defaultCenter, 14);
      _scheduleBboxUpdate();
    }
  }

  bool _isMine(Tree t, String? myId) =>
      myId != null && t.ownerId != null && t.ownerId == myId;

  Color _pinColor(Tree t) {
    if (t.features.any((f) => f.toLowerCase().contains('rare'))) {
      return Palette.gold500;
    }
    final tag = t.photoTag;
    if (tag == 'pine') return Palette.green800;
    if (tag == 'maple') return Palette.brown600;
    return Palette.green600;
  }

  void _goToPlace(PlaceSuggestion place) {
    setState(() => _selected = null);
    _mapController.move(place.point, 13);
    _scheduleBboxUpdate();
  }

  Future<void> _useSearchCurrentLocation() async {
    setState(() => _searchLocating = true);
    try {
      final loc = ref.read(locationServiceProvider);
      final geocode = ref.read(nominatimGeocodeProvider);
      final label = await loc.currentLocationLabel(geocode);
      if (!mounted) return;
      if (label != null && label.isNotEmpty) {
        _searchController.text = label;
      }
      final point = await loc.current();
      if (!mounted) return;
      if (point != null) {
        setState(() {
          _userLocation = point;
          _located = true;
        });
        _mapController.move(point, 14);
        _scheduleBboxUpdate();
      }
    } finally {
      if (mounted) setState(() => _searchLocating = false);
    }
  }

  List<Tree> _applyFilters(List<Tree> trees, MapFilters filters) {
    return trees.where((t) {
      if (t.displayLocation == null) return false;
      if (filters.health != null && t.health != filters.health) return false;
      if (filters.verifiedOnly && !t.verified) return false;
      return true;
    }).toList();
  }

  Future<void> _openFilters() async {
    final picked = await showMapFilterSheet(
      context,
      initial: ref.read(mapFiltersProvider),
    );
    if (picked != null) {
      ref.read(mapFiltersProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(mapFeedProvider);
    final filters = ref.watch(mapFiltersProvider);
    final myId = ref.watch(profileProvider).valueOrNull?.profile.id;
    final trees = feed.valueOrNull ?? const <Tree>[];
    final visible = _applyFilters(trees, filters);
    final initialLoad = feed.isLoading && !feed.hasValue;

    if (!_autoCentered && visible.isNotEmpty && !_located) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoCentered || _located) return;
        final first = visible.first.displayLocation;
        if (first == null) return;
        _autoCentered = true;
        _mapController.move(first, 13);
        _scheduleBboxUpdate();
      });
    }

    return Stack(
      children: [
        _buildMap(visible, trees.length, filters, myId, refreshing: feed.isRefreshing),
        if (initialLoad)
          const Center(child: CircularProgressIndicator()),
        if (feed.hasError && !feed.hasValue)
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not load trees\n${feed.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(mapFeedProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMap(
    List<Tree> visible,
    int fetchedCount,
    MapFilters filters,
    String? myId, {
    bool refreshing = false,
  }) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation ?? _defaultCenter,
            initialZoom: 14,
            onMapReady: _onMapReady,
            onMapEvent: _onMapEvent,
          ),
          children: [
            const MwavuliTileLayer(),
            if (_userLocation != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _userLocation!,
                    radius: 8,
                    color: Palette.green600.withValues(alpha: 0.25),
                    borderColor: Palette.green700,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final t in visible)
                  Marker(
                    point: t.displayLocation!,
                    width: 40,
                    height: 40,
                    child: _Pin(
                      color: _pinColor(t),
                      ring: _isMine(t, myId),
                      onTap: () => setState(() => _selected = t),
                    ),
                  ),
              ],
            ),
          ],
        ),

        Positioned(
          top: 10,
          left: 14,
          right: 14,
          child: Material(
            color: Palette.cream50,
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: LocationAutocompleteField(
                controller: _searchController,
                locating: _searchLocating,
                onUseCurrentLocation: _useSearchCurrentLocation,
                onPlaceSelected: _goToPlace,
              ),
            ),
          ),
        ),

        if (visible.isEmpty && (filters.isActive || fetchedCount > 0))
          Positioned(
            top: 64,
            left: 14,
            right: 14,
            child: Material(
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _emptyMessage(filters, fetchedCount),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          ),

        Positioned(left: 14, bottom: 0, child: const SafeArea(
          minimum: EdgeInsets.only(bottom: 24),
          child: _Legend(),
        )),

        Positioned(
          right: 14,
          bottom: 0,
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniFab(
                  Icons.filter_list_rounded,
                  _openFilters,
                  active: filters.isActive,
                ),
                const SizedBox(height: 10),
                _MiniFab(Icons.my_location_rounded, _goToMyLocation),
              ],
            ),
          ),
        ),

        if (refreshing)
          const Positioned(
            top: 58,
            right: 14,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          left: 10,
          right: 10,
          bottom: _selected == null ? -200 : 14,
          child: _selected == null
              ? const SizedBox.shrink()
              : _PreviewSheet(
                  tree: _selected!,
                  isMine: _isMine(_selected!, myId),
                  onClose: () => setState(() => _selected = null),
                  onDetails: () => context.push('/tree/${_selected!.id}'),
                ),
        ),
      ],
    );
  }

  String _emptyMessage(MapFilters filters, int fetchedCount) {
    if (filters.isActive) {
      return 'No trees match your filters in this map area.\nTry zooming out or clearing filters.';
    }
    if (fetchedCount == 0) {
      return 'No trees logged in this area yet.';
    }
    return 'No trees to show.';
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.onTap, this.ring = false});
  final Color color;
  final bool ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
              color: ring ? Palette.green600 : Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
                color: Color(0x552A2118), blurRadius: 4, offset: Offset(0, 3))
          ],
        ),
        child: Icon(Icons.park_rounded,
            size: 18, color: ring ? Palette.green700 : Colors.white),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    Widget row(Color c, String label, {bool ring = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                  color: ring ? Colors.white : c,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: ring ? Palette.green600 : Colors.white,
                      width: ring ? 2 : 1)),
            ),
            const SizedBox(width: 7),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 8)
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(Palette.green600, 'Oak / broadleaf'),
          row(Palette.green800, 'Conifer'),
          row(Palette.gold500, 'Rare / notable'),
          row(Colors.white, 'Your logs', ring: true),
        ],
      ),
    );
  }
}

class _MiniFab extends StatelessWidget {
  const _MiniFab(this.icon, this.onTap, {this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Palette.green50 : Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon,
              color: active ? Palette.green700 : Palette.green800, size: 22),
        ),
      ),
    );
  }
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({
    required this.tree,
    required this.isMine,
    required this.onClose,
    required this.onDetails,
  });
  final Tree tree;
  final bool isMine;
  final VoidCallback onClose;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TreePhoto(
              tree.photoTag,
              imageUrl: tree.thumbUrl,
              photoStatus: tree.photoStatus,
              height: 76,
              borderRadius: BorderRadius.circular(14),
              child: const SizedBox(width: 76),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tree.commonName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Palette.green900)),
                  Text(tree.scientificName,
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: earth.brown,
                          fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 10, children: [
                    _meta(Icons.place_outlined,
                        tree.isFuzzy ? '±500 m' : 'Exact'),
                    _meta(Icons.eco_outlined, tree.health.label),
                    _meta(Icons.person_outline, tree.contributor),
                    if (isMine)
                      _meta(Icons.account_circle_outlined, 'Your log'),
                  ]),
                ],
              ),
            ),
            Column(children: [
              SizedBox(
                height: 34,
                child: ElevatedButton(
                    onPressed: onDetails,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 34)),
                    child: const Text('Details')),
              ),
              IconButton(
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData i, String s) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 13, color: const Color(0xFF77694F)),
          const SizedBox(width: 3),
          Text(s,
              style:
                  const TextStyle(fontSize: 11.5, color: Color(0xFF77694F))),
        ],
      );
}
