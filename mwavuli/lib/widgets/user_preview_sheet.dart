import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../data/models/community.dart';
import '../data/repositories/community_repository.dart';
import '../features/auth/auth_controller.dart';

/// Public user card — opened from activity, leaderboard, or follow suggestions.
Future<void> showUserPreviewSheet(
  BuildContext context,
  WidgetRef ref,
  String userId, {
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _UserPreviewSheet(
      userId: userId,
      onChanged: onChanged,
    ),
  );
}

class _UserPreviewSheet extends ConsumerStatefulWidget {
  const _UserPreviewSheet({required this.userId, this.onChanged});
  final String userId;
  final VoidCallback? onChanged;

  @override
  ConsumerState<_UserPreviewSheet> createState() => _UserPreviewSheetState();
}

class _UserPreviewSheetState extends ConsumerState<_UserPreviewSheet> {
  SuggestedUser? _user;
  bool _loading = true;
  String? _error;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user =
          await ref.read(communityRepositoryProvider).fetchUser(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load profile';
      });
    }
  }

  Future<void> _toggleFollow() async {
    final user = _user;
    if (user == null || _followBusy) return;
    if (ref.read(authControllerProvider) != AuthStatus.authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log in to follow mappers.')),
        );
      }
      return;
    }
    setState(() => _followBusy = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      if (user.isFollowing) {
        await repo.unfollow(user.id);
      } else {
        await repo.follow(user.id);
      }
      if (!mounted) return;
      setState(() {
        _user = SuggestedUser(
          id: user.id,
          displayName: user.displayName,
          username: user.username,
          avatarUrl: user.avatarUrl,
          bio: user.bio,
          logCount: user.logCount,
          isFollowing: !user.isFollowing,
        );
        _followBusy = false;
      });
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: _loading
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
              ? SizedBox(
                  height: 120,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: Palette.danger)),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildBody(context, _user!),
    );
  }

  Widget _buildBody(BuildContext context, SuggestedUser user) {
    final initial = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()[0].toUpperCase()
        : '?';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
          CircleAvatar(
            radius: 36,
            backgroundColor: Palette.green600,
            backgroundImage: NetworkImage(user.avatarUrl!),
            onBackgroundImageError: (_, __) {},
          )
        else
          CircleAvatar(
            radius: 36,
            backgroundColor: Palette.green600,
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 12),
        Text(user.displayName,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center),
        Text('@${user.username}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF77694F))),
        if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(user.bio!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, height: 1.45)),
        ],
        if (user.logCount != null && user.logCount! > 0) ...[
          const SizedBox(height: 8),
          Text('${user.logCount} trees logged',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF77694F))),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _followBusy
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : user.isFollowing
                  ? OutlinedButton(
                      onPressed: _toggleFollow,
                      child: const Text('Following'),
                    )
                  : ElevatedButton(
                      onPressed: _toggleFollow,
                      child: const Text('Follow'),
                    ),
        ),
      ],
    );
  }
}
