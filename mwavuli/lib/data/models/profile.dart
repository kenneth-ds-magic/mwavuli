import 'tree.dart';

/// Signed-in user profile from GET /v1/me.
class MeProfile {
  const MeProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.avatarUrl,
    required this.points,
    required this.level,
    required this.levelName,
    required this.locationLabel,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String username;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final int points;
  final int level;
  final String levelName;
  final String? locationLabel;
  final DateTime createdAt;

  String get handle => '@$username';

  /// First letter of the display name (first name).
  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) {
      return username.isNotEmpty ? username[0].toUpperCase() : '?';
    }
    final first =
        name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).first;
    return first[0].toUpperCase();
  }

  bool get hasAvatar => avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  factory MeProfile.fromApi(Map<String, dynamic> j) => MeProfile(
        id: j['id'] as String,
        email: j['email'] as String,
        username: j['username'] as String,
        displayName: j['displayName'] as String? ?? 'User',
        bio: j['bio'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        points: (j['points'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? 1,
        levelName: j['levelName'] as String? ?? 'Seedling',
        locationLabel: j['locationLabel'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class ProfileBadge {
  const ProfileBadge({
    required this.code,
    required this.name,
    required this.icon,
    required this.awardedAt,
  });

  final String code;
  final String name;
  final String? icon;
  final DateTime awardedAt;

  factory ProfileBadge.fromApi(Map<String, dynamic> j) => ProfileBadge(
        code: j['code'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String?,
        awardedAt: DateTime.parse(j['awardedAt'] as String),
      );
}

class TopSpeciesStat {
  const TopSpeciesStat({required this.name, required this.count});
  final String name;
  final int count;

  factory TopSpeciesStat.fromApi(Map<String, dynamic> j) => TopSpeciesStat(
        name: j['name'] as String,
        count: (j['count'] as num).toInt(),
      );
}

class MonthlyContribution {
  const MonthlyContribution({required this.month, required this.count});
  final String month;
  final int count;

  static const _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Ensures the chart always has six month slots (current month and prior five).
  static List<MonthlyContribution> fillLastSixMonths(
    List<MonthlyContribution> raw,
  ) {
    final lookup = <String, int>{
      for (final item in raw) item.month.trim().toLowerCase(): item.count,
    };
    final now = DateTime.now();
    final anchor = DateTime(now.year, now.month, 1);

    return [
      for (var offset = 5; offset >= 0; offset--)
        MonthlyContribution(
          month: _monthLabel(DateTime(anchor.year, anchor.month - offset, 1)),
          count: lookup[_monthLabel(
                DateTime(anchor.year, anchor.month - offset, 1),
              ).toLowerCase()] ??
              0,
        ),
    ];
  }

  static String _monthLabel(DateTime date) => _monthLabels[date.month - 1];

  factory MonthlyContribution.fromApi(Map<String, dynamic> j) =>
      MonthlyContribution(
        month: (j['month'] as String).trim(),
        count: (j['count'] as num).toInt(),
      );
}

class ProfileData {
  const ProfileData({
    required this.profile,
    required this.following,
    required this.followers,
    required this.treeCount,
    required this.speciesCount,
    required this.points,
    required this.badges,
    required this.trees,
    required this.topSpecies,
    required this.contributions,
  });

  final MeProfile profile;
  final int following;
  final int followers;
  final int treeCount;
  final int speciesCount;
  final int points;
  final List<ProfileBadge> badges;
  final List<Tree> trees;
  final List<TopSpeciesStat> topSpecies;
  final List<MonthlyContribution> contributions;

  factory ProfileData.fromApi(Map<String, dynamic> j) {
    final profile = MeProfile.fromApi(
        (j['profile'] as Map).cast<String, dynamic>());
    final social = (j['social'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stats = (j['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ProfileData(
      profile: profile,
      following: (social['following'] as num?)?.toInt() ?? 0,
      followers: (social['followers'] as num?)?.toInt() ?? 0,
      treeCount: (stats['trees'] as num?)?.toInt() ?? 0,
      speciesCount: (stats['species'] as num?)?.toInt() ?? 0,
      points: (stats['points'] as num?)?.toInt() ?? profile.points,
      badges: ((j['badges'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(ProfileBadge.fromApi)
          .toList(),
      trees: ((j['trees'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Tree.fromApi)
          .toList(),
      topSpecies: ((j['topSpecies'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(TopSpeciesStat.fromApi)
          .toList(),
      contributions: MonthlyContribution.fillLastSixMonths(
        ((j['contributions'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(MonthlyContribution.fromApi)
            .toList(),
      ),
    );
  }
}
