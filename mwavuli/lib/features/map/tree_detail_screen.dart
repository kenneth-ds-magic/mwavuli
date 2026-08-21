import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dio/dio.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/camera/photo_capture.dart';
import '../../core/id/identification_service.dart';
import '../../core/offline/sync_service.dart';
import '../../data/models/species.dart';
import '../../data/models/tree.dart';
import '../../data/models/tree_comment.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/tree_repository.dart';
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
  bool? _liked;
  int? _likeCount;
  bool _likeBusy = false;
  bool _commentBusy = false;
  bool? _saved;
  bool _saveBusy = false;
  bool _verifyBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshTree();
    });
  }

  void _refreshTree() {
    ref.invalidate(treeDetailProvider(widget.treeId));
    ref.invalidate(treeCommentsProvider(widget.treeId));
  }

  @override
  void didUpdateWidget(TreeDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.treeId != widget.treeId) {
      _saved = null;
      _liked = null;
      _likeCount = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshTree();
      });
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

  Future<void> _toggleLike(Tree tree, bool currentLiked) async {
    if (ref.read(authControllerProvider) != AuthStatus.authenticated) {
      _snack('Log in to like trees');
      return;
    }
    setState(() => _likeBusy = true);
    try {
      final repo = ref.read(treeRepositoryProvider);
      final count =
          currentLiked ? await repo.unlike(tree.id) : await repo.like(tree.id);
      if (!mounted) return;
      setState(() {
        _liked = !currentLiked;
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
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Tree not found'));
          }
          final tree = detail.tree;
          final liked = _liked ?? detail.liked;
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tree.commonName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                if (tree.scientificName.trim().isNotEmpty)
                                  Text(
                                    tree.scientificName,
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: earth.brown,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _likeBusy
                                ? null
                                : () => _toggleLike(tree, liked),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    liked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color:
                                        liked ? Colors.redAccent : earth.ink2,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$displayLikes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color:
                                          liked ? Colors.redAccent : earth.ink2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openDirections(tree),
                              icon: const Icon(Icons.directions_outlined,
                                  size: 19),
                              label: const Text('Directions'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _identifyWithPlantnet(
                                  detail, myId == tree.ownerId),
                              icon: const Icon(Icons.auto_awesome_rounded,
                                  size: 19),
                              label: const Text('Identify Species'),
                            ),
                          ),
                        ],
                      ),
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

  Future<void> _identifyWithPlantnet(TreeDetail detail, bool isOwner) async {
    final tree = detail.tree;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.cream50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _IdentifyResultSheet(
        tree: tree,
        detail: detail,
        isOwner: isOwner,
        ref: ref,
        onUpdate: (common, sci, conf) async {
          final body = <String, dynamic>{
            'commonName': common,
            if (sci != null && sci.isNotEmpty) 'scientificName': sci,
            if (conf != null && conf > 0) 'confidence': conf,
          };

          try {
            await ref.read(treeRepositoryProvider).updateTree(tree.id, body);
            ref.invalidate(treeDetailProvider(widget.treeId));
            ref.invalidate(feedProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tree details updated in database!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (_) {
            await ref.read(syncServiceProvider).enqueueUpdate(tree.id, body);
            ref.invalidate(syncQueueCountProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Saved offline. Will sync when backend is reachable.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
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
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
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

class _IdentifyResultSheet extends StatefulWidget {
  const _IdentifyResultSheet({
    required this.tree,
    required this.detail,
    required this.isOwner,
    required this.ref,
    required this.onUpdate,
  });

  final Tree tree;
  final TreeDetail detail;
  final bool isOwner;
  final WidgetRef ref;
  final Future<void> Function(
          String commonName, String? scientificName, int? confidence)
      onUpdate;

  @override
  State<_IdentifyResultSheet> createState() => _IdentifyResultSheetState();
}

class _IdentifyResultSheetState extends State<_IdentifyResultSheet> {
  bool _loading = true;
  bool _serviceUnavailable = false;
  String _errorMsg = '';
  List<SpeciesCandidate> _candidates = [];
  SpeciesCandidate? _selected;
  bool _updating = false;

  final _manualCommonCtrl = TextEditingController();
  final _manualSciCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _manualCommonCtrl.text = widget.tree.commonName;
    _manualSciCtrl.text = widget.tree.scientificName;
    _runIdentification();
  }

  @override
  void dispose() {
    _manualCommonCtrl.dispose();
    _manualSciCtrl.dispose();
    super.dispose();
  }

  Future<void> _runIdentification() async {
    setState(() {
      _loading = true;
      _serviceUnavailable = false;
      _errorMsg = '';
    });

    final dio = Dio();
    final photos = <CapturedPhoto>[];

    for (final p in widget.detail.photos) {
      final url = p.url ?? p.thumbUrl;
      if (url != null && url.isNotEmpty) {
        try {
          final res = await dio.get<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              sendTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );
          if (res.data != null && res.data!.isNotEmpty) {
            photos.add(CapturedPhoto(
              bytes: Uint8List.fromList(res.data!),
              organ: p.organ,
            ));
          }
        } catch (_) {}
      }
    }

    if (photos.isEmpty && widget.detail.heroImageUrl != null) {
      try {
        final res = await dio.get<List<int>>(
          widget.detail.heroImageUrl!,
          options: Options(
            responseType: ResponseType.bytes,
            sendTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        if (res.data != null && res.data!.isNotEmpty) {
          photos.add(CapturedPhoto(
            bytes: Uint8List.fromList(res.data!),
            organ: 'whole',
          ));
        }
      } catch (_) {}
    }

    if (photos.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _serviceUnavailable = true;
          _errorMsg =
              'Service currently unavailable. Could not connect to backend to retrieve photo data.';
        });
      }
      return;
    }

    try {
      final idService = widget.ref.read(identificationServiceProvider);
      final response = await idService.identifyPhotos(photos);
      if (!mounted) return;

      if (response.source == IdentifySource.unavailable ||
          response.candidates.isEmpty) {
        setState(() {
          _loading = false;
          _serviceUnavailable = true;
          _errorMsg =
              'Service currently unavailable. Pl@ntNet API servers are unreachable.';
        });
      } else {
        setState(() {
          _loading = false;
          _candidates = response.candidates;
          _selected = response.candidates.first;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _serviceUnavailable = true;
          _errorMsg =
              'Service currently unavailable. Identification network error.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: Palette.green700, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pl@ntNet Species Identification',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                  tooltip: 'Close',
                ),
              ],
            ),
            const Divider(height: 16),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: _buildBody(ctx),
              ),
            ),
            const SizedBox(height: 12),
            _buildFooter(ctx),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final earth = context.earth;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Downloading photos & analyzing with Pl@ntNet AI...'),
          ],
        ),
      );
    }

    if (_serviceUnavailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text(
                  'Service currently unavailable',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_errorMsg, style: TextStyle(color: earth.ink2)),
            if (widget.isOwner) ...[
              const SizedBox(height: 20),
              const Text(
                'Manual Species Details (Owner Update):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _manualCommonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Common Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _manualSciCtrl,
                decoration: const InputDecoration(
                  labelText: 'Scientific Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top AI Match Candidates:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
        ),
        const SizedBox(height: 10),
        ..._candidates.map((c) {
          final isSel = _selected == c;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: isSel ? Palette.green50 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSel ? Palette.green700 : Colors.black12,
                  width: isSel ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                onTap: widget.isOwner ? () => setState(() => _selected = c) : null,
                leading: Icon(
                  isSel
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSel ? Palette.green700 : Colors.grey,
                ),
                title: Text(
                  c.commonName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  c.scientificName,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                trailing: Pill(
                  '${c.confidence}% match',
                  tone: PillTone.green,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    if (_updating) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.isOwner) {
      return ElevatedButton.icon(
        onPressed: () async {
          setState(() => _updating = true);
          String common;
          String? sci;
          int? conf;

          if (_serviceUnavailable) {
            common = _manualCommonCtrl.text.trim();
            sci = _manualSciCtrl.text.trim();
          } else if (_selected != null) {
            common = _selected!.commonName;
            sci = _selected!.scientificName;
            conf = _selected!.confidence;
          } else {
            common = widget.tree.commonName;
          }

          if (common.isEmpty) return;

          Navigator.pop(context);
          await widget.onUpdate(common, sci, conf);
        },
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: const Text('Update Tree Details'),
      );
    }

    return OutlinedButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Close'),
    );
  }
}
