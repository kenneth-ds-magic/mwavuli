import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/species.dart';
import '../../data/models/tree.dart';
import '../api/api_client.dart';
import '../camera/photo_capture.dart';

/// Tree identification from captured organ photos.
abstract interface class IdentificationService {
  Future<IdentifyResponse> identifyPhotos(List<CapturedPhoto> photos);
}

/// Calls POST /v1/identify with base64 JPEG bytes from the capture step.
/// Does not invent fake matches on failure — errors propagate to the UI.
class RemoteIdentificationService implements IdentificationService {
  RemoteIdentificationService(this._api);
  final ApiClient _api;

  @override
  Future<IdentifyResponse> identifyPhotos(List<CapturedPhoto> photos) async {
    if (photos.isEmpty) {
      return const IdentifyResponse(
        candidates: [],
        source: IdentifySource.unavailable,
      );
    }
    return _api.identifyPhotos(photos);
  }
}

final identificationServiceProvider = Provider<IdentificationService>(
    (ref) => RemoteIdentificationService(ref.watch(apiClientProvider)));

/// Rewards returned after POST /v1/trees.
class LogRewards {
  const LogRewards({
    required this.pointsEarned,
    required this.totalPoints,
    required this.level,
    required this.levelName,
  });

  final int pointsEarned;
  final int totalPoints;
  final int level;
  final String levelName;

  factory LogRewards.fromApi(Map<String, dynamic>? j) {
    if (j == null) {
      return const LogRewards(
          pointsEarned: 10, totalPoints: 0, level: 1, levelName: 'Seedling');
    }
    return LogRewards(
      pointsEarned: (j['pointsEarned'] as num?)?.toInt() ?? 10,
      totalPoints: (j['totalPoints'] as num?)?.toInt() ?? 0,
      level: (j['level'] as num?)?.toInt() ?? 1,
      levelName: j['levelName'] as String? ?? 'Seedling',
    );
  }
}

/// Result of a successful tree log submission.
class LogSubmitResult {
  const LogSubmitResult({
    required this.treeId,
    required this.commonName,
    this.rewards,
    this.queued = false,
    this.isFuzzy = true,
    this.visibility = TreeVisibility.public,
  });

  final String treeId;
  final String commonName;
  final LogRewards? rewards;
  final bool queued;
  final bool isFuzzy;
  final TreeVisibility visibility;
}
