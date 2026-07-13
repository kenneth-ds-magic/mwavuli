import 'community.dart';
import 'tree.dart';

class TrendingSpecies {
  const TrendingSpecies({
    required this.commonName,
    required this.treeCount,
    required this.sampleTree,
  });

  final String commonName;
  final int treeCount;
  final Tree sampleTree;

  factory TrendingSpecies.fromApi(Map<String, dynamic> j) => TrendingSpecies(
        commonName: j['commonName'] as String,
        treeCount: (j['treeCount'] as num).toInt(),
        sampleTree: Tree.fromApi((j['tree'] as Map).cast<String, dynamic>()),
      );
}

class ExploreData {
  const ExploreData({
    required this.treeCount,
    required this.trendingSpecies,
    this.nearbyCount,
    this.locationLabel,
    this.recentActivity = const [],
  });

  final int treeCount;
  final int? nearbyCount;
  final String? locationLabel;
  final List<TrendingSpecies> trendingSpecies;
  final List<ActivityItem> recentActivity;

  String headerSubtitle({String? localLocationLabel}) {
    // Prefer live GPS/Nominatim label over the saved profile location.
    final label = (localLocationLabel?.trim().isNotEmpty == true
            ? localLocationLabel
            : locationLabel)
        ?.trim();
    final total = _formatCount(treeCount);
    final nearby = nearbyCount;

    if (label != null && label.isNotEmpty) {
      if (nearby != null && nearby > 0) {
        return '$label · ${_formatCount(nearby)} nearby · $total mapped';
      }
      return '$label · $total trees mapped';
    }
    if (nearby != null && nearby > 0) {
      return '${_formatCount(nearby)} nearby · $total trees mapped';
    }
    return '$total trees mapped';
  }

  String mapTeaserLabel() {
    if (nearbyCount != null && nearbyCount! > 0) {
      return '${_formatCount(nearbyCount!)} trees nearby';
    }
    return '${_formatCount(treeCount)} trees mapped';
  }

  static String _formatCount(int n) {
    if (n >= 1000) {
      final s = (n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1);
      return '${s.replaceAll(RegExp(r'\.0$'), '')}k';
    }
    return n.toString();
  }

  factory ExploreData.fromApi(Map<String, dynamic> j) => ExploreData(
        treeCount: (j['treeCount'] as num?)?.toInt() ?? 0,
        nearbyCount: (j['nearbyCount'] as num?)?.toInt(),
        locationLabel: j['locationLabel'] as String?,
        trendingSpecies: ((j['trendingSpecies'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(TrendingSpecies.fromApi)
            .toList(),
        recentActivity: ((j['recentActivity'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ActivityItem.fromApi)
            .toList(),
      );
}

/// Server-side explore feed query (maps to GET /v1/feed).
class ExploreFeedQuery {
  const ExploreFeedQuery({
    this.search = '',
    this.filter = 'all',
    this.lat,
    this.lng,
    this.radiusM = 50000,
  });

  final String search;
  final String filter;
  final double? lat;
  final double? lng;
  final int radiusM;

  ExploreFeedQuery copyWith({
    String? search,
    String? filter,
    double? lat,
    double? lng,
    int? radiusM,
  }) =>
      ExploreFeedQuery(
        search: search ?? this.search,
        filter: filter ?? this.filter,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        radiusM: radiusM ?? this.radiusM,
      );

  @override
  bool operator ==(Object other) =>
      other is ExploreFeedQuery &&
      other.search == search &&
      other.filter == filter &&
      other.lat == lat &&
      other.lng == lng &&
      other.radiusM == radiusM;

  @override
  int get hashCode => Object.hash(search, filter, lat, lng, radiusM);
}

/// Device location context for explore stats (lat/lng + optional geocoded label).
class ExploreLocation {
  const ExploreLocation({this.lat, this.lng, this.label});
  final double? lat;
  final double? lng;
  final String? label;

  ExploreLocation copyWith({double? lat, double? lng, String? label}) =>
      ExploreLocation(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) =>
      other is ExploreLocation &&
      other.lat == lat &&
      other.lng == lng &&
      other.label == label;

  @override
  int get hashCode => Object.hash(lat, lng, label);
}

/// Filter chip labels in UI order → API filter keys.
const exploreFilterKeys = [
  'all',
  'near',
  'oak',
  'flowering',
  'autumn',
  'rare',
  'native',
];

const exploreFilterLabels = [
  'All',
  'Near me',
  'Oaks',
  'Flowering',
  'Autumn colour',
  'Rare',
  'Native',
];
