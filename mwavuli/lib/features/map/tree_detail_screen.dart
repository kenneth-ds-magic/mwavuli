import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../data/models/tree.dart';
import '../../data/models/tree_comment.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/tree_repository.dart';
import '../../core/api/api_client.dart';
import '../../features/auth/auth_controller.dart';
import '../../widgets/pill.dart';
import '../../widgets/tree_photo.dart';
import 'map_tile_layer.dart';

class TreeDetailScreen extends ConsumerStatefulWidget {
  const TreeDetailScreen({super.key, required this.treeId});
  final String treeId;

  @override
  ConsumerState<TreeDetailScreen> createState() => _TreeDetailScreenState();
}

class _TreeDetailScreenState extends ConsumerState<TreeDetailScreen> {
  final _commentController = TextEditingController();
  bool _liked = false;
  int? _likeCount;
  bool _likeBusy = false;
  bool _commentBusy = false;
  bool? _saved;
  bool _saveBusy = false;
  bool _verifyBusy = false;

  @override
  void didUpdateWidget(TreeDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.treeId != widget.treeId) {
      _saved = null;
      _liked = false;
      _likeCount = null;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.brown800,
      ));
  }

  Future<void> _share(Tree tree) async {
    final loc = tree.displayLocation;
    final text = StringBuffer('${tree.commonName} (${tree.scientificName})');
    if (loc != null) {
      text.write(
          '\nApproximate map point: ${loc.latitude.toStringAsFixed(5)}, '
          '${loc.longitude.toStringAsFixed(5)}');
    }
    text.write('\nView in mwavuli: tree/${tree.id}');
    await Clipboard.setData(ClipboardData(text: text.toString()));
    _snack('Share text copied (no exact GPS)');
  }

  Future<void> _verifyTree(Tree tree) async {
    if (ref.read(authControllerProvider) != AuthStatus.authenticated) {
      _snack('Log in to verify species IDs');
      return;
    }
    setState(() => _verifyBusy = true);
    try {
      final r = await ref.read(treeRepositoryProvider).verify(tree.id);
      ref.invalidate(treeDetailProvider(tree.id));
      ref.invalidate(mapFeedProvider);
      if (!mounted) return;
      setState(() => _verifyBusy = false);
      if (r.verified) {
        _snack('Community verified this species ID');
      } else {
        _snack(
            'Thanks — ${r.verificationCount} confirmation${r.verificationCount == 1 ? '' : 's'} received');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _verifyBusy = false);
        _snack('Could not submit verification');
      }
    }
  }

  Future<void> _openDirections(Tree tree) async {
    final loc = tree.displayLocation;
    if (loc == null) {
      _snack('No location available for this tree');
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${loc.latitude},${loc.longitude}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Could not open maps');
    }
  }

  Future<void> _toggleLike(Tree tree) async {
    if (ref.read(authControllerProvider) != AuthStatus.authenticated) {
      _snack('Log in to like trees');
      return;
    }
    setState(() => _likeBusy = true);
    try {
      final repo = ref.read(treeRepositoryProvider);
      final count =
          _liked ? await repo.unlike(tree.id) : await repo.like(tree.id);
      if (!mounted) return;
      setState(() {
        _liked = !_liked;
        _likeCount = count;
        _likeBusy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _likeBusy = false);
        _snack('Could not update like');
      }
    }
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    if (ref.read(authControllerProvider) != AuthStatus.authenticated) {
      _snack('Log in to comment');
      return;
    }
    setState(() => _commentBusy = true);
    try {
      await ref.read(treeRepositoryProvider).postComment(widget.treeId, body);
      _commentController.clear();
      ref.invalidate(treeCommentsProvider(widget.treeId));
      ref.invalidate(treeDetailProvider(widget.treeId));
      _snack('Comment posted');
    } catch (_) {
      _snack('Could not post comment');
    } finally {
      if (mounted) setState(() => _commentBusy = false);
    }
  }

  Future<void> _toggleSave(Tree tree, bool currentlySaved) async {
    if (ref.read(authControllerProvider) != AuthStatus.authenticated) {
      _snack('Log in to save trees to your collection');
      return;
    }
    setState(() => _saveBusy = true);
    try {
      final repo = ref.read(treeRepositoryProvider);
      final saved = currentlySaved
          ? await repo.unsave(tree.id)
          : await repo.save(tree.id);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _saveBusy = false;
      });
      _snack(saved ? 'Saved to your collection' : 'Removed from your collection');
    } catch (_) {
      if (mounted) {
        setState(() => _saveBusy = false);
        _snack('Could not update collection');
      }
    }
  }

  Future<void> _report(Tree tree) async {
    if (ref.read(authControllerProvider) != AuthStatus.authenticated) {
      _snack('Log in to report entries');
      return;
    }
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Report this entry',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final (code, label) in const [
              ('inaccurate_id', 'Inaccurate identification'),
              ('wrong_location', 'Wrong location'),
              ('spam', 'Spam'),
              ('offensive', 'Offensive content'),
              ('sensitive_species', 'Sensitive species exposure'),
              ('privacy', 'Privacy concern'),
              ('other', 'Other'),
            ])
              ListTile(
                title: Text(label),
                onTap: () => Navigator.pop(ctx, code),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await ref
          .read(treeRepositoryProvider)
          .reportTree(tree.id, reason: reason);
      _snack('Reported — our moderators will review this entry');
    } catch (_) {
      _snack('Could not submit report');
    }
  }

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
    final detailAsync = ref.watch(treeDetailProvider(widget.treeId));
    final commentsAsync = ref.watch(treeCommentsProvider(widget.treeId));
    final myId = ref.watch(profileProvider).valueOrNull?.profile.id;

    return Scaffold(
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Tree not found'));
          }
          final tree = detail.tree;
          final displayLikes = _likeCount ?? tree.likeCount;
          final saved = _saved ?? detail.saved;
          final commentCount =
              commentsAsync.valueOrNull?.length ?? tree.commentCount;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Palette.green800,
                leading: _RoundBtn(
                    Icons.arrow_back_rounded, () => Navigator.pop(context)),
                actions: [
                  if (_saveBusy)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    _RoundBtn(
                      saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      () => _toggleSave(tree, saved),
                    ),
                  _RoundBtn(Icons.ios_share_rounded, () => _share(tree)),
                  const SizedBox(width: 6),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: TreePhoto(
                    tree.photoTag,
                    imageUrl: detail.heroImageUrl,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (tree.verified)
                          const Pill('ID verified',
                              icon: Icons.check_rounded, tone: PillTone.green)
                        else
                          Pill('ID ${tree.confidence}%',
                              icon: Icons.auto_awesome, tone: PillTone.gold),
                      ]),
                      if (!tree.verified &&
                          myId != null &&
                          tree.ownerId != null &&
                          tree.ownerId != myId) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _verifyBusy || detail.userVerified
                                ? null
                                : () => _verifyTree(tree),
                            icon: _verifyBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.verified_outlined, size: 18),
                            label: Text(
                              detail.userVerified
                                  ? 'You confirmed this ID'
                                  : 'Confirm species ID '
                                      '(${detail.verificationCount}/'
                                      '${detail.verificationsRequired})',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(tree.commonName,
                          style: Theme.of(context).textTheme.headlineSmall),
                      Text(tree.scientificName,
                          style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: earth.brown,
                              fontSize: 14)),
                      const SizedBox(height: 14),
                      _facts(tree),
                      if (tree.description.trim().isNotEmpty)
                        _section(
                          context,
                          'Description',
                          Text(tree.description,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.6,
                                  color: earth.ink2)),
                        ),
                      _section(
                          context, 'Location', _locationCard(context, tree)),
                      if (detail.photos.length > 1)
                        _section(
                          context,
                          'Photos',
                          SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: detail.photos.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final p = detail.photos[i];
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: TreePhoto(
                                    tree.photoTag,
                                    imageUrl: p.thumbUrl ?? p.url,
                                    height: 88,
                                    child: const SizedBox(width: 88),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      _section(context, 'Contributor',
                          _contributor(context, tree, myId)),
                      _section(
                        context,
                        'Comments · $commentCount',
                        _commentsSection(commentsAsync),
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openDirections(tree),
                            icon: const Icon(Icons.directions_outlined,
                                size: 19),
                            label: const Text('Directions'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: OutlinedButton.icon(
                            onPressed:
                                _likeBusy ? null : () => _toggleLike(tree),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                            ),
                            icon: Icon(
                              _liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                            ),
                            label: Text('$displayLikes'),
                          ),
                        ),
                      ]),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _report(tree),
                          icon: Icon(Icons.outlined_flag_rounded,
                              size: 15, color: earth.ink3),
                          label: Text('Report this entry',
                              style: TextStyle(
                                  color: earth.ink3,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _facts(Tree t) {
    Widget tile(String v, String k) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x24241D14))),
            child: Column(children: [
              Text(v,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Palette.green800)),
              const SizedBox(height: 2),
              Text(k,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF77694F),
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        );
    return Row(children: [
      tile('${t.heightMeters.toStringAsFixed(0)} m', 'HEIGHT'),
      tile(t.ageEstimate, 'AGE EST.'),
      tile(t.health.label, 'HEALTH'),
      tile('${t.girthMeters} m', 'GIRTH'),
    ]);
  }

  Widget _section(BuildContext context, String title, Widget child) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _locationCard(BuildContext context, Tree t) {
    final loc = t.displayLocation;
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x24241D14))),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        SizedBox(
          height: 110,
          child: loc == null
              ? const ColoredBox(
                  color: Color(0xFFE7EEDD),
                  child: Center(
                      child: Icon(Icons.place,
                          color: Palette.green700, size: 30)),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: loc,
                    initialZoom: 15,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    const MwavuliTileLayer(),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: loc,
                          width: 28,
                          height: 28,
                          child: const Icon(Icons.place,
                              color: Palette.green700, size: 28),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(11),
          child: Row(children: [
            Icon(
                t.isFuzzy
                    ? Icons.lock_outline_rounded
                    : Icons.place_outlined,
                size: 15),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                  t.isFuzzy
                      ? 'Approximate location shown (±500 m) to protect this '
                          'tree. Exact coordinates are private.'
                      : 'Public exact location shown on the map.',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF4F4536))),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _contributor(BuildContext context, Tree t, String? myId) {
    final ownerId = t.ownerId;
    final isSelf = myId != null && ownerId != null && myId == ownerId;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x24241D14))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
              radius: 22,
              backgroundColor: Palette.gold500,
              child: Text(t.contributor.characters.first,
                  style: const TextStyle(color: Colors.white))),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.contributor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                    isSelf ? 'This is your tree log' : 'Community contributor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF77694F))),
              ],
            ),
          ),
          if (ownerId != null && !isSelf) ...[
            const SizedBox(width: 8),
            _ContributorFollowButton(ownerId: ownerId),
          ],
        ],
      ),
    );
  }

  Widget _commentsSection(AsyncValue<List<TreeComment>> commentsAsync) {
    return commentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Could not load comments.',
              style: TextStyle(fontSize: 13, color: Color(0xFF77694F))),
          TextButton(
            onPressed: () =>
                ref.invalidate(treeCommentsProvider(widget.treeId)),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (comments) => Column(
        children: [
          if (comments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No comments yet — be the first.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF77694F))),
              ),
            ),
          for (final c in comments) _commentBubble(c),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  enabled: !_commentBusy,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment…',
                    constraints: BoxConstraints(maxHeight: 46),
                  ),
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
              IconButton(
                onPressed: _commentBusy ? null : _submitComment,
                icon: _commentBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _commentBubble(TreeComment c) {
    final seed = _colorForName(c.author);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 16, backgroundColor: seed),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFF4EDDD),
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.author,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(c.body, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Color _colorForName(String name) {
    final palette = [
      Palette.green500,
      const Color(0xFF5C4B8A),
      Palette.brown600,
      Palette.gold500,
    ];
    return palette[name.hashCode.abs() % palette.length];
  }
}

class _ContributorFollowButton extends ConsumerStatefulWidget {
  const _ContributorFollowButton({required this.ownerId});
  final String ownerId;

  @override
  ConsumerState<_ContributorFollowButton> createState() =>
      _ContributorFollowButtonState();
}

class _ContributorFollowButtonState
    extends ConsumerState<_ContributorFollowButton> {
  bool _following = false;
  bool _busy = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    if (ref.read(authControllerProvider) != AuthStatus.authenticated) return;
    try {
      final list = await ref.read(apiClientProvider).fetchFollowing();
      if (!mounted) return;
      setState(() {
        _following =
            list.any((u) => (u['id'] as String?) == widget.ownerId);
        _checked = true;
      });
    } catch (_) {
      if (mounted) setState(() => _checked = true);
    }
  }

  Future<void> _toggle() async {
    if (ref.read(authControllerProvider) != AuthStatus.authenticated) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      if (_following) {
        await api.unfollowUser(widget.ownerId);
      } else {
        await api.followUser(widget.ownerId);
      }
      if (!mounted) return;
      setState(() {
        _following = !_following;
        _busy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const SizedBox(
        width: 88,
        height: 36,
        child: Center(
            child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (ref.watch(authControllerProvider) != AuthStatus.authenticated) {
      return const SizedBox.shrink();
    }

    final label = _following ? 'Following' : 'Follow';
    final style = ElevatedButton.styleFrom(
      minimumSize: const Size(72, 36),
      maximumSize: const Size(120, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    if (_busy) {
      return SizedBox(
        width: 88,
        height: 36,
        child: ElevatedButton(
          onPressed: null,
          style: style,
          child: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: _toggle,
      style: style,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(7),
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: Palette.green800),
          ),
        ),
      ),
    );
  }
}
