import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/models/community.dart';
import '../../data/repositories/community_repository.dart';
import '../../features/auth/auth_controller.dart';
import '../../widgets/tree_card.dart';

/// Full-screen public mapper profile — deep-linkable at `/user/:id`.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicUserProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapper'),
        actions: [
          async.maybeWhen(
            data: (user) => IconButton(
              tooltip: 'Copy profile link',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () async {
                final link = 'mwavuli://user/${user.id}';
                await Clipboard.setData(ClipboardData(
                  text: '${user.displayName} (${user.handle}) on mwavuli\n$link',
                ));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Profile link copied'),
                  behavior: SnackBarBehavior.floating,
                ));
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load this mapper.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(publicUserProvider(userId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (user) => _UserProfileBody(userId: userId, user: user),
      ),
    );
  }
}

class _UserProfileBody extends ConsumerStatefulWidget {
  const _UserProfileBody({required this.userId, required this.user});
  final String userId;
  final PublicUserProfile user;

  @override
  ConsumerState<_UserProfileBody> createState() => _UserProfileBodyState();
}

class _UserProfileBodyState extends ConsumerState<_UserProfileBody> {
  late bool _following = widget.user.isFollowing;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _UserProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.isFollowing != widget.user.isFollowing) {
      _following = widget.user.isFollowing;
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.user.isMe || _busy) return;
    if (ref.read(authControllerProvider) != AuthStatus.authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log in to follow mappers.')),
        );
      }
      return;
    }
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
      ref.invalidate(communityProvider);
      ref.invalidate(publicUserProvider(widget.userId));
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initial = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()[0].toUpperCase()
        : '?';

    return ListView(
      padding: const EdgeInsets.fromLTRB(Dims.gutter, 8, Dims.gutter, 32),
      children: [
        Center(
          child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
              ? CircleAvatar(
                  radius: 44,
                  backgroundColor: Palette.green600,
                  backgroundImage: NetworkImage(user.avatarUrl!),
                  onBackgroundImageError: (_, __) {},
                )
              : CircleAvatar(
                  radius: 44,
                  backgroundColor: Palette.green600,
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700)),
                ),
        ),
        const SizedBox(height: 14),
        Text(user.displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        Text(user.handle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF77694F))),
        if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(user.bio!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.45)),
        ],
        const SizedBox(height: 14),
        Text(
          'Level ${user.level} · ${user.levelName} · ${user.points} pts',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: Palette.green800),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _stat('${user.logCount}', 'Trees'),
            _stat('${user.followers}', 'Followers'),
            _stat('${user.following}', 'Following'),
          ],
        ),
        if (!user.isMe) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _busy
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _following
                    ? OutlinedButton(
                        onPressed: _toggleFollow,
                        child: const Text('Following'),
                      )
                    : ElevatedButton(
                        onPressed: _toggleFollow,
                        child: const Text('Follow'),
                      ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.go('/profile'),
            child: const Text('Open my profile'),
          ),
        ],
        const SizedBox(height: 22),
        Text('Public trees',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (user.trees.isEmpty)
          const Text('No public trees yet.',
              style: TextStyle(color: Color(0xFF77694F), fontSize: 13))
        else
          for (final t in user.trees)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TreeCard(
                tree: t,
                onTap: () => context.push('/tree/${t.id}'),
              ),
            ),
      ],
    );
  }

  Widget _stat(String v, String k) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(v,
                    style: const TextStyle(
                        fontFamily: 'RobotoSlab',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Palette.green800)),
                const SizedBox(height: 2),
                Text(k,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF77694F))),
              ],
            ),
          ),
        ),
      );
}
