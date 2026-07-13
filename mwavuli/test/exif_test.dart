import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mwavuli/core/privacy/exif.dart';

void main() {
  test('stripMetadata re-encodes a valid JPEG at the same size', () {
    final src = img.Image(width: 64, height: 48);
    img.fill(src, color: img.ColorRgb8(20, 120, 60));
    final jpg = Uint8List.fromList(img.encodeJpg(src));

    final stripped = ImagePrivacy.stripMetadata(jpg);
    final decoded = img.decodeImage(stripped);
    expect(decoded, isNotNull);
    expect(decoded!.width, 64);
    expect(decoded.height, 48);
  });

  test('thumbnail bounds the longest edge', () {
    final src = img.Image(width: 1200, height: 600);
    final jpg = Uint8List.fromList(img.encodeJpg(src));
    final thumb = ImagePrivacy.thumbnail(jpg, maxEdge: 480);
    final decoded = img.decodeImage(thumb)!;
    expect(decoded.width <= 480, isTrue);
  });
}
