import 'package:dio/dio.dart';

import '../../data/models/species.dart';
import '../camera/photo_capture.dart';
import '../privacy/exif.dart';

/// Direct Pl@ntNet REST API client in Dart.
/// Serves as an automatic fallback when the mwavuli-backend server is offline
/// or unreachable, allowing tree identification to function directly from the app.
class DirectPlantNetService {
  DirectPlantNetService({Dio? dio, String? apiKey})
      : _dio = dio ?? Dio(),
        _apiKey = apiKey ??
            const String.fromEnvironment(
              'PLANTNET_API_KEY',
              defaultValue: '2b10aTrjssyXHSESSqVfFzLle',
            );

  final Dio _dio;
  final String _apiKey;

  static const String _endpoint =
      'https://my-api.plantnet.org/v2/identify/all';

  bool get hasKey => _apiKey.trim().isNotEmpty;

  static String _plantNetOrgan(String organ) {
    switch (organ) {
      case 'leaf':
      case 'flower':
      case 'fruit':
      case 'bark':
        return organ;
      case 'whole':
        return 'habit';
      default:
        return 'auto';
    }
  }

  /// Query Pl@ntNet API directly using multipart form-data.
  Future<IdentifyResponse> identify(List<CapturedPhoto> photos) async {
    if (photos.isEmpty || !hasKey) {
      return const IdentifyResponse(
        candidates: [],
        source: IdentifySource.unavailable,
      );
    }

    try {
      final formData = FormData();
      for (final photo in photos) {
        final downscaled = ImagePrivacy.thumbnail(photo.bytes, maxEdge: 1280);
        formData.files.add(MapEntry(
          'images',
          MultipartFile.fromBytes(
            downscaled,
            filename: '${_plantNetOrgan(photo.organ)}.jpg',
            contentType: DioMediaType.parse('image/jpeg'),
          ),
        ));
        formData.fields.add(MapEntry('organs', _plantNetOrgan(photo.organ)));
      }

      final response = await _dio.post(
        _endpoint,
        queryParameters: {'api-key': _apiKey.trim()},
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final map = response.data as Map;
        final results = (map['results'] as List?) ?? const [];
        final candidates = results.take(5).map((r) {
          final species = (r as Map)['species'] as Map?;
          final commonNames =
              (species?['commonNames'] as List?)?.cast<String>();
          final sciName =
              species?['scientificNameWithoutAuthor'] as String? ?? '';
          final common = (commonNames != null && commonNames.isNotEmpty)
              ? commonNames.first
              : (sciName.isNotEmpty ? sciName : 'Unknown');
          final score = ((r['score'] as num?)?.toDouble() ?? 0.0) * 100;
          return SpeciesCandidate(
            commonName: common,
            scientificName: sciName,
            confidence: score.round(),
            photoTag: speciesPhotoTag(common),
          );
        }).toList();

        return IdentifyResponse(
          candidates: candidates,
          source: IdentifySource.plantnet,
        );
      }
    } catch (_) {
      // Direct API call failed or timed out
    }

    return const IdentifyResponse(
      candidates: [],
      source: IdentifySource.unavailable,
    );
  }
}
