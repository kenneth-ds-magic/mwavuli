import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api/media_url.dart';

/// Tree imagery: network thumbnail when available, otherwise a calm placeholder.
/// Pending/failed uploads show a processing state instead of a solid green block.
class TreePhoto extends StatelessWidget {
  const TreePhoto(
    this.tag, {
    super.key,
    this.height,
    this.borderRadius,
    this.child,
    this.imageUrl,
    this.photoStatus,
  });

  final String tag;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? child;
  final String? imageUrl;
  final String? photoStatus;

  static const _gradients = <String, List<Color>>{
    'oak': [Color(0xFF4C9138), Color(0xFF1F4715)],
    'maple': [Color(0xFFD1691F), Color(0xFF7A2A12)],
    'jac': [Color(0xFF7E6BB0), Color(0xFF4A3D78)],
    'pine': [Color(0xFF2B5A46), Color(0xFF12271F)],
    'birch': [Color(0xFFDFEED7), Color(0xFF8BBF78)],
    'cherry': [Color(0xFFF2A9C0), Color(0xFFB56B86)],
    'willow': [Color(0xFF7FB968), Color(0xFF3C7D2B)],
  };

  bool get _processing =>
      (imageUrl == null || imageUrl!.isEmpty) &&
      (photoStatus == 'pending' || photoStatus == 'failed');

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[tag] ?? _gradients['oak']!;
    final radius = borderRadius ?? BorderRadius.zero;
    final url = resolveMediaUrl(imageUrl);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && url.isNotEmpty)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _placeholder(colors, processing: false),
              )
            else
              _placeholder(colors, processing: _processing),
            if (child != null) child!,
          ],
        );

        // Horizontal lists / Rows pass infinite maxWidth — never force Infinity.
        final Widget box;
        if (height != null) {
          box = SizedBox(
            height: height,
            width: constraints.hasBoundedWidth ? double.infinity : height,
            child: stack,
          );
        } else if (constraints.hasBoundedWidth &&
            constraints.hasBoundedHeight) {
          box = SizedBox.expand(child: stack);
        } else {
          box = stack;
        }

        return ClipRRect(borderRadius: radius, child: box);
      },
    );
  }

  Widget _placeholder(List<Color> colors, {required bool processing}) {
    if (processing) {
      return ColoredBox(
        color: const Color(0xFFE8E0D0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                photoStatus == 'failed'
                    ? Icons.broken_image_outlined
                    : Icons.hourglass_top_rounded,
                size: 28,
                color: Palette.green800.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 6),
              Text(
                photoStatus == 'failed' ? 'Photo unavailable' : 'Processing…',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Palette.green800.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[0].withValues(alpha: 0.55),
            colors[1].withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.park_outlined,
          size: 36,
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
