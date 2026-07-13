import 'package:flutter/material.dart';

import '../app/theme.dart';

enum PillTone { green, gold, brown }

/// Small rounded status pill (verified, rare, fuzzy location, role…).
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.icon, this.tone = PillTone.green});

  final String label;
  final IconData? icon;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
    final (bg, fg) = switch (tone) {
      PillTone.green => (Palette.green100, Palette.green800),
      PillTone.gold => (earth.goldSoft, earth.goldInk),
      PillTone.brown => (earth.brownPill, Palette.brown700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(Dims.radiusPill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
