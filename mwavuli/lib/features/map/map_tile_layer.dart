import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// OpenStreetMap raster tiles with a grey fallback when a tile fetch fails
/// (DNS / TLS issues are common on Android emulators).
class MwavuliTileLayer extends StatelessWidget {
  const MwavuliTileLayer({super.key});

  /// Valid 8×8 light-grey PNG used when a tile request fails.
  static final ImageProvider _errorTile = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAD0lEQVR42mO4gwMwDC0JAHiIpQFQusoIAAAAAElFTkSuQmCC',
    ),
  );

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.mwavuli',
      retinaMode: false,
      panBuffer: 1,
      errorImage: _errorTile,
      errorTileCallback: (tile, error, stackTrace) {
        // DNS / offline: keep the map usable with [errorImage]; avoid spam.
      },
    );
  }
}
