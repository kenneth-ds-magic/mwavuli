import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../data/models/community.dart';
import '../../data/repositories/community_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final feed = ref.watch(communityProvider);
    final activity = ref.watch(activityFeedProvider);

    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Could not load community.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(communityProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) {
        final leaderboard = [
          ...data.leaderboard,
          ..._extraLeaderboard,
        ];
        final canLoadMoreLb =
            _extraLeaderboard.isEmpty ? data.leaderboardHasMore : _leaderboardHasMore;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _extraLeaderboard = const [];
              _leaderboardHasMore = false;
            });
            ref.invalidate(communityProvider);
            ref.invalidate(activityFeedProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Dims.gutter, 8, Dims.gutter, 4),
                child: Row(children: [
                  Text('Community',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _openSearch(context, ref),
                    icon: const Icon(Icons.search_rounded),
                  ),
                ]),
              ),
              if (auth == AuthStatus.unauthenticated)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.login_rounded,
                          color: Palette.green700),
                      title: const Text('Log in for your level & badges'),
                      subtitle: const Text(
                          'Leaderboard and activity are public.'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/login'),
                    ),
                  ),
                ),
              if (data.profile != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
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
              SectionHeader(
                'Your badges',
                action: data.profile == null
                    ? null
                    : '${data.earnedBadgeCount} of ${data.totalBadgeCount}',
              ),
              if (data.badges.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Dims.gutter),
                  child: Text('No badges defined yet.',
                      style:
                          TextStyle(color: Color(0xFF77694F), fontSize: 13)),
                )
              else
                SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: Dims.gutter),
                    itemCount: data.badges.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _BadgeChip(data.badges[i]),
                  ),
                ),
              SectionHeader(
                'Leaderboard',
                action: data.leaderboardPeriod == 'week'
                    ? 'This week'
                    : data.leaderboardPeriod,
              ),
              if (leaderboard.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Dims.gutter),
                  child: Text('No logs this week yet.',
                      style:
                          TextStyle(color: Color(0xFF77694F), fontSize: 13)),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (final e in leaderboard)
                            _LbRow(
                              e,
                              onTap: () => context.push('/user/${e.userId}'),
                            ),
                          if (canLoadMoreLb)
                            TextButton(
                              onPressed: _leaderboardLoading
                                  ? null
                                  : () => _loadMoreLeaderboard(data),
                              child: _leaderboardLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Load more'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (auth != AuthStatus.unauthenticated) ...[
                SectionHeader(
                  'People to follow',
                  action: data.suggestions.isEmpty ? null : 'Suggested',
                ),
                if (data.suggestions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Dims.gutter),
                    child: Text('No suggestions right now.',
                        style: TextStyle(
                            color: Color(0xFF77694F), fontSize: 13)),
                  )
                else
                  SizedBox(
                    height: _followCarouselHeight(context),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: Dims.gutter),
                      itemCount: data.suggestions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _FollowCard(
                        user: data.suggestions[i],
                        onChanged: () => ref.invalidate(communityProvider),
                        onViewProfile: () =>
                            context.push('/user/${data.suggestions[i].id}'),
                      ),
                    ),
                  ),
              ],
              const SectionHeader('Recent activity'),
              ...activity.when(
                loading: () => [
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (_, __) => [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Dims.gutter),
                    child: Text('Could not load activity.',
                        style:
                            TextStyle(color: Color(0xFF77694F), fontSize: 13)),
                  ),
                ],
                data: (page) {
                  if (page.items.isEmpty) {
                    return [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: Dims.gutter),
                        child: Text('No recent activity.',
                            style: TextStyle(
                                color: Color(0xFF77694F), fontSize: 13)),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (page.hasMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Dims.gutter, vertical: 8),
                        child: OutlinedButton(
                          onPressed: () => ref
                              .read(activityFeedProvider.notifier)
                              .loadMore(),
                          child: const Text('Load more activity'),
                        ),
                      ),
                  ];
                },
              ),
            ],
          ),
        );
      },
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

  double _followCarouselHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w < 360 ? 200.0 : 188.0;
  }

  Future<void> _openSearch(BuildContext context, WidgetRef ref) async {
    final refreshed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Palette.cream50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _UserSearchSheet(),
    );
    if (refreshed == true) ref.invalidate(communityProvider);
  }
}

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
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.earth.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Find people',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _changed),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                onChanged: _onQueryChanged,
                decoration: const InputDecoration(
                  hintText: 'Search by name or username',
                  prefixIcon: Icon(Icons.search_rounded),
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
          child: CircularProgressIndicator(strokeWidth: 2),
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
      return const Center(child: Text('No users found.'));
    }
    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Type at least 2 characters to search.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF77694F), fontSize: 13),
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
          contentPadding: EdgeInsets.zero,
          leading: _UserAvatar(
            name: u.displayName,
            avatarUrl: u.avatarUrl,
          ),
          title: Text(u.displayName, overflow: TextOverflow.ellipsis),
          subtitle: Text('@${u.username}', overflow: TextOverflow.ellipsis),
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

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.profile});
  final CommunityProfile profile;

  @override
  Widget build(BuildContext context) {
    final g = profile.gamification;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Palette.green600, Palette.green800]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('Level ${profile.level} · ${profile.levelName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white, fontSize: 20)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999)),
                child: Text('★ ${profile.points}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: g.progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Palette.gold400),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  g.pointsToNextLevel > 0
                      ? '${g.pointsToNextLevel} pts to Level ${g.nextLevel}'
                      : 'Max level reached',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              if (g.streakDays > 0) ...[
                const SizedBox(width: 8),
                Text('🔥 ${g.streakDays}d',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

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
    Widget tile(String v, String k, {VoidCallback? onTap}) => Expanded(
          child: Card(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  Text(v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontSize: 20, color: Palette.green800)),
                  const SizedBox(height: 4),
                  Text(k,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF77694F),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dims.gutter, 12, Dims.gutter, 0),
      child: Row(children: [
        tile('${profile.treeCount}', 'Trees logged', onTap: onTrees),
        const SizedBox(width: 10),
        tile('${profile.speciesCount}', 'Species', onTap: onTrees),
        const SizedBox(width: 10),
        tile('${profile.followers}', 'Followers', onTap: onFollowers),
      ]),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip(this.badge);
  final AchievementBadge badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(badge.name),
            content: Text(
              badge.description?.trim().isNotEmpty == true
                  ? badge.description!
                  : badge.earned
                      ? 'You earned this badge.'
                      : 'Keep logging trees to unlock this badge.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
            ],
          ),
        );
      },
      child: SizedBox(
        width: 84,
        child: Column(children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: badge.earned
                ? const LinearGradient(
                    colors: [Palette.gold400, Palette.gold600])
                : null,
            color: badge.earned ? null : const Color(0xFFE9DFC9),
          ),
          child: Icon(badge.iconData,
              color: badge.earned ? Colors.white : const Color(0x8877694F),
              size: 30),
        ),
        const SizedBox(height: 7),
        Text(badge.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: badge.earned
                    ? Palette.ink
                    : const Color(0xFF77694F))),
        ]),
      ),
    );
  }
}

class _LbRow extends StatelessWidget {
  const _LbRow(this.e, {this.onTap});
  final LeaderboardEntry e;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (e.rank) {
      1 => Palette.gold600,
      2 => const Color(0xFF8A8A8A),
      3 => Palette.brown500,
      _ => const Color(0xFF77694F),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: e.isMe
          ? BoxDecoration(
              color: Palette.green50, borderRadius: BorderRadius.circular(12))
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x14241D14)))),
      child: Row(children: [
        SizedBox(
            width: 28,
            child: Text('${e.rank}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: rankColor,
                    fontSize: 14))),
        _UserAvatar(name: e.displayName, avatarUrl: e.avatarUrl, radius: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(e.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF77694F))),
            ],
          ),
        ),
        Text('${e.logCount}',
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Palette.green800,
                fontSize: 14)),
      ]),
        ),
      ),
    );
  }
}

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
    final width = cardWidth.clamp(140.0, 168.0);

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                    const SizedBox(height: 6),
                    Text(widget.user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(widget.user.meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF77694F),
                            height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: _busy
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _following
                        ? OutlinedButton(
                            onPressed: _toggle,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Following'))
                        : ElevatedButton(
                            onPressed: _toggle,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Follow')),
              ),
            ],
          ),
        ),
      ),
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
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return TextButton(
      onPressed: _toggle,
      child: Text(_following ? 'Following' : 'Follow'),
    );
  }
}

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
      child: Text(initial,
          style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.55,
              fontWeight: FontWeight.w700)),
    );
  }
}
