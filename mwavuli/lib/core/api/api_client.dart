import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/species.dart';
import '../../data/models/tree.dart';
import '../../data/models/tree_comment.dart';
import '../../data/models/explore.dart';
import '../../data/models/community.dart';
import '../camera/photo_capture.dart';
import 'api_config.dart';
import 'token_store.dart';

/// Typed client for the mwavuli API. All traffic is HTTPS (TLS). Attaches the
/// bearer token, and transparently refreshes + retries once on a 401.
class ApiClient {
  ApiClient(this._tokens, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'accept': 'application/json'},
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final t = await _tokens.accessToken();
        if (t != null) options.headers['authorization'] = 'Bearer $t';
        handler.next(options);
      },
      onError: (e, handler) async {
        final canRetry = e.response?.statusCode == 401 &&
            e.requestOptions.extra['retried'] != true &&
            await _tokens.refreshToken() != null;
        if (canRetry) {
          try {
            await _refresh();
            final req = e.requestOptions..extra['retried'] = true;
            final t = await _tokens.accessToken();
            req.headers['authorization'] = 'Bearer $t';
            return handler.resolve(await _dio.fetch(req));
          } catch (_) {/* fall through */}
        }
        handler.next(e);
      },
    ));
  }

  final Dio _dio;
  final TokenStore _tokens;
  DateTime? _feedCooldownUntil;

  bool get _feedInCooldown =>
      _feedCooldownUntil != null &&
      DateTime.now().isBefore(_feedCooldownUntil!);

  void _armFeedCooldown() {
    _feedCooldownUntil = DateTime.now().add(const Duration(seconds: 30));
  }

  // --- Auth ---
  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String displayName,
    required int birthYear,
  }) async {
    final r = await _dio.post('/v1/auth/register', data: {
      'email': email, 'username': username, 'password': password,
      'displayName': displayName, 'birthYear': birthYear, 'acceptTos': true,
    });
    await _saveTokens(r.data);
  }

  Future<void> login(String identifier, String password) async {
    final r = await _dio.post('/v1/auth/login',
        data: {'identifier': identifier, 'password': password});
    await _saveTokens(r.data);
  }

  Future<void> logout() async {
    final rt = await _tokens.refreshToken();
    if (rt != null) {
      try {
        await _dio.post('/v1/auth/logout', data: {'refreshToken': rt});
      } catch (_) {}
    }
    await _tokens.clear();
  }

  Future<void> _refresh() async {
    final rt = await _tokens.refreshToken();
    final r = await _dio.post('/v1/auth/refresh', data: {'refreshToken': rt});
    await _saveTokens(r.data);
  }

  Future<void> _saveTokens(dynamic d) async {
    await _tokens.save(
        access: d['accessToken'] as String, refresh: d['refreshToken'] as String);
  }

  // --- Trees / feed ---
  Future<List<Tree>> fetchFeed({
    String? bbox,
    String? before,
    int limit = 50,
    String? search,
    String filter = 'all',
    double? lat,
    double? lng,
    int radiusM = 50000,
  }) async {
    if (_feedInCooldown) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v1/feed'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/feed'),
          statusCode: 429,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    try {
      final r = await _dio.get('/v1/feed', queryParameters: {
        'limit': limit,
        if (bbox != null) 'bbox': bbox,
        if (before != null) 'before': before,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (filter != 'all') 'filter': filter,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (filter == 'near' || lat != null) 'radiusM': radiusM,
      });
      final items = (r.data['items'] as List).cast<Map<String, dynamic>>();
      return items.map(Tree.fromApi).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) _armFeedCooldown();
      rethrow;
    }
  }

  Future<({bool verified, int verificationCount, bool userVerified})>
      verifyTree(String treeId) async {
    final r = await _dio.post('/v1/trees/$treeId/verify');
    final d = (r.data as Map).cast<String, dynamic>();
    return (
      verified: d['verified'] as bool? ?? false,
      verificationCount: (d['verificationCount'] as num?)?.toInt() ?? 0,
      userVerified: d['userVerified'] as bool? ?? false,
    );
  }

  Future<void> processPhoto(String photoId) async {
    await _dio.post('/v1/photos/$photoId/process');
  }

  /// Upload JPEG/PNG bytes via the API (avoids direct MinIO from mobile).
  Future<void> uploadPhoto(
    String photoId,
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) async {
    await _dio.put(
      '/v1/photos/$photoId/upload',
      data: bytes,
      options: Options(
        contentType: contentType,
        headers: {Headers.contentLengthHeader: bytes.length},
      ),
    );
  }

  Future<Tree> fetchTree(String id) async {
    return (await fetchTreeDetail(id)).tree;
  }

  Future<TreeDetail> fetchTreeDetail(String id) async {
    final r = await _dio.get('/v1/trees/$id');
    final data = (r.data as Map).cast<String, dynamic>();
    final photos = ((data['photos'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(TreePhotoRef.fromApi)
        .toList();
    return TreeDetail(
      tree: Tree.fromApi((data['tree'] as Map).cast<String, dynamic>()),
      photos: photos,
      saved: data['saved'] as bool? ?? false,
      verificationCount: (data['verificationCount'] as num?)?.toInt() ?? 0,
      userVerified: data['userVerified'] as bool? ?? false,
      verificationsRequired:
          (data['verificationsRequired'] as num?)?.toInt() ?? 2,
    );
  }

  /// Create a tree. Returns `{ tree, uploads, rewards }`.
  Future<Map<String, dynamic>> createTree(Map<String, dynamic> body) async {
    final r = await _dio.post('/v1/trees', data: body);
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<({double lat, double lng, double? accuracyM})> exactLocation(String treeId) async {
    final r = await _dio.get('/v1/trees/$treeId/exact-location');
    return (
      lat: (r.data['lat'] as num).toDouble(),
      lng: (r.data['lng'] as num).toDouble(),
      accuracyM: (r.data['accuracyM'] as num?)?.toDouble(),
    );
  }

  Future<int> like(String id) async {
    final r = await _dio.post('/v1/trees/$id/like');
    return (r.data['likeCount'] as num?)?.toInt() ?? 0;
  }

  Future<int> unlike(String id) async {
    final r = await _dio.delete('/v1/trees/$id/like');
    return (r.data['likeCount'] as num?)?.toInt() ?? 0;
  }

  Future<List<TreeComment>> fetchComments(String treeId) async {
    final r = await _dio.get('/v1/trees/$treeId/comments');
    return ((r.data['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(TreeComment.fromApi)
        .toList();
  }

  Future<TreeComment> postComment(String treeId, String body) async {
    final r = await _dio.post('/v1/trees/$treeId/comments', data: {'body': body});
    final data = (r.data as Map).cast<String, dynamic>();
    return TreeComment(
      id: data['id'] as String,
      body: data['body'] as String,
      author: 'You',
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    await _dio.post('/v1/reports', data: {
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      if (details != null && details.isNotEmpty) 'details': details,
    });
  }

  Future<bool> saveTree(String id) async {
    final r = await _dio.post('/v1/trees/$id/save');
    return (r.data['saved'] as bool?) ?? true;
  }

  Future<bool> unsaveTree(String id) async {
    final r = await _dio.delete('/v1/trees/$id/save');
    return (r.data['saved'] as bool?) ?? false;
  }

  Future<List<Tree>> fetchSavedTrees() async {
    final r = await _dio.get('/v1/me/saved');
    return ((r.data['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Tree.fromApi)
        .toList();
  }

  Future<ExploreData> fetchExplore({
    double? lat,
    double? lng,
    int radiusM = 50000,
    int trendingLimit = 8,
    int activityLimit = 8,
  }) async {
    final r = await _dio.get('/v1/explore', queryParameters: {
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'radiusM': radiusM,
      'trendingLimit': trendingLimit,
      'activityLimit': activityLimit,
    });
    return ExploreData.fromApi((r.data as Map).cast<String, dynamic>());
  }

  Future<List<ActivityItem>> fetchActivity({
    int limit = 20,
    String? before,
  }) async {
    final r = await _dio.get('/v1/activity', queryParameters: {
      'limit': limit,
      if (before != null) 'before': before,
    });
    return ((r.data['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ActivityItem.fromApi)
        .toList();
  }

  Future<({List<LeaderboardEntry> items, bool hasMore, String period})>
      fetchLeaderboard({int limit = 20, int offset = 0}) async {
    final r = await _dio.get('/v1/leaderboard', queryParameters: {
      'limit': limit,
      'offset': offset,
    });
    final d = (r.data as Map).cast<String, dynamic>();
    final items = ((d['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromApi)
        .toList();
    return (
      items: items,
      hasMore: d['hasMore'] as bool? ?? items.length >= limit,
      period: d['period'] as String? ?? 'week',
    );
  }

  // --- Profile ---
  Future<Map<String, dynamic>> fetchMe() async {
    final r = await _dio.get('/v1/me');
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateMe({
    String? displayName,
    String? bio,
    String? locationLabel,
  }) async {
    final r = await _dio.patch('/v1/me', data: {
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio.isEmpty ? null : bio,
      if (locationLabel != null)
        'locationLabel': locationLabel.isEmpty ? null : locationLabel,
    });
    return (r.data as Map).cast<String, dynamic>();
  }

  /// Returns `{ uploadUrl, key }` for a presigned PUT to the private bucket.
  Future<Map<String, dynamic>> requestAvatarUpload({
    String contentType = 'image/jpeg',
  }) async {
    final r = await _dio.post('/v1/me/avatar', data: {'contentType': contentType});
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> fetchFollowing() async {
    final r = await _dio.get('/v1/me/following');
    return ((r.data['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchFollowers() async {
    final r = await _dio.get('/v1/me/followers');
    return ((r.data['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchMyReports() async {
    final r = await _dio.get('/v1/me/reports');
    return ((r.data['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchCommunity() async {
    final r = await _dio.get('/v1/community');
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> searchUsers(String q) async {
    final r = await _dio.get('/v1/users/search', queryParameters: {'q': q});
    return ((r.data['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchUser(String userId) async {
    final r = await _dio.get('/v1/users/$userId');
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<void> followUser(String userId) =>
      _dio.post('/v1/users/$userId/follow');

  Future<void> unfollowUser(String userId) =>
      _dio.delete('/v1/users/$userId/follow');

  // --- Identify ---
  Future<IdentifyResponse> identifyPhotos(
    List<CapturedPhoto> photos,
  ) async {
    final r = await _dio.post('/v1/identify', data: {
      'images': photos
          .map((p) => {
                'organ': _organForApi(p.organ),
                'data': base64Encode(p.bytes),
                'contentType': p.contentType,
              })
          .toList(),
    });
    return _parseIdentifyResponse(r.data);
  }

  Future<IdentifyResponse> identify(List<String> imageUrls,
      {List<String>? organs}) async {
    final r = await _dio.post('/v1/identify', data: {
      'imageUrls': imageUrls,
      if (organs != null) 'organs': organs,
    });
    return _parseIdentifyResponse(r.data);
  }

  IdentifyResponse _parseIdentifyResponse(dynamic data) {
    final map = data as Map;
    final cands =
        ((map['candidates'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final sourceRaw = map['source'] as String? ?? 'unavailable';
    final source = switch (sourceRaw) {
      'plantnet' => IdentifySource.plantnet,
      'stub' => IdentifySource.stub,
      _ => IdentifySource.unavailable,
    };
    return IdentifyResponse(
      source: source,
      candidates: cands.map((c) {
        final common = c['commonName'] as String? ?? 'Unknown';
        return SpeciesCandidate(
          commonName: common,
          scientificName: c['scientificName'] as String? ?? '',
          confidence: (c['confidence'] as num?)?.toInt() ?? 0,
          photoTag: speciesPhotoTag(common),
        );
      }).toList(),
    );
  }

  static String _organForApi(String organ) {
    const allowed = {'whole', 'bark', 'leaf', 'flower', 'fruit'};
    return allowed.contains(organ) ? organ : 'whole';
  }

  // --- GDPR ---
  Future<dynamic> exportData({String format = 'json'}) async {
    final r = await _dio.post('/v1/me/export', queryParameters: {'format': format});
    return r.data;
  }

  Future<void> scheduleDeletion() => _dio.post('/v1/me/deletion');
  Future<void> cancelDeletion() => _dio.delete('/v1/me/deletion');
}

final apiClientProvider =
    Provider((ref) => ApiClient(ref.watch(tokenStoreProvider)));
