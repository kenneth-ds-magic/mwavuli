import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../privacy/exif.dart';

class CapturedPhoto {
  const CapturedPhoto({
    required this.organ,
    required this.bytes,
    this.contentType = 'image/jpeg',
  });
  final String organ;
  final Uint8List bytes;
  final String contentType;
}

/// Captures from camera or gallery and strips EXIF/GPS on-device before the
/// bytes ever leave the phone (defence in depth; the server strips again).
class PhotoCapture {
  final ImagePicker _picker = ImagePicker();

  Future<CapturedPhoto?> pickAvatar({bool fromGallery = false}) async {
    final x = await _picker.pickImage(
      source: fromGallery ? ImageSource.gallery : ImageSource.camera,
      imageQuality: 92,
      maxWidth: 1024,
    );
    if (x == null) return null;
    final raw = await x.readAsBytes();
    final clean = ImagePrivacy.stripMetadata(raw);
    return CapturedPhoto(organ: 'avatar', bytes: clean);
  }

  Future<CapturedPhoto?> pick({
    required String organ,
    bool fromGallery = false,
  }) async {
    final x = await _picker.pickImage(
      source: fromGallery ? ImageSource.gallery : ImageSource.camera,
      imageQuality: 92,
      maxWidth: 2048,
    );
    if (x == null) return null;
    final raw = await x.readAsBytes();
    final clean = ImagePrivacy.stripMetadata(raw);
    return CapturedPhoto(organ: organ, bytes: clean);
  }
}

final photoCaptureProvider = Provider((_) => PhotoCapture());

/// Persists stripped photo bytes to disk while a log sits in the offline queue,
/// so photos survive an app restart and upload once connectivity returns.
class PhotoCache {
  Future<String> save(Uint8List bytes) async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory('${dir.path}/queue');
    if (!await folder.exists()) await folder.create(recursive: true);
    final path = '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<Uint8List?> read(String path) async {
    final f = File(path);
    return await f.exists() ? f.readAsBytes() : null;
  }

  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}

final photoCacheProvider = Provider((_) => PhotoCache());
