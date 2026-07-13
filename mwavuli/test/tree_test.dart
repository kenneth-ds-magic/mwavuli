import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mwavuli/data/models/tree.dart';

void main() {
  test('fromApi parses camelCase + fuzzy location, never exact', () {
    final t = Tree.fromApi({
      'id': 'abc',
      'commonName': 'English Oak',
      'scientificName': 'Quercus robur',
      'heightM': 18,
      'health': 'healthy',
      'features': ['Heritage'],
      'confidence': 97,
      'verified': true,
        'contributor': 'Angela',
        'ownerId': 'user-1',
        'likeCount': 3,
        'commentCount': 1,
        'description': 'A fine oak.',
      'visibility': 'public',
      'isFuzzy': true,
      'fuzzyLocation': {'lat': 43.65, 'lng': -79.38},
    });
    expect(t.commonName, 'English Oak');
    expect(t.photoTag, 'oak'); // guessed from name
    expect(t.health, TreeHealth.healthy);
    expect(t.fuzzyLocation!.latitude, closeTo(43.65, 1e-9));
    expect(t.exactLocation, isNull);
    expect(t.verified, true);
  });

  test('toCreateRequest sends exact lat/lng and omits empty fields', () {
    const t = Tree(
      id: 'x',
      commonName: 'Oak',
      scientificName: '',
      photoTag: 'oak',
      heightMeters: 0,
      ageEstimate: '',
      health: TreeHealth.healthy,
      girthMeters: 0,
      confidence: 0,
      verified: false,
      contributor: 'You',
      description: '',
      exactLocation: LatLng(1, 2),
      isFuzzy: true,
      features: ['Heritage'],
    );
    final body = t.toCreateRequest();
    expect(body['lat'], 1);
    expect(body['lng'], 2);
    expect(body['isFuzzy'], true);
    expect(body['features'], ['Heritage']);
    expect(body.containsKey('scientificName'), false);
    expect(body.containsKey('heightM'), false);
    expect(body.containsKey('confidence'), false);
  });
}
