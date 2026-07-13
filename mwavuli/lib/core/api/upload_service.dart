import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Uploads raw bytes to a presigned S3 URL. No auth header — the URL itself is
/// signed. The Content-Type must match what the API signed (image/jpeg).
class UploadService {
  final Dio _dio = Dio();

  Future<void> putBytes(
    String url,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    await _dio.put(
      url,
      data: Stream.value(bytes),
      options: Options(
        contentType: contentType,
        headers: {Headers.contentLengthHeader: bytes.length},
      ),
    );
  }
}

final uploadServiceProvider = Provider((_) => UploadService());
