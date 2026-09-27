import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../data/models/community.dart';

/// A single community activity line — styled with card elevation & micro-chips.
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
      ActivityKind.verify => (Icons.verified_rounded, Palette.green600),
      ActivityKind.comment =>
        (Icons.mode_comment_outlined, Palette.brown600),
      ActivityKind.follow => (Icons.person_add_rounded, Palette.green700),
      ActivityKind.log => (Icons.park_rounded, Palette.green600),
      ActivityKind.other => (Icons.notifications_outlined, Palette.brown600),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(Dims.gutter, 6, Dims.gutter, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F241D14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: item.isTappable ? () => _onTap(context, ref) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.text,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink,
                        ),
                      ),
                      if (item.quote != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Palette.cream100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Palette.cream200),
                          ),
                          child: Text(
                            '“${item.quote}”',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Palette.ink2,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (item.timeAgo.isNotEmpty)
                            Text(
                              item.timeAgo,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Palette.ink3,
                              ),
                            ),
                          if (item.isTappable) ...[
                            const Spacer(),
                            const Text(
                              'View detail →',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Palette.green700,
                              ),
                            ),
                          ],
                        ],
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
