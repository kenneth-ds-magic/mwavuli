import 'package:latlong2/latlong.dart';

import '../../core/api/media_url.dart';

enum TreeHealth { healthy, stressed, dead, unknown }

enum TreeVisibility { public, followers, private }

extension TreeHealthX on TreeHealth {
  String get label => switch (this) {
        TreeHealth.healthy => 'Healthy',
        TreeHealth.stressed => 'Stressed',
        TreeHealth.dead => 'Dead',
        TreeHealth.unknown => 'Unknown',
      };
}

/// A single logged tree.
///
/// Privacy model: [exactLocation] is the precise GPS point and is
/// access-controlled server-side. The public API returns [fuzzyLocation]
/// (randomised within ~500 m) when [isFuzzy] is true.
class Tree {
  const Tree({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.photoTag,
    required this.heightMeters,
    required this.ageEstimate,
    required this.health,
    required this.girthMeters,
    required this.confidence,
    required this.verified,
    required this.contributor,
    required this.description,
    this.ownerId,
    this.likeCount = 0,
    this.commentCount = 0,
    this.features = const [],
    this.exactLocation,
    this.fuzzyLocation,
    this.isFuzzy = true,
    this.visibility = TreeVisibility.public,
    this.synced = true,
    this.thumbUrl,
    this.photoStatus,
    this.createdAt,
  });

  final String id;
  final String commonName;
  final String scientificName;

  /// Key into the scaffold's placeholder imagery (e.g. 'oak', 'maple').
  /// In production this is a thumbnail URL from the serverless image pipeline.
  final String photoTag;

  final double heightMeters;
  final String ageEstimate;
  final TreeHealth health;
  final double girthMeters;
  final int confidence; // ID confidence %
  final bool verified; // community-verified ID
  final String contributor;
  final String description;
  final String? ownerId;
  final int likeCount;
  final int commentCount;
  final List<String> features;

  final LatLng? exactLocation; // access-controlled
  final LatLng? fuzzyLocation; // public
  final bool isFuzzy;
  final TreeVisibility visibility;
  final bool synced; // false = queued in the offline sync queue
  final String? thumbUrl;
  /// `processed` | `pending` | `failed` when the API reports photo pipeline state.
  final String? photoStatus;
  final DateTime? createdAt;

  /// True when a photo exists but derivatives are not ready yet.
  bool get photoProcessing =>
      thumbUrl == null &&
      (photoStatus == 'pending' || photoStatus == 'failed');

  /// The point safe to render on a public map.
  LatLng? get displayLocation => isFuzzy ? fuzzyLocation : exactLocation;

  Tree copyWith({
    bool? synced,
    bool? verified,
    int? likeCount,
    int? commentCount,
    String? thumbUrl,
    String? photoStatus,
  }) => Tree(
        id: id,
        commonName: commonName,
        scientificName: scientificName,
        photoTag: photoTag,
        heightMeters: heightMeters,
        ageEstimate: ageEstimate,
        health: health,
        girthMeters: girthMeters,
        confidence: confidence,
        verified: verified ?? this.verified,
        contributor: contributor,
        description: description,
        ownerId: ownerId,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        features: features,
        exactLocation: exactLocation,
        fuzzyLocation: fuzzyLocation,
        isFuzzy: isFuzzy,
        visibility: visibility,
        synced: synced ?? this.synced,
        thumbUrl: thumbUrl ?? this.thumbUrl,
        photoStatus: photoStatus ?? this.photoStatus,
        createdAt: createdAt,
      );

  /// Persist a tree in the on-device SQLite cache (survives restarts).
  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'commonName': commonName,
        'scientificName': scientificName,
        'photoTag': photoTag,
        'heightMeters': heightMeters,
        'ageEstimate': ageEstimate,
        'health': health.name,
        'girthMeters': girthMeters,
        'confidence': confidence,
        'verified': verified,
        'contributor': contributor,
        'description': description,
        'ownerId': ownerId,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'features': features,
        'exactLocation': exactLocation == null
            ? null
            : {'lat': exactLocation!.latitude, 'lng': exactLocation!.longitude},
        'fuzzyLocation': fuzzyLocation == null
            ? null
            : {'lat': fuzzyLocation!.latitude, 'lng': fuzzyLocation!.longitude},
        'isFuzzy': isFuzzy,
        'visibility': visibility.name,
        'synced': synced,
        'thumbUrl': thumbUrl,
        'photoStatus': photoStatus,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Tree.fromCacheJson(Map<String, dynamic> j) => Tree(
        id: j['id'] as String,
        commonName: j['commonName'] as String? ?? 'Unknown',
        scientificName: j['scientificName'] as String? ?? '',
        photoTag: j['photoTag'] as String? ?? 'oak',
        heightMeters: (j['heightMeters'] as num?)?.toDouble() ?? 0,
        ageEstimate: j['ageEstimate'] as String? ?? '—',
        health: TreeHealth.values.firstWhere(
            (h) => h.name == j['health'], orElse: () => TreeHealth.unknown),
        girthMeters: (j['girthMeters'] as num?)?.toDouble() ?? 0,
        confidence: (j['confidence'] as num?)?.toInt() ?? 0,
        verified: j['verified'] as bool? ?? false,
        contributor: j['contributor'] as String? ?? 'Unknown',
        description: j['description'] as String? ?? '',
        ownerId: j['ownerId'] as String?,
        likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
        commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
        features: (j['features'] as List?)?.cast<String>() ?? const [],
        exactLocation: _loc(j['exactLocation'] as Map<String, dynamic>?),
        fuzzyLocation: _loc(j['fuzzyLocation'] as Map<String, dynamic>?),
        isFuzzy: j['isFuzzy'] as bool? ?? true,
        visibility: TreeVisibility.values.firstWhere(
            (v) => v.name == j['visibility'],
            orElse: () => TreeVisibility.public),
        synced: j['synced'] as bool? ?? true,
        thumbUrl: resolveMediaUrl(j['thumbUrl'] as String?),
        photoStatus: j['photoStatus'] as String?,
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.tryParse(j['createdAt'] as String),
      );

  /// Used by the API client and the GDPR data-export feature.
  Map<String, dynamic> toJson() => {
        'id': id,
        'common_name': commonName,
        'scientific_name': scientificName,
        'photo_tag': photoTag,
        'height_m': heightMeters,
        'age_estimate': ageEstimate,
        'health': health.name,
        'girth_m': girthMeters,
        'confidence': confidence,
        'verified': verified,
        'contributor': contributor,
        'description': description,
        'features': features,
        // Exact coords only included in the owner's private export.
        'exact_location': exactLocation == null
            ? null
            : {'lat': exactLocation!.latitude, 'lng': exactLocation!.longitude},
        'fuzzy_location': fuzzyLocation == null
            ? null
            : {'lat': fuzzyLocation!.latitude, 'lng': fuzzyLocation!.longitude},
        'is_fuzzy': isFuzzy,
        'visibility': visibility.name,
        'synced': synced,
      };

  static LatLng? _loc(Map<String, dynamic>? m) =>
      m == null ? null : LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());

  /// Parse the API's public tree DTO (camelCase; fuzzy location only — the
  /// public payload never contains exact coordinates). See GET /v1/feed.
  factory Tree.fromApi(Map<String, dynamic> j) => Tree(
        id: j['id'] as String,
        commonName: j['commonName'] as String? ?? 'Unknown',
        scientificName: j['scientificName'] as String? ?? '',
        photoTag: _guessTag(j['commonName'] as String? ?? ''),
        heightMeters: (j['heightM'] as num?)?.toDouble() ?? 0,
        ageEstimate: j['ageEstimate'] as String? ?? '—',
        health: TreeHealth.values.firstWhere(
            (h) => h.name == j['health'], orElse: () => TreeHealth.unknown),
        girthMeters: (j['girthM'] as num?)?.toDouble() ?? 0,
        confidence: (j['confidence'] as num?)?.toInt() ?? 0,
        verified: j['verified'] as bool? ?? false,
        contributor: j['contributor'] as String? ?? 'Unknown',
        description: j['description'] as String? ?? '',
        ownerId: j['ownerId'] as String?,
        likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
        commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
        features: (j['features'] as List?)?.cast<String>() ?? const [],
        fuzzyLocation: _loc(j['fuzzyLocation'] as Map<String, dynamic>?),
        isFuzzy: j['isFuzzy'] as bool? ?? true,
        visibility: TreeVisibility.values.firstWhere(
            (v) => v.name == j['visibility'], orElse: () => TreeVisibility.public),
        synced: true,
        thumbUrl: resolveMediaUrl(j['thumbUrl'] as String?),
        photoStatus: j['photoStatus'] as String?,
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.tryParse(j['createdAt'] as String),
      );

  /// Request body for POST /v1/trees. Sends the EXACT captured point; the
  /// server stores it privately and derives/refreshes the public fuzzy point.
  Map<String, dynamic> toCreateRequest() => {
        'commonName': commonName,
        if (scientificName.isNotEmpty) 'scientificName': scientificName,
        'health': health.name,
        if (heightMeters > 0) 'heightM': heightMeters,
        if (girthMeters > 0) 'girthM': girthMeters,
        if (ageEstimate.isNotEmpty) 'ageEstimate': ageEstimate,
        if (description.isNotEmpty) 'description': description,
        'features': features,
        if (confidence > 0) 'confidence': confidence,
        'visibility': visibility.name,
        'isFuzzy': isFuzzy,
        'lat': exactLocation?.latitude,
        'lng': exactLocation?.longitude,
      };

  static String _guessTag(String name) {
    final n = name.toLowerCase();
    if (n.contains('oak')) return 'oak';
    if (n.contains('maple')) return 'maple';
    if (n.contains('pine') || n.contains('spruce') || n.contains('fir')) return 'pine';
    if (n.contains('birch')) return 'birch';
    if (n.contains('cherry') || n.contains('blossom')) return 'cherry';
    if (n.contains('willow')) return 'willow';
    if (n.contains('jacaranda')) return 'jac';
    return 'oak';
  }
}
