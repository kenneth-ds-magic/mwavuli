import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/models/tree.dart';
import 'pill.dart';
import 'tree_photo.dart';

/// Community-feed card for a single tree.
class TreeCard extends StatelessWidget {
  const TreeCard({super.key, required this.tree, required this.onTap});

  final Tree tree;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TreePhoto(
              tree.photoTag,
              imageUrl: tree.thumbUrl,
              photoStatus: tree.photoStatus,
              height: 180,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _imgTag(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                        radius: 15,
                        backgroundColor: Palette.green300,
                        child: Text(tree.contributor.characters.first,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12))),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tree.contributor,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                              tree.isFuzzy
                                  ? 'fuzzy location'
                                  : 'exact location',
                              style: TextStyle(
                                  fontSize: 11.5, color: earth.ink3)),
                        ],
                      ),
                    ),
                    if (tree.verified)
                      const Pill('ID verified',
                          icon: Icons.check_rounded, tone: PillTone.green),
                  ]),
                  const SizedBox(height: 10),
                  Text(tree.commonName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Palette.green900)),
                  Text(tree.scientificName,
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: earth.brown,
                          fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Text(tree.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: earth.ink2)),
                  const SizedBox(height: 11),
                  const Divider(),
                  const SizedBox(height: 4),
                  Row(children: [
                    _MetaAction(Icons.favorite_border_rounded,
                        '${tree.likeCount}'),
                    const SizedBox(width: 16),
                    _MetaAction(Icons.mode_comment_outlined,
                        '${tree.commentCount}'),
                    const Spacer(),
                    _MetaAction(Icons.arrow_forward_rounded, 'View',
                        onTap: onTap),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgTag() {
    final label =
        tree.synced ? 'ID ${tree.confidence}%' : 'Queued offline';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _MetaAction extends StatelessWidget {
  const _MetaAction(this.icon, this.label, {this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: context.earth.ink2),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: context.earth.ink2)),
        ]),
      ),
    );
  }
}
