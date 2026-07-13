import 'package:flutter_test/flutter_test.dart';
import 'package:mwavuli/data/models/profile.dart';

void main() {
  test('ProfileData.fromApi parses camelCase payload', () {
    final data = ProfileData.fromApi({
      'profile': {
        'id': 'u1',
        'email': 'a@b.com',
        'username': 'jordan',
        'displayName': 'Jordan Ellery',
        'bio': 'Tree lover',
        'avatarUrl': null,
        'points': 120,
        'level': 4,
        'levelName': 'Sapling Scout',
        'locationLabel': 'Toronto, ON',
        'createdAt': '2024-06-01T12:00:00Z',
      },
      'social': {'following': 10, 'followers': 5},
      'stats': {'trees': 3, 'species': 2, 'points': 120},
      'badges': [
        {
          'code': 'first_sprout',
          'name': 'First Sprout',
          'icon': 'eco',
          'awardedAt': '2024-06-02T12:00:00Z',
        },
      ],
      'trees': [
        {
          'id': 't1',
          'commonName': 'English Oak',
          'health': 'healthy',
          'verified': false,
          'visibility': 'public',
          'isFuzzy': true,
        },
      ],
      'topSpecies': [
        {'name': 'Oak', 'count': 2},
      ],
      'contributions': [
        {'month': 'Jul', 'count': 2},
      ],
    });

    expect(data.profile.displayName, 'Jordan Ellery');
    expect(data.profile.initials, 'J');
    expect(data.profile.handle, '@jordan');
    expect(data.following, 10);
    expect(data.treeCount, 3);
    expect(data.badges.first.name, 'First Sprout');
    expect(data.trees.first.commonName, 'English Oak');
    expect(data.topSpecies.first.count, 2);
    expect(data.contributions, hasLength(6));
    expect(data.contributions.where((m) => m.count == 2), hasLength(1));
    expect(data.contributions.where((m) => m.count == 0), hasLength(5));
  });

  test('MonthlyContribution.fillLastSixMonths pads missing months with zero', () {
    final filled = MonthlyContribution.fillLastSixMonths(const [
      MonthlyContribution(month: 'Jul', count: 2),
    ]);
    expect(filled, hasLength(6));
    expect(filled.where((m) => m.count == 0), hasLength(5));
    expect(filled.singleWhere((m) => m.count > 0).count, 2);
    expect(filled.singleWhere((m) => m.count > 0).month, 'Jul');
  });
}
