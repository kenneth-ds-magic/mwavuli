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
      showDragHandle: true,
      builder: (ctx) => _NotificationsSheet(seed: explore?.recentActivity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
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

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Dims.gutter, 8, Dims.gutter, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Explore',
                          style: Theme.of(context).textTheme.titleLarge),
                      explore.when(
                        loading: () => Text('Loading…',
                            style: TextStyle(fontSize: 12, color: earth.ink3)),
                        error: (_, __) => Text('Could not load stats',
                            style: TextStyle(fontSize: 12, color: earth.ink3)),
                        data: (data) => Text(
                          data.headerSubtitle(
                              localLocationLabel: localLoc.label),
                          style: TextStyle(fontSize: 12, color: earth.ink3),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openNotifications(explore.valueOrNull),
                  tooltip: 'Notifications',
                  icon: Badge(
                    isLabelVisible: activityCount > 0,
                    label: Text('$activityCount'),
                    child: Icon(
                      activityCount > 0
                          ? Icons.notifications_rounded
                          : Icons.notifications_none_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: _ProfileAvatar(profile: profile?.profile),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search species, places or people',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                prefixIcon: const Icon(Icons.search_rounded),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 44, minHeight: 44),
                suffixIcon: _searchInput.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: _searchController.clear,
                      ),
              ),
            ),
          ),
          if (searchQ.length >= 2 && userSearch != null) ...[
            const SizedBox(height: 10),
            userSearch.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: Dims.gutter),
                child: LinearProgressIndicator(minHeight: 2),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (users) {
                if (users.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: Dims.gutter),
                      child: Text('People',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF77694F))),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: Dims.gutter),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final u = users[i];
                          return ActionChip(
                            avatar: CircleAvatar(
                              radius: 12,
                              backgroundColor: Palette.green600,
                              backgroundImage: u.avatarUrl != null &&
                                      u.avatarUrl!.isNotEmpty
                                  ? NetworkImage(u.avatarUrl!)
                                  : null,
                              onBackgroundImageError: (_, __) {},
                              child: u.avatarUrl == null || u.avatarUrl!.isEmpty
                                  ? Text(
                                      u.displayName.isNotEmpty
                                          ? u.displayName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11),
                                    )
                                  : null,
                            ),
                            label: Text(u.displayName,
                                style: const TextStyle(fontSize: 12)),
                            onPressed: () => context.push('/user/${u.id}'),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
              itemCount: exploreFilterLabels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _FilterChip(
                exploreFilterLabels[i],
                selected: i == _selectedFilter,
                onTap: () => _selectFilter(i),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
            child: _MapTeaser(
              label: explore.when(
                data: (d) => d.mapTeaserLabel(),
                loading: () => 'Loading map…',
                error: (_, __) => 'Open the map',
              ),
              center: localLoc.lat != null && localLoc.lng != null
                  ? LatLng(localLoc.lat!, localLoc.lng!)
                  : null,
              trees: feedTrees,
              onTap: () => context.go('/map'),
            ),
          ),
          SectionHeader(
            'Trending species',
            action: 'See all',
            onAction: () => context.go('/map'),
          ),
          explore.when(
            loading: () => const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) {
              if (data.trendingSpecies.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Dims.gutter),
                  child: Text('No species logged yet.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF77694F))),
                );
              }
              return SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: Dims.gutter),
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
          const SectionHeader('Community feed', action: 'Latest'),
          feed.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Couldn\'t load feed: $e'),
                    TextButton(
                      onPressed: () => ref.invalidate(exploreFeedProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                )),
            data: (page) {
              if (page.trees.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    searchQ.isNotEmpty || _selectedFilter > 0
                        ? 'No trees match your search or filters.'
                        : 'No trees logged yet. Be the first!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF77694F)),
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
                          onTap: () => context.push('/tree/${t.id}')),
                    ),
                  if (page.loadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (page.hasMore)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Dims.gutter, 0, Dims.gutter, 8),
                      child: OutlinedButton(
                        onPressed: () =>
                            ref.read(exploreFeedProvider.notifier).loadMore(),
                        child: const Text('Load more'),
                      ),
                    ),
                ],
              );
            },
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
    final avatar = profile != null && profile!.hasAvatar
        ? CircleAvatar(
            radius: 19,
            backgroundImage: NetworkImage(profile!.avatarUrl!),
            onBackgroundImageError: (_, __) {},
          )
        : CircleAvatar(
            radius: 19,
            backgroundColor: Palette.green500,
            child: Text(profile?.initials ?? '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          );
    return avatar;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(this.label, {this.selected = false, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Palette.green700 : Colors.white,
          borderRadius: BorderRadius.circular(Dims.radiusPill),
          border: Border.all(color: selected ? Palette.green700 : earth.line),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : earth.ink2)),
      ),
    );
  }
}

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
    final mapCenter = center ??
        () {
          for (final t in trees) {
            final p = t.displayLocation;
            if (p != null) return p;
          }
          return _fallback;
        }();
    final markers = <Marker>[
      for (final t in trees.take(12))
        if (t.displayLocation != null)
          Marker(
            point: t.displayLocation!,
            width: 18,
            height: 18,
            child: const Icon(Icons.circle, size: 10, color: Palette.green700),
          ),
      if (center != null)
        Marker(
          point: center!,
          width: 22,
          height: 22,
          child: const Icon(Icons.my_location, size: 16, color: Palette.danger),
        ),
    ];

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Dims.radius),
        child: SizedBox(
          height: 132,
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
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Palette.green800)),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                      color: Palette.green700,
                      borderRadius: BorderRadius.circular(999)),
                  child: const Text('Open map →',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        width: 132,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  TreePhoto(
                    tag,
                    height: 92,
                    imageUrl: imageUrl,
                    photoStatus: photoStatus,
                  ),
                  if (count > 0)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999)),
                        child: Text('$count',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
                child: Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Palette.green900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsSheet extends ConsumerWidget {
  const _NotificationsSheet({this.seed});
  final List<ActivityItem>? seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityFeedProvider);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;
    final seedItems = seed ?? const <ActivityItem>[];

    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: Row(children: [
                Text('Notifications',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => ref.invalidate(activityFeedProvider),
                  child: const Text('Refresh'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/community');
                  },
                  child: const Text('Community'),
                ),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Recent activity from the mwavuli community.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF77694F)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: activity.when(
                loading: () => seedItems.isNotEmpty
                    ? _activityList(context, seedItems)
                    : const Center(child: CircularProgressIndicator()),
                error: (_, __) => seedItems.isNotEmpty
                    ? _activityList(context, seedItems)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Could not load activity.'),
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
                        'No activity yet.\nLog a tree or follow mappers to see updates here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF77694F)),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(activityFeedProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: list.length + (page.hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == list.length) {
                          return TextButton(
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
                                        strokeWidth: 2),
                                  )
                                : const Text('Load more'),
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
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (_, i) => ActivityRow(
        items[i],
        onBeforeNavigate: () => Navigator.pop(context),
      ),
    );
  }
}
