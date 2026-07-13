import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// On-device image privacy. The serverless pipeline repeats thumbnail
/// generation server-side, but stripping GPS here means exact coordinates
/// never leave the phone inside a public photo.
abstract final class ImagePrivacy {
  /// Re-encode as a clean JPEG, dropping ALL metadata (including GPS EXIF).
  static Uint8List stripMetadata(Uint8List input) {
    final decoded = img.decodeImage(input);
    if (decoded == null) return input;
    // encodeJpg writes pixel data only — EXIF/GPS is not carried over.
    return img.encodeJpg(decoded, quality: 90);
  }

  /// Client-side thumbnail (longest edge = [maxEdge]px). Mirrors the
  /// serverless thumbnailer so lists stay light while offline.
  static Uint8List thumbnail(Uint8List input, {int maxEdge = 480}) {
    final decoded = img.decodeImage(input);
    if (decoded == null) return input;
    final resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxEdge)
        : img.copyResize(decoded, height: maxEdge);
    return img.encodeJpg(resized, quality: 82);
  }
}
