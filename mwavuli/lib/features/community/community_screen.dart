import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../data/models/community.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/explore_repository.dart';
import '../../features/auth/auth_controller.dart';
import '../../widgets/activity_row.dart';
import '../../widgets/section_header.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  List<LeaderboardEntry> _extraLeaderboard = const [];
  bool _leaderboardLoading = false;
  bool _leaderboardHasMore = false;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    if (maxScroll - currentScroll <= 250) {
      ref.read(activityFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final feed = ref.watch(communityProvider);
    final activity = ref.watch(activityFeedProvider);

    ref.listen(communityProvider, (prev, next) {
      if (next.isLoading || next.isRefreshing) {
        if (_extraLeaderboard.isEmpty && !_leaderboardHasMore) return;
        setState(() {
          _extraLeaderboard = const [];
          _leaderboardHasMore = false;
        });
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Palette.cream50,
      body: SafeArea(
        bottom: false,
        child: feed.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Center(
            child: CircularProgressIndicator(color: Palette.green700),
          ),
          error: (_, __) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCEEEA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_off_rounded,
                        size: 44, color: Palette.danger),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not load community.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Palette.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Please check your internet connection.',
                    style: TextStyle(fontSize: 13, color: Palette.ink3),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(communityProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final router = GoRouter.of(context);
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout();
                          router.go('/welcome');
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Log Out'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          data: (data) {
            final leaderboard = [
              ...data.leaderboard,
              ..._extraLeaderboard,
            ];
            final canLoadMoreLb = _extraLeaderboard.isEmpty
                ? data.leaderboardHasMore
                : _leaderboardHasMore;

            return RefreshIndicator(
              color: Palette.green700,
              onRefresh: () async {
                setState(() {
                  _extraLeaderboard = const [];
                  _leaderboardHasMore = false;
                });
                ref.invalidate(communityProvider);
                ref.invalidate(activityFeedProvider);
                ref.invalidate(exploreFeedProvider);
              },
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  // --- Hero Top Header ---
                  _HeaderBanner(onSearch: () => _openSearch(context, ref)),

                  // --- Unauthenticated Login Banner ---
                  if (auth == AuthStatus.unauthenticated)
                    Container(
                      margin: const EdgeInsets.fromLTRB(
                          Dims.gutter, 16, Dims.gutter, 0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Palette.green50, Palette.cream100],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Palette.green100),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Palette.green700,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.login_rounded,
                              color: Colors.white, size: 20),
                        ),
                        title: const Text('Log in to unlock your level & badges',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: const Text(
                          'Join the community leaderboard and earn rewards.',
                          style: TextStyle(fontSize: 12, color: Palette.ink2),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              size: 16, color: Palette.green800),
                        ),
                        onTap: () => context.push('/login'),
                      ),
                    ),

                  // --- User Level Card & Quick Stats ---
                  if (data.profile != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Dims.gutter, 16, Dims.gutter, 0),
                      child: _LevelCard(profile: data.profile!),
                    ),
                    _StatRow(
                      profile: data.profile!,
                      onTrees: () {
                        ref.read(profileTabRequestProvider.notifier).state = 0;
                        context.go('/profile');
                      },
                      onFollowers: () {
                        ref
                            .read(profileOpenFollowersRequestProvider.notifier)
                            .state = true;
                        context.go('/profile');
                      },
                    ),
                  ],

                  // --- Achievements & Badges Section ---
                  const SizedBox(height: 12),
                  SectionHeader(
                    'Your Badges',
                    action: data.profile == null
                        ? null
                        : '${data.earnedBadgeCount} of ${data.totalBadgeCount} unlocked',
                  ),
                  if (data.badges.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: Dims.gutter),
                      child: Text('No badges defined yet.',
                          style: TextStyle(
                              color: Palette.ink3, fontSize: 13)),
                    )
                  else
                    SizedBox(
                      height: 114,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: Dims.gutter),
                        itemCount: data.badges.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _BadgeChip(data.badges[i]),
                      ),
                    ),

                  // --- Community Leaderboard Section ---
                  const SizedBox(height: 16),
                  SectionHeader(
                    'Leaderboard',
                    action: data.leaderboardPeriod == 'week'
                        ? '🔥 This Week'
                        : data.leaderboardPeriod,
                  ),
                  if (leaderboard.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: Dims.gutter),
                      child: Text('No logs recorded this week yet.',
                          style: TextStyle(
                              color: Palette.ink3, fontSize: 13)),
                    )
                  else ...[
                    // Top 3 Podium Cards if at least 3 entries exist
                    if (leaderboard.length >= 3)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Dims.gutter),
                        child: _LbPodium(
                          top1: leaderboard[0],
                          top2: leaderboard[1],
                          top3: leaderboard[2],
                          onTapUser: (userId) => context.push('/user/$userId'),
                        ),
                      ),

                    // Ranks 4+ (or all if <3 entries) List View
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Dims.gutter),
                      child: Card(
                        elevation: 1,
                        shadowColor: Colors.black.withValues(alpha: 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0x1A241D14)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Column(
                            children: [
                              for (var i = (leaderboard.length >= 3 ? 3 : 0);
                                  i < leaderboard.length;
                                  i++)
                                _LbRow(
                                  leaderboard[i],
                                  onTap: () => context.push(
                                      '/user/${leaderboard[i].userId}'),
                                ),
                              if (canLoadMoreLb) ...[
                                const Divider(height: 1),
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: _leaderboardLoading
                                      ? null
                                      : () => _loadMoreLeaderboard(data),
                                  child: _leaderboardLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Palette.green700),
                                        )
                                      : const Text(
                                          'Show More Leaders',
                                          style: TextStyle(
                                              color: Palette.green700,
                                              fontWeight: FontWeight.w700),
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // --- People to Follow Carousel ---
                  if (auth != AuthStatus.unauthenticated) ...[
                    const SizedBox(height: 16),
                    SectionHeader(
                      'People to Follow',
                      action: data.suggestions.isEmpty ? null : 'Suggested',
                    ),
                    if (data.suggestions.isEmpty)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: Dims.gutter),
                        child: Text('No new suggestions right now.',
                            style: TextStyle(
                                color: Palette.ink3, fontSize: 13)),
                      )
                    else
                      SizedBox(
                        height: 200,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: Dims.gutter),
                          itemCount: data.suggestions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) => _FollowCard(
                            user: data.suggestions[i],
                            onChanged: () => ref.invalidate(communityProvider),
                            onViewProfile: () => context.push(
                                '/user/${data.suggestions[i].id}'),
                          ),
                        ),
                      ),
                  ],

                  // --- Recent Community Activity Section ---
                  const SizedBox(height: 16),
                  SectionHeader(
                    'Recent Activity',
                    action: activity.valueOrNull != null &&
                            activity.valueOrNull!.items.isNotEmpty
                        ? '${activity.valueOrNull!.items.length} items'
                        : null,
                  ),
                  ...activity.when(
                    skipLoadingOnReload: true,
                    skipLoadingOnRefresh: true,
                    loading: () => [
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: Palette.green700),
                        ),
                      ),
                    ],
                    error: (_, __) => [
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: Dims.gutter),
                        child: Text('Could not load community activity.',
                            style: TextStyle(
                                color: Palette.ink3, fontSize: 13)),
                      ),
                    ],
                    data: (page) {
                      if (page.items.isEmpty) {
                        return [
                          const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: Dims.gutter),
                            child: Text('No recent community activity.',
                                style: TextStyle(
                                    color: Palette.ink3, fontSize: 13)),
                          ),
                        ];
                      }
                      return [
                        for (final a in page.items) ActivityRow(a),
                        if (page.loadingMore)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Palette.green700),
                              ),
                            ),
                          )
                        else if (page.hasMore)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Dims.gutter, vertical: 12),
                            child: OutlinedButton(
                              onPressed: () => ref
                                  .read(activityFeedProvider.notifier)
                                  .loadMore(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Palette.green700),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Load More Activity',
                                  style: TextStyle(
                                      color: Palette.green700,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                      ];
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadMoreLeaderboard(CommunityData data) async {
    setState(() => _leaderboardLoading = true);
    try {
      final offset = data.leaderboard.length + _extraLeaderboard.length;
      final page = await ref
          .read(communityRepositoryProvider)
          .fetchLeaderboardPage(limit: 10, offset: offset);
      if (!mounted) return;
      setState(() {
        _extraLeaderboard = [..._extraLeaderboard, ...page.items];
        _leaderboardHasMore = page.hasMore;
        _leaderboardLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _leaderboardLoading = false);
    }
  }

  Future<void> _openSearch(BuildContext context, WidgetRef ref) async {
    final refreshed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Palette.cream50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _UserSearchSheet(),
    );
    if (refreshed == true) ref.invalidate(communityProvider);
  }
}

// ============================================================================
// Header Banner Component
// ============================================================================
class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.onSearch});
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.nature_people_rounded,
                              size: 13, color: Palette.gold400),
                          SizedBox(width: 4),
                          Text(
                            'ECO COMMUNITY',
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
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Community',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Log trees, earn badges & climb the leaderboard',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: const Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Gamification Level Card
// ============================================================================
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.profile});
  final CommunityProfile profile;

  @override
  Widget build(BuildContext context) {
    final g = profile.gamification;
    final progressPct = (g.progress * 100).clamp(0, 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF143513),
            Color(0xFF22521F),
            Color(0xFF33702D),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF143513).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Level Shield Badge Icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Palette.gold400, Palette.gold600],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Palette.gold500.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${profile.level}',
                    style: const TextStyle(
                      color: Palette.brown800,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.levelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Level ${profile.level} Pioneer',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Points Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Palette.gold400.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Palette.gold400, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.points} pts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar with Percentage
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      FractionallySizedBox(
                        widthFactor: g.progress.clamp(0.0, 1.0),
                        child: Container(
                          height: 10,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Palette.gold400, Palette.gold500],
                            ),
                            borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(999),
                              left: Radius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$progressPct%',
                style: const TextStyle(
                  color: Palette.gold400,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Footer Metrics (Points to Next Level & Streak)
          Row(
            children: [
              Expanded(
                child: Text(
                  g.pointsToNextLevel > 0
                      ? '${g.pointsToNextLevel} pts to Level ${g.nextLevel}'
                      : '🏆 Max level achieved!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (g.streakDays > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 3),
                      Text(
                        '${g.streakDays}d Streak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Quick Stats Row
// ============================================================================
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.profile,
    this.onTrees,
    this.onFollowers,
  });
  final CommunityProfile profile;
  final VoidCallback? onTrees;
  final VoidCallback? onFollowers;

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required String value,
      required String label,
      required IconData icon,
      required Color color,
      VoidCallback? onTap,
    }) {
      return Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1F241D14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Palette.green800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.ink3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Dims.gutter, 14, Dims.gutter, 0),
      child: Row(
        children: [
          tile(
            value: '${profile.treeCount}',
            label: 'Trees Logged',
            icon: Icons.park_rounded,
            color: Palette.green700,
            onTap: onTrees,
          ),
          const SizedBox(width: 10),
          tile(
            value: '${profile.speciesCount}',
            label: 'Species',
            icon: Icons.eco_rounded,
            color: Palette.gold600,
            onTap: onTrees,
          ),
          const SizedBox(width: 10),
          tile(
            value: '${profile.followers}',
            label: 'Followers',
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF2E7D32),
            onTap: onFollowers,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Achievement Badge Chip & Details Modal
// ============================================================================
class _BadgeChip extends StatelessWidget {
  const _BadgeChip(this.badge);
  final AchievementBadge badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showBadgeDetailSheet(context, badge),
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: badge.earned
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Palette.gold400, Palette.gold600],
                          )
                        : null,
                    color: badge.earned ? null : const Color(0xFFE5DDD0),
                    boxShadow: badge.earned
                        ? [
                            BoxShadow(
                              color: Palette.gold500.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: badge.earned
                          ? Palette.gold400
                          : const Color(0xFFC7BBAA),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      badge.iconData,
                      color: badge.earned
                          ? Colors.white
                          : const Color(0x9977694F),
                      size: 30,
                    ),
                  ),
                ),
                if (!badge.earned)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF77694F),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Palette.green700,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              badge.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: badge.earned ? Palette.ink : Palette.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetailSheet(BuildContext context, AchievementBadge badge) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.cream50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Palette.cream200,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: badge.earned
                    ? const LinearGradient(
                        colors: [Palette.gold400, Palette.gold600],
                      )
                    : null,
                color: badge.earned ? null : const Color(0xFFE5DDD0),
                boxShadow: badge.earned
                    ? [
                        BoxShadow(
                          color: Palette.gold500.withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                badge.iconData,
                color: badge.earned ? Colors.white : Palette.ink3,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Palette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badge.earned ? Palette.green50 : Palette.cream100,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: badge.earned ? Palette.green100 : Palette.cream200,
                ),
              ),
              child: Text(
                badge.earned ? '🏆 Unlocked' : '🔒 Locked Achievement',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: badge.earned ? Palette.green800 : Palette.ink3,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              badge.description?.trim().isNotEmpty == true
                  ? badge.description!
                  : (badge.earned
                      ? 'You have successfully earned this achievement badge!'
                      : 'Keep logging trees and interacting with the community to unlock this badge.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Palette.ink2),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.green700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Top 3 Leaderboard Podium Component
// ============================================================================
class _LbPodium extends StatelessWidget {
  const _LbPodium({
    required this.top1,
    required this.top2,
    required this.top3,
    required this.onTapUser,
  });

  final LeaderboardEntry top1;
  final LeaderboardEntry top2;
  final LeaderboardEntry top3;
  final ValueChanged<String> onTapUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Palette.green800,
            Palette.green700,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Palette.green900.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_rounded,
                  color: Palette.gold400, size: 18),
              SizedBox(width: 6),
              Text(
                'TOP CHAMPIONS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place (Left)
              _PodiumItem(
                entry: top2,
                crown: '🥈',
                rank: 2,
                color: const Color(0xFFDCDCDC),
                avatarRadius: 24,
                onTap: () => onTapUser(top2.userId),
              ),

              // 1st Place (Center - Elevated)
              _PodiumItem(
                entry: top1,
                crown: '👑',
                rank: 1,
                color: Palette.gold400,
                avatarRadius: 30,
                isFirst: true,
                onTap: () => onTapUser(top1.userId),
              ),

              // 3rd Place (Right)
              _PodiumItem(
                entry: top3,
                crown: '🥉',
                rank: 3,
                color: const Color(0xFFE0A96D),
                avatarRadius: 24,
                onTap: () => onTapUser(top3.userId),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  const _PodiumItem({
    required this.entry,
    required this.crown,
    required this.rank,
    required this.color,
    required this.avatarRadius,
    this.isFirst = false,
    required this.onTap,
  });

  final LeaderboardEntry entry;
  final String crown;
  final int rank;
  final Color color;
  final double avatarRadius;
  final bool isFirst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(crown, style: TextStyle(fontSize: isFirst ? 22 : 18)),
          const SizedBox(height: 2),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: isFirst ? 3 : 2),
                  boxShadow: isFirst
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: _UserAvatar(
                  name: entry.displayName,
                  avatarUrl: entry.avatarUrl,
                  radius: avatarRadius,
                ),
              ),
              Positioned(
                bottom: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: isFirst ? Palette.brown800 : Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: isFirst ? 95 : 80,
            child: Text(
              entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isFirst ? FontWeight.w800 : FontWeight.w600,
                fontSize: isFirst ? 13 : 11.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '🌿 ${entry.logCount}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Leaderboard Row Item (#4+)
// ============================================================================
class _LbRow extends StatelessWidget {
  const _LbRow(this.e, {this.onTap});
  final LeaderboardEntry e;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: e.isMe
              ? BoxDecoration(
                  color: Palette.green50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.green100),
                )
              : const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0x14241D14)),
                  ),
                ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '${e.rank}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Palette.ink3,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _UserAvatar(
                name: e.displayName,
                avatarUrl: e.avatarUrl,
                radius: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            e.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  e.isMe ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 14,
                              color: Palette.ink,
                            ),
                          ),
                        ),
                        if (e.isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Palette.green700,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      e.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: Palette.ink3),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Palette.green50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '🌿 ${e.logCount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Palette.green800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Suggested User Follow Card
// ============================================================================
class _FollowCard extends ConsumerStatefulWidget {
  const _FollowCard({
    required this.user,
    required this.onChanged,
    this.onViewProfile,
  });
  final SuggestedUser user;
  final VoidCallback onChanged;
  final VoidCallback? onViewProfile;

  @override
  ConsumerState<_FollowCard> createState() => _FollowCardState();
}

class _FollowCardState extends ConsumerState<_FollowCard> {
  late bool _following = widget.user.isFollowing;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _FollowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.isFollowing != widget.user.isFollowing ||
        oldWidget.user.id != widget.user.id) {
      _following = widget.user.isFollowing;
    }
  }

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      if (_following) {
        await repo.unfollow(widget.user.id);
      } else {
        await repo.follow(widget.user.id);
      }
      if (!mounted) return;
      setState(() {
        _following = !_following;
        _busy = false;
      });
      widget.onChanged();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.sizeOf(context).width * 0.42;
    final width = cardWidth.clamp(144.0, 168.0);

    return SizedBox(
      width: width,
      child: Card(
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x1F241D14)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: widget.onViewProfile,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    _UserAvatar(
                      name: widget.user.displayName,
                      avatarUrl: widget.user.avatarUrl,
                      radius: 26,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.user.meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Palette.ink3,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: _busy
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Palette.green700),
                        ),
                      )
                    : _following
                        ? OutlinedButton(
                            onPressed: _toggle,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              side: const BorderSide(color: Palette.green700),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Following',
                                style: TextStyle(color: Palette.green700)),
                          )
                        : ElevatedButton(
                            onPressed: _toggle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Palette.green700,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 34),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Follow'),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// User Search Bottom Sheet
// ============================================================================
class _UserSearchSheet extends ConsumerStatefulWidget {
  const _UserSearchSheet();

  @override
  ConsumerState<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends ConsumerState<_UserSearchSheet> {
  late final TextEditingController _controller;
  Timer? _debounce;
  List<SuggestedUser> _results = const [];
  bool _loading = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items =
          await ref.read(communityRepositoryProvider).searchUsers(q.trim());
      if (!mounted) return;
      setState(() {
        _results = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: sheetHeight,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) Navigator.pop(context, _changed);
          },
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Find People',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, _changed),
                      child: const Text('Done',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Palette.green700)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name or @username',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Palette.green700),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _controller.clear();
                              _onQueryChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
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
                      borderSide: const BorderSide(
                          color: Palette.green700, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildResults()),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Palette.green700),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_error!, style: const TextStyle(color: Palette.danger)),
        ),
      );
    }
    if (_results.isEmpty && _controller.text.trim().length >= 2) {
      return const Center(
        child: Text('No users found matching your search.',
            style: TextStyle(color: Palette.ink3)),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Type at least 2 characters to search for users.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Palette.ink3, fontSize: 13),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final u = _results[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: _UserAvatar(
            name: u.displayName,
            avatarUrl: u.avatarUrl,
            radius: 20,
          ),
          title: Text(u.displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('@${u.username}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Palette.ink3, fontSize: 12)),
          onTap: () => context.push('/user/${u.id}'),
          trailing: _FollowButton(
            userId: u.id,
            following: u.isFollowing,
            onChanged: () async {
              _changed = true;
              await _search(_controller.text);
            },
          ),
        );
      },
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({
    required this.userId,
    required this.following,
    required this.onChanged,
  });
  final String userId;
  final bool following;
  final VoidCallback onChanged;

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  late bool _following = widget.following;
  bool _busy = false;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      if (_following) {
        await repo.unfollow(widget.userId);
      } else {
        await repo.follow(widget.userId);
      }
      if (!mounted) return;
      setState(() {
        _following = !_following;
        _busy = false;
      });
      widget.onChanged();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Palette.green700),
      );
    }
    return _following
        ? OutlinedButton(
            onPressed: _toggle,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Palette.green700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Following',
                style: TextStyle(color: Palette.green700)),
          )
        : ElevatedButton(
            onPressed: _toggle,
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.green700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Follow'),
          );
  }
}

// ============================================================================
// User Avatar Helper
// ============================================================================
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.name,
    this.avatarUrl,
    this.radius = 18,
  });
  final String name;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final url = avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Palette.green600,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
        child: url.isEmpty
            ? Text(initial, style: const TextStyle(color: Colors.white))
            : null,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Palette.green600,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.55,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
