import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../data/models/community.dart';

/// A single community activity line — tappable when linked to a tree or user.
class ActivityRow extends ConsumerWidget {
  const ActivityRow(this.item, {super.key, this.onBeforeNavigate});

  final ActivityItem item;

  /// Called before routing (e.g. close a parent bottom sheet).
  final VoidCallback? onBeforeNavigate;

  void _onTap(BuildContext context, WidgetRef ref) {
    if (!item.isTappable) return;
    onBeforeNavigate?.call();
    final treeId = item.treeId;
    if (treeId != null) {
      context.push('/tree/$treeId');
      return;
    }
    final userId = item.userId ?? item.actorId;
    if (userId != null) {
      context.push('/user/$userId');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = switch (item.kind) {
      ActivityKind.badge => (Icons.star_rounded, Palette.gold500),
      ActivityKind.verify => (Icons.check_rounded, Palette.green600),
      ActivityKind.comment =>
        (Icons.mode_comment_outlined, Palette.brown600),
      ActivityKind.follow => (Icons.person_add_outlined, Palette.green700),
      ActivityKind.log => (Icons.eco_outlined, Palette.green600),
      ActivityKind.other => (Icons.notifications_outlined, Palette.brown600),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(Dims.gutter, 10, Dims.gutter, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.isTappable ? () => _onTap(context, ref) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    radius: 19,
                    backgroundColor: color,
                    child: Icon(icon, color: Colors.white, size: 19)),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.text,
                          style: const TextStyle(
                              fontSize: 13.5, height: 1.45)),
                      if (item.quote != null)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF4EDDD),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text('“${item.quote}”',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF4F4536))),
                        ),
                      if (item.timeAgo.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(item.timeAgo,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF77694F))),
                        ),
                      if (item.isTappable)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Tap to view',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Palette.green700)),
                        ),
                    ],
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
