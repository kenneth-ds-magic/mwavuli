import 'package:flutter_test/flutter_test.dart';

import 'package:mwavuli/data/models/explore.dart';

void main() {
  test('ExploreData formats header subtitle preferring GPS label', () {
    const data = ExploreData(
      treeCount: 4812,
      nearbyCount: 42,
      locationLabel: 'Saved City',
      trendingSpecies: [],
    );
    expect(
      data.headerSubtitle(localLocationLabel: 'Toronto, ON'),
      'Toronto, ON · 42 nearby · 4.8k mapped',
    );
    expect(data.headerSubtitle(), 'Saved City · 42 nearby · 4.8k mapped');
    expect(data.mapTeaserLabel(), '42 trees nearby');
  });

  test('ExploreData fromApi parses trending species and activity', () {
    final data = ExploreData.fromApi({
      'treeCount': 12,
      'nearbyCount': 3,
      'locationLabel': 'Nairobi',
      'trendingSpecies': [
        {
          'commonName': 'English Oak',
          'treeCount': 5,
          'tree': {
            'id': 'abc',
            'commonName': 'English Oak',
            'scientificName': 'Quercus robur',
            'health': 'healthy',
            'isFuzzy': true,
            'fuzzyLocation': {'lat': 1, 'lng': 2},
            'photoStatus': 'pending',
          },
        },
      ],
      'recentActivity': [
        {
          'verb': 'logged_tree',
          'actorDisplayName': 'Angela',
          'createdAt': '2026-01-01T12:00:00Z',
        },
      ],
    });
    expect(data.treeCount, 12);
    expect(data.nearbyCount, 3);
    expect(data.trendingSpecies.single.treeCount, 5);
    expect(data.trendingSpecies.single.sampleTree.photoStatus, 'pending');
    expect(data.recentActivity.single.kind.name, 'log');
  });

  test('ExploreFeedQuery equality for provider invalidation', () {
    const a = ExploreFeedQuery(filter: 'oak', search: 'oak');
    const b = ExploreFeedQuery(filter: 'oak', search: 'oak');
    const c = ExploreFeedQuery(filter: 'near');
    expect(a, b);
    expect(a == c, false);
  });
}
