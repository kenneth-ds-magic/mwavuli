import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'tree.dart';

/// An achievement badge from GET /v1/community.
class AchievementBadge {
  const AchievementBadge({
    required this.code,
    required this.name,
    required this.icon,
    required this.earned,
    this.description,
    this.awardedAt,
  });

  final String code;
  final String name;
  final String? description;
  final String? icon;
  final bool earned;
  final DateTime? awardedAt;

  IconData get iconData => badgeIcon(icon);

  factory AchievementBadge.fromApi(Map<String, dynamic> j) => AchievementBadge(
        code: j['code'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        icon: j['icon'] as String?,
        earned: j['earned'] as bool? ?? false,
        awardedAt: j['awardedAt'] == null
            ? null
            : DateTime.tryParse(j['awardedAt'] as String),
      );
}

IconData badgeIcon(String? icon) => switch (icon) {
      'eco' => Icons.eco_rounded,
      'explore' => Icons.explore_rounded,
      'star' => Icons.star_rounded,
      'verified' => Icons.verified_rounded,
      'lock' => Icons.lock_rounded,
      _ => Icons.military_tech_outlined,
    };

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.username,
    required this.logCount,
    this.avatarUrl,
    this.isMe = false,
  });

  final int rank;
  final String userId;
  final String displayName;
  final String username;
  final int logCount;
  final String? avatarUrl;
  final bool isMe;

  String get role => '@$username';

  factory LeaderboardEntry.fromApi(Map<String, dynamic> j) => LeaderboardEntry(
        rank: (j['rank'] as num).toInt(),
        userId: j['userId'] as String,
        displayName: j['displayName'] as String? ?? 'User',
        username: j['username'] as String? ?? '',
        logCount: (j['logCount'] as num?)?.toInt() ?? 0,
        avatarUrl: j['avatarUrl'] as String?,
        isMe: j['isMe'] as bool? ?? false,
      );
}

enum ActivityKind { badge, verify, comment, follow, log, other }

class ActivityItem {
  const ActivityItem({
    required this.kind,
    required this.text,
    required this.timeAgo,
    this.quote,
    this.id,
    this.objectId,
    this.objectType,
    this.actorId,
    this.createdAt,
  });

  final ActivityKind kind;
  final String text;
  final String timeAgo;
  final String? quote;
  final String? id;
  final String? objectId;
  final String? objectType;
  final String? actorId;
  final DateTime? createdAt;

  /// Tree-linked activity (log, comment, verify) — safe to open tree detail.
  String? get treeId =>
      objectType == 'tree' && objectId != null && objectId!.isNotEmpty
          ? objectId
          : null;

  /// Follow activity — object is the followed user.
  String? get userId =>
      objectType == 'user' && objectId != null && objectId!.isNotEmpty
          ? objectId
          : null;

  bool get isTappable =>
      treeId != null || userId != null || (actorId != null && actorId!.isNotEmpty);

  factory ActivityItem.fromApi(Map<String, dynamic> j) {
    final verb = j['verb'] as String? ?? '';
    final actor = j['actorDisplayName'] as String? ?? 'Someone';
    final meta = (j['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
    final created = DateTime.tryParse(j['createdAt'] as String? ?? '');
    final treeName = (meta['commonName'] as String?)?.trim();
    final otherName = (meta['displayName'] as String?)?.trim();
    final badgeName = (meta['name'] as String?)?.trim();

    final kind = switch (verb) {
      'earned_badge' => ActivityKind.badge,
      'verified_id' => ActivityKind.verify,
      'commented' => ActivityKind.comment,
      'followed' => ActivityKind.follow,
      'logged_tree' => ActivityKind.log,
      _ => ActivityKind.other,
    };

    String text;
    String? quote;
    switch (verb) {
      case 'earned_badge':
        text = '$actor earned the ${badgeName ?? 'badge'} badge.';
        break;
      case 'verified_id':
        text = treeName == null || treeName.isEmpty
            ? '$actor verified a community tree ID.'
            : '$actor verified $treeName.';
        break;
      case 'commented':
        text = treeName == null || treeName.isEmpty
            ? '$actor commented on a tree.'
            : '$actor commented on $treeName.';
        quote = meta['body'] as String? ?? meta['quote'] as String?;
        break;
      case 'followed':
        text = otherName == null || otherName.isEmpty
            ? '$actor followed a mapper.'
            : '$actor followed $otherName.';
        break;
      case 'logged_tree':
        text = treeName == null || treeName.isEmpty
            ? '$actor logged a new tree.'
            : '$actor logged $treeName.';
        break;
      default:
        text = '$actor was active in the community.';
    }

    return ActivityItem(
      kind: kind,
      text: text,
      quote: quote,
      timeAgo: created == null ? '' : _timeAgo(created),
      id: j['id'] as String?,
      objectId: j['objectId'] as String?,
      objectType: j['objectType'] as String?,
      actorId: j['actorId'] as String?,
      createdAt: created,
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return DateFormat.MMMd().format(dt);
  }
}

class SuggestedUser {
  const SuggestedUser({
    required this.id,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.bio,
    this.logCount,
    this.isFollowing = false,
  });

  final String id;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final int? logCount;
  final bool isFollowing;

  String get meta {
    final parts = <String>[];
    if (bio != null && bio!.trim().isNotEmpty) parts.add(bio!.trim());
    if (logCount != null && logCount! > 0) {
      parts.add('${logCount!} logs this month');
    }
    return parts.isEmpty ? '@$username' : parts.join(' · ');
  }

  factory SuggestedUser.fromApi(Map<String, dynamic> j) => SuggestedUser(
        id: j['id'] as String,
        displayName: j['displayName'] as String? ?? 'User',
        username: j['username'] as String? ?? '',
        avatarUrl: j['avatarUrl'] as String?,
        bio: j['bio'] as String?,
        logCount: (j['logCount'] as num?)?.toInt(),
        isFollowing: j['isFollowing'] as bool? ?? false,
      );
}

class CommunityGamification {
  const CommunityGamification({
    required this.progress,
    required this.pointsToNextLevel,
    required this.nextLevel,
    required this.streakDays,
  });

  final double progress;
  final int pointsToNextLevel;
  final int nextLevel;
  final int streakDays;

  factory CommunityGamification.fromApi(Map<String, dynamic> j) =>
      CommunityGamification(
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        pointsToNextLevel: (j['pointsToNextLevel'] as num?)?.toInt() ?? 0,
        nextLevel: (j['nextLevel'] as num?)?.toInt() ?? 2,
        streakDays: (j['streakDays'] as num?)?.toInt() ?? 0,
      );
}

class CommunityProfile {
  const CommunityProfile({
    required this.points,
    required this.level,
    required this.levelName,
    required this.treeCount,
    required this.speciesCount,
    required this.followers,
    required this.gamification,
  });

  final int points;
  final int level;
  final String levelName;
  final int treeCount;
  final int speciesCount;
  final int followers;
  final CommunityGamification gamification;

  factory CommunityProfile.fromApi(Map<String, dynamic> j) => CommunityProfile(
        points: (j['points'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? 1,
        levelName: j['levelName'] as String? ?? 'Seedling',
        treeCount: (j['treeCount'] as num?)?.toInt() ?? 0,
        speciesCount: (j['speciesCount'] as num?)?.toInt() ?? 0,
        followers: (j['followers'] as num?)?.toInt() ?? 0,
        gamification: CommunityGamification.fromApi(
          (j['gamification'] as Map).cast<String, dynamic>(),
        ),
      );
}

class CommunityData {
  const CommunityData({
    this.profile,
    required this.badges,
    required this.earnedBadgeCount,
    required this.totalBadgeCount,
    required this.leaderboard,
    required this.leaderboardPeriod,
    this.leaderboardHasMore = false,
    this.activity = const [],
    required this.suggestions,
  });

  final CommunityProfile? profile;
  final List<AchievementBadge> badges;
  final int earnedBadgeCount;
  final int totalBadgeCount;
  final List<LeaderboardEntry> leaderboard;
  final String leaderboardPeriod;
  final bool leaderboardHasMore;
  final List<ActivityItem> activity;
  final List<SuggestedUser> suggestions;

  factory CommunityData.fromApi(Map<String, dynamic> j) {
    final lb = (j['leaderboard'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CommunityData(
      profile: j['profile'] == null
          ? null
          : CommunityProfile.fromApi(
              (j['profile'] as Map).cast<String, dynamic>()),
      badges: ((j['badges'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AchievementBadge.fromApi)
          .toList(),
      earnedBadgeCount: (j['earnedBadgeCount'] as num?)?.toInt() ?? 0,
      totalBadgeCount: (j['totalBadgeCount'] as num?)?.toInt() ?? 0,
      leaderboard: ((lb['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(LeaderboardEntry.fromApi)
          .toList(),
      leaderboardPeriod: lb['period'] as String? ?? 'week',
      leaderboardHasMore: lb['hasMore'] as bool? ?? false,
      activity: ((j['activity'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(ActivityItem.fromApi)
          .toList(),
      suggestions: ((j['suggestions'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(SuggestedUser.fromApi)
          .toList(),
    );
  }
}

/// Public mapper profile from GET /v1/users/:id.
class PublicUserProfile {
  const PublicUserProfile({
    required this.id,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.bio,
    this.logCount = 0,
    this.followers = 0,
    this.following = 0,
    this.points = 0,
    this.level = 1,
    this.levelName = 'Seedling',
    this.isFollowing = false,
    this.isMe = false,
    this.trees = const [],
  });

  final String id;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final int logCount;
  final int followers;
  final int following;
  final int points;
  final int level;
  final String levelName;
  final bool isFollowing;
  final bool isMe;
  final List<Tree> trees;

  String get handle => '@$username';

  factory PublicUserProfile.fromApi(Map<String, dynamic> j) => PublicUserProfile(
        id: j['id'] as String,
        displayName: j['displayName'] as String? ?? 'User',
        username: j['username'] as String? ?? '',
        avatarUrl: j['avatarUrl'] as String?,
        bio: j['bio'] as String?,
        logCount: (j['logCount'] as num?)?.toInt() ?? 0,
        followers: (j['followers'] as num?)?.toInt() ?? 0,
        following: (j['following'] as num?)?.toInt() ?? 0,
        points: (j['points'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? 1,
        levelName: j['levelName'] as String? ?? 'Seedling',
        isFollowing: j['isFollowing'] as bool? ?? false,
        isMe: j['isMe'] as bool? ?? false,
        trees: ((j['trees'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Tree.fromApi)
            .toList(),
      );
}
