import 'package:flutter_test/flutter_test.dart';
import 'package:mwavuli/data/models/community.dart';

void main() {
  test('CommunityData.fromApi parses bundle', () {
    final data = CommunityData.fromApi({
      'profile': {
        'points': 120,
        'level': 2,
        'levelName': 'Sprout',
        'treeCount': 3,
        'speciesCount': 2,
        'followers': 5,
        'gamification': {
          'progress': 0.4,
          'pointsToNextLevel': 180,
          'nextLevel': 3,
          'streakDays': 2,
        },
      },
      'badges': [
        {
          'code': 'first_sprout',
          'name': 'First Sprout',
          'icon': 'eco',
          'earned': true,
        },
        {
          'code': 'rare_finder',
          'name': 'Rare Finder',
          'icon': 'lock',
          'earned': false,
        },
      ],
      'earnedBadgeCount': 1,
      'totalBadgeCount': 2,
      'leaderboard': {
        'period': 'week',
        'items': [
          {
            'rank': 1,
            'userId': 'u1',
            'username': 'angela',
            'displayName': 'Angela R.',
            'logCount': 12,
            'isMe': false,
          },
        ],
        'hasMore': true,
      },
      'suggestions': [
        {
          'id': 'u2',
          'username': 'lena',
          'displayName': 'Lena K.',
          'logCount': 8,
          'isFollowing': false,
        },
      ],
    });

    expect(data.profile?.levelName, 'Sprout');
    expect(data.earnedBadgeCount, 1);
    expect(data.leaderboard.first.displayName, 'Angela R.');
    expect(data.leaderboardHasMore, isTrue);
    expect(data.activity, isEmpty);
    expect(data.suggestions.first.username, 'lena');
    expect(data.suggestions.first.isFollowing, isFalse);
  });

  test('ActivityItem formats verbs and links trees', () {
    final item = ActivityItem.fromApi({
      'verb': 'commented',
      'actorDisplayName': 'Priya',
      'actorId': 'actor-1',
      'createdAt': DateTime.now().toIso8601String(),
      'metadata': {'body': 'Nice tree!', 'commonName': 'English Oak'},
      'objectType': 'tree',
      'objectId': 'abc-123',
    });
    expect(item.kind, ActivityKind.comment);
    expect(item.quote, 'Nice tree!');
    expect(item.treeId, 'abc-123');
    expect(item.text, contains('English Oak'));
    expect(item.isTappable, isTrue);
  });

  test('ActivityItem links follow events to users', () {
    final item = ActivityItem.fromApi({
      'verb': 'followed',
      'actorDisplayName': 'Alex',
      'createdAt': DateTime.now().toIso8601String(),
      'objectType': 'user',
      'objectId': 'user-uuid',
      'metadata': {'displayName': 'Jordan'},
    });
    expect(item.kind, ActivityKind.follow);
    expect(item.userId, 'user-uuid');
    expect(item.text, contains('Jordan'));
    expect(item.isTappable, isTrue);
  });

  test('ActivityItem badge events are tappable via actor', () {
    final item = ActivityItem.fromApi({
      'verb': 'earned_badge',
      'actorDisplayName': 'Sam',
      'actorId': 'sam-id',
      'createdAt': DateTime.now().toIso8601String(),
      'objectType': 'badge',
      'objectId': 'badge-id',
      'metadata': {'name': 'First Sprout'},
    });
    expect(item.kind, ActivityKind.badge);
    expect(item.actorId, 'sam-id');
    expect(item.isTappable, isTrue);
    expect(item.text, contains('First Sprout'));
  });
}
