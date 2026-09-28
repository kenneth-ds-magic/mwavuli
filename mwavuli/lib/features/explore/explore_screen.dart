import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/location/location_service.dart';
import '../../data/models/community.dart';
import '../../data/models/explore.dart';
import '../../data/models/profile.dart';
import '../../data/models/tree.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/explore_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../features/map/map_tile_layer.dart';
import '../../widgets/activity_row.dart';
import '../../widgets/section_header.dart';
import '../../widgets/tree_card.dart';
import '../../widgets/tree_photo.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  int _selectedFilter = 0;
  String _searchInput = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      ref.read(exploreFeedProvider.notifier).loadMore();
    }
  }

  Future<void> _initLocation() async {
    final loc = await ref.read(locationServiceProvider).current();
    if (!mounted || loc == null) return;
    String? label;
    try {
      label = await ref.read(nominatimGeocodeProvider).reverseLabel(loc);
    } catch (_) {}
    ref.read(exploreLocationProvider.notifier).state = ExploreLocation(
      lat: loc.latitude,
      lng: loc.longitude,
      label: label,
    );
    ref.invalidate(exploreProvider);
  }

  void _onSearchChanged() {
    final value = _searchController.text;
    setState(() => _searchInput = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(exploreFeedQueryProvider.notifier).state =
          ref.read(exploreFeedQueryProvider).copyWith(search: value.trim());
    });
  }

  void _selectFilter(int index) {
    final key = exploreFilterKeys[index];
    final loc = ref.read(exploreLocationProvider);
    if (key == 'near' && (loc.lat == null || loc.lng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable location to filter trees near you.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _selectedFilter = index);
    ref.read(exploreFeedQueryProvider.notifier).state =
        ref.read(exploreFeedQueryProvider).copyWith(filter: key);
  }

  Future<void> _refresh() async {
    ref.invalidate(exploreProvider);
    ref.invalidate(exploreFeedProvider);
    if (_searchInput.trim().length >= 2) {
      ref.invalidate(exploreUserSearchProvider(_searchInput.trim()));
    }
  }

  void _openNotifications(ExploreData? explore) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.cream50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _NotificationsSheet(seed: explore?.recentActivity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final explore = ref.watch(exploreProvider);
    final feed = ref.watch(exploreFeedProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final localLoc = ref.watch(exploreLocationProvider);
    final searchQ = _searchInput.trim();
    final userSearch = searchQ.length >= 2
        ? ref.watch(exploreUserSearchProvider(searchQ))
        : null;
    final activityCount = explore.valueOrNull?.recentActivity.length ?? 0;
    final feedTrees = feed.valueOrNull?.trees ?? const <Tree>[];
    final trendingTrees = explore.valueOrNull?.trendingSpecies
            .map((s) => s.sampleTree)
            .toList() ??
        const <Tree>[];
    final allExploreTrees = [
      ...feedTrees,
      ...trendingTrees.where((t) => !feedTrees.any((ft) => ft.id == t.id)),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Palette.cream50,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Palette.green700,
          onRefresh: _refresh,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // --- Hero Top Header ---
              _HeaderBanner(
                exploreData: explore.valueOrNull,
                localLocationLabel: localLoc.label,
                activityCount: activityCount,
                profile: profile?.profile,
                onNotifications: () => _openNotifications(explore.valueOrNull),
                onProfile: () => context.go('/profile'),
              ),

              // --- Search Bar ---
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Dims.gutter, 14, Dims.gutter, 0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search species, places or people…',
                    hintStyle: const TextStyle(color: Palette.ink3),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Palette.green700, size: 22),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 46, minHeight: 46),
                    suffixIcon: _searchInput.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 18, color: Palette.ink3),
                            onPressed: _searchController.clear,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0x1F241D14)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0x1F241D14)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Palette.green700, width: 1.5),
                    ),
                  ),
                ),
              ),

              // --- People Search Results Chips ---
              if (searchQ.length >= 2 && userSearch != null) ...[
                const SizedBox(height: 12),
                userSearch.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Dims.gutter),
                    child: LinearProgressIndicator(
                        minHeight: 2, color: Palette.green700),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (users) {
                    if (users.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: Dims.gutter),
                          child: Text(
                            'PEOPLE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Palette.ink3,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: Dims.gutter),
                            itemCount: users.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, i) {
                              final u = users[i];
                              return _UserResultChip(
                                user: u,
                                onTap: () => context.push('/user/${u.id}'),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],

              // --- Category Filters ---
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: Dims.gutter),
                  itemCount: exploreFilterLabels.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _FilterChip(
                    exploreFilterLabels[i],
                    index: i,
                    selected: i == _selectedFilter,
                    onTap: () => _selectFilter(i),
                  ),
                ),
              ),

              // --- Map Teaser Box ---
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
                child: _MapTeaser(
                  label: explore.when(
                    skipLoadingOnReload: true,
                    skipLoadingOnRefresh: true,
                    data: (d) => d.mapTeaserLabel(),
                    loading: () => 'Loading local map…',
                    error: (_, __) => 'Open interactive map',
                  ),
                  center: localLoc.lat != null && localLoc.lng != null
                      ? LatLng(localLoc.lat!, localLoc.lng!)
                      : null,
                  trees: allExploreTrees,
                  onTap: () => context.go('/map'),
                ),
              ),

              // --- Trending Species Carousel ---
              const SizedBox(height: 12),
              SectionHeader(
                'Trending Species',
                action: 'See All',
                onAction: () => context.go('/map'),
              ),
              explore.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () => const SizedBox(
                  height: 164,
                  child: Center(
                    child: CircularProgressIndicator(color: Palette.green700),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) {
                  if (data.trendingSpecies.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: Dims.gutter),
                      child: Text('No species logged yet.',
                          style: TextStyle(fontSize: 13, color: Palette.ink3)),
                    );
                  }
                  return SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: Dims.gutter),
                      itemCount: data.trendingSpecies.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final item = data.trendingSpecies[i];
                        final t = item.sampleTree;
                        return _SpeciesMini(
                          tag: t.photoTag,
                          name: t.commonName,
                          imageUrl: t.thumbUrl,
                          photoStatus: t.photoStatus,
                          count: item.treeCount,
                          onTap: () => context.push('/tree/${t.id}'),
                        );
                      },
                    ),
                  );
                },
              ),

              // --- Community Feed Section ---
              const SizedBox(height: 12),
              SectionHeader(
                'Community Feed',
                action: _selectedFilter == 0
                    ? '✨ Latest'
                    : exploreFilterLabels[_selectedFilter],
              ),
              feed.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: Palette.green700),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('Could not load community feed: $e',
                          style: const TextStyle(color: Palette.danger)),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(exploreFeedProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (page) {
                  if (page.trees.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.eco_outlined,
                                size: 40, color: Palette.ink3),
                            const SizedBox(height: 8),
                            Text(
                              searchQ.isNotEmpty || _selectedFilter > 0
                                  ? 'No trees match your search or filters.'
                                  : 'No trees logged yet. Be the first to map one!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13.5, color: Palette.ink3),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final t in page.trees)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Dims.gutter, 0, Dims.gutter, 14),
                          child: TreeCard(
                            tree: t,
                            onTap: () => context.push('/tree/${t.id}'),
                          ),
                        ),
                      if (page.loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Palette.green700),
                            ),
                          ),
                        )
                      else if (page.hasMore)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Dims.gutter, 0, Dims.gutter, 12),
                          child: OutlinedButton(
                            onPressed: () => ref
                                .read(exploreFeedProvider.notifier)
                                .loadMore(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Palette.green700),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Load More Trees',
                              style: TextStyle(
                                  color: Palette.green700,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Header Banner Component
// ============================================================================
class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({
    required this.exploreData,
    required this.localLocationLabel,
    required this.activityCount,
    required this.profile,
    required this.onNotifications,
    required this.onProfile,
  });

  final ExploreData? exploreData;
  final String? localLocationLabel;
  final int activityCount;
  final MeProfile? profile;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final subtitle = exploreData?.headerSubtitle(
          localLocationLabel: localLocationLabel,
        ) ??
        'Discover & map trees near you';

    return Container(
      margin: const EdgeInsets.fromLTRB(Dims.gutter, 10, Dims.gutter, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Palette.green900,
            Palette.green800,
            Palette.green700,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Palette.green900.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.explore_rounded,
                          size: 13, color: Palette.gold400),
                      SizedBox(width: 4),
                      Text(
                        'EXPLORE & MAP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Explore',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Notification Button with Badge
          Material(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onNotifications,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Badge(
                  isLabelVisible: activityCount > 0,
                  backgroundColor: Palette.gold400,
                  textColor: Palette.brown800,
                  label: Text('$activityCount',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Profile Avatar with Ring
          GestureDetector(
            onTap: onProfile,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Palette.gold400, width: 1.5),
              ),
              child: _ProfileAvatar(profile: profile),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.profile});
  final MeProfile? profile;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    return CircleAvatar(
      radius: 17,
      backgroundColor: Palette.green700,
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      onBackgroundImageError: hasAvatar ? (_, __) {} : null,
      child: Text(
        profile?.initials ?? '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ============================================================================
// User Result Chip (People Search)
// ============================================================================
class _UserResultChip extends StatelessWidget {
  const _UserResultChip({required this.user, required this.onTap});
  final SuggestedUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1F241D14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Palette.green600,
                  backgroundImage:
                      user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                  onBackgroundImageError: (_, __) {},
                  child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Category Filter Chip
// ============================================================================
class _FilterChip extends StatelessWidget {
  const _FilterChip(
    this.label, {
    required this.index,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final int index;
  final bool selected;
  final VoidCallback? onTap;

  static const _icons = [
    Icons.grid_view_rounded,
    Icons.near_me_rounded,
    Icons.nature_rounded,
    Icons.local_florist_rounded,
    Icons.eco_rounded,
    Icons.diamond_rounded,
    Icons.forest_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final icon = index < _icons.length ? _icons[index] : Icons.park_rounded;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Palette.green700 : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Palette.green700 : const Color(0x1F241D14),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Palette.green700.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : Palette.green700,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : Palette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Interactive Map Teaser Component
// ============================================================================
class _MapTeaser extends StatelessWidget {
  const _MapTeaser({
    required this.label,
    required this.onTap,
    this.center,
    this.trees = const [],
  });

  final String label;
  final VoidCallback onTap;
  final LatLng? center;
  final List<Tree> trees;

  static const _fallback = LatLng(43.6489, -79.3817);

  @override
  Widget build(BuildContext context) {
    final locTrees = trees.where((t) => t.displayLocation != null).toList();
    final mapCenter = center ??
        (locTrees.isNotEmpty ? locTrees.first.displayLocation! : _fallback);

    if (center != null && locTrees.isNotEmpty) {
      const distance = Distance();
      locTrees.sort((a, b) {
        final dA = distance(center!, a.displayLocation!);
        final dB = distance(center!, b.displayLocation!);
        return dA.compareTo(dB);
      });
    }

    final markers = <Marker>[
      for (final t in locTrees.take(20))
        Marker(
          point: t.displayLocation!,
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: Palette.green700,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.park_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      if (center != null)
        Marker(
          point: center!,
          width: 26,
          height: 26,
          child: Container(
            decoration: BoxDecoration(
              color: Palette.danger,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.my_location_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
    ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 140,
            child: Stack(
              children: [
                IgnorePointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: center != null ? 12.5 : 11,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      const MwavuliTileLayer(),
                      if (markers.isNotEmpty) MarkerLayer(markers: markers),
                    ],
                  ),
                ),

                // Top Location Label Badge
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 14, color: Palette.green700),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Palette.green900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Pill Button
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Palette.green700,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.green900.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open Map',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Trending Species Card Component
// ============================================================================
class _SpeciesMini extends StatelessWidget {
  const _SpeciesMini({
    required this.tag,
    required this.name,
    required this.onTap,
    this.imageUrl,
    this.photoStatus,
    this.count = 0,
  });

  final String tag;
  final String name;
  final String? imageUrl;
  final String? photoStatus;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 136,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x1F241D14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    TreePhoto(
                      tag,
                      height: 94,
                      imageUrl: imageUrl,
                      photoStatus: photoStatus,
                    ),
                    if (count > 0)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.park_rounded,
                                  size: 10, color: Palette.gold400),
                              const SizedBox(width: 3),
                              Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Palette.green900,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Notifications Bottom Sheet Modal
// ============================================================================
class _NotificationsSheet extends ConsumerWidget {
  const _NotificationsSheet({this.seed});
  final List<ActivityItem>? seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityFeedProvider);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.76;
    final seedItems = seed ?? const <ActivityItem>[];

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Palette.cream200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                children: [
                  Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => ref.invalidate(activityFeedProvider),
                    icon: const Icon(Icons.refresh_rounded,
                        color: Palette.green700),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/community');
                    },
                    child: const Text('Community',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Palette.green700)),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Recent activity and updates from the mwavuli community.',
                style: TextStyle(fontSize: 12.5, color: Palette.ink3),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: activity.when(
                loading: () => seedItems.isNotEmpty
                    ? _activityList(context, seedItems)
                    : const Center(
                        child: CircularProgressIndicator(
                            color: Palette.green700),
                      ),
                error: (_, __) => seedItems.isNotEmpty
                    ? _activityList(context, seedItems)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Could not load notifications.'),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () =>
                                  ref.invalidate(activityFeedProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                data: (page) {
                  final list =
                      page.items.isNotEmpty ? page.items : seedItems;
                  if (list.isEmpty) {
                    return const Center(
                      child: Text(
                        'No notifications yet.\nLog a tree or follow mappers to see updates here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Palette.ink3, fontSize: 13),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: Palette.green700,
                    onRefresh: () async =>
                        ref.invalidate(activityFeedProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: list.length + (page.hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == list.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: TextButton(
                                onPressed: page.loadingMore
                                    ? null
                                    : () => ref
                                        .read(activityFeedProvider.notifier)
                                        .loadMore(),
                                child: page.loadingMore
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Palette.green700),
                                      )
                                    : const Text('Load More Notifications',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Palette.green700)),
                              ),
                            ),
                          );
                        }
                        return ActivityRow(
                          list[i],
                          onBeforeNavigate: () => Navigator.pop(context),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityList(BuildContext context, List<ActivityItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      itemBuilder: (_, i) => ActivityRow(
        items[i],
        onBeforeNavigate: () => Navigator.pop(context),
      ),
    );
  }
}
