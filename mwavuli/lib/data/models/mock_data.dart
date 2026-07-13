import 'package:latlong2/latlong.dart';

import 'species.dart';
import 'tree.dart';

/// Seed content for the scaffold so every screen renders without a backend.
/// Replace with repository/API data in Phase 3.

const _toronto = LatLng(43.6489, -79.3817);

final List<Tree> seedTrees = [
  Tree(
    id: 'oak',
    commonName: 'English Oak',
    scientificName: 'Quercus robur',
    photoTag: 'oak',
    heightMeters: 18,
    ageEstimate: '~180 y',
    health: TreeHealth.healthy,
    girthMeters: 3.4,
    confidence: 97,
    verified: true,
    contributor: 'Angela R.',
    description:
        'Grand old oak near the river bend, likely 180+ years old. Deeply '
        'fissured bark, classic lobed leaves, and a wide spreading crown that '
        'shades the path. A key habitat tree — home to woodpeckers and insects.',
    features: ['Fruiting', 'Heritage'],
    exactLocation: LatLng(_toronto.latitude + 0.004, _toronto.longitude - 0.006),
    fuzzyLocation: LatLng(_toronto.latitude + 0.006, _toronto.longitude - 0.004),
  ),
  Tree(
    id: 'jac',
    commonName: 'Jacaranda',
    scientificName: 'Jacaranda mimosifolia',
    photoTag: 'jac',
    heightMeters: 9,
    ageEstimate: '~25 y',
    health: TreeHealth.healthy,
    girthMeters: 1.1,
    confidence: 88,
    verified: false,
    contributor: 'Priya N.',
    description:
        'An ornamental jacaranda in full purple bloom — a surprising sight this '
        'far north. Fern-like leaves and trumpet flowers make it unmistakable.',
    features: ['Flowering', 'Rare'],
    exactLocation: LatLng(_toronto.latitude + 0.010, _toronto.longitude + 0.003),
    fuzzyLocation: LatLng(_toronto.latitude + 0.012, _toronto.longitude + 0.005),
  ),
  Tree(
    id: 'maple',
    commonName: 'Sugar Maple',
    scientificName: 'Acer saccharum',
    photoTag: 'maple',
    heightMeters: 21,
    ageEstimate: '~90 y',
    health: TreeHealth.healthy,
    girthMeters: 2.6,
    confidence: 94,
    verified: true,
    contributor: 'Marco T.',
    description:
        'Blazing autumn colour every October. Tapped by the local community '
        'group each spring for syrup — a genuine neighbourhood landmark.',
    features: ['Heritage'],
    isFuzzy: false,
    exactLocation: LatLng(_toronto.latitude - 0.002, _toronto.longitude + 0.008),
  ),
  Tree(
    id: 'pine',
    commonName: 'Eastern White Pine',
    scientificName: 'Pinus strobus',
    photoTag: 'pine',
    heightMeters: 27,
    ageEstimate: '~120 y',
    health: TreeHealth.healthy,
    girthMeters: 2.9,
    confidence: 92,
    verified: true,
    contributor: 'Dev P.',
    description:
        'A towering native white pine — soft needles in bundles of five and a '
        'straight, commanding trunk. A favourite roost for local raptors.',
    features: ['Native'],
    exactLocation: LatLng(_toronto.latitude - 0.006, _toronto.longitude - 0.002),
    fuzzyLocation: LatLng(_toronto.latitude - 0.004, _toronto.longitude - 0.004),
  ),
  Tree(
    id: 'birch',
    commonName: 'Silver Birch',
    scientificName: 'Betula pendula',
    photoTag: 'birch',
    heightMeters: 12,
    ageEstimate: '~40 y',
    health: TreeHealth.healthy,
    girthMeters: 0.9,
    confidence: 90,
    verified: true,
    contributor: 'You',
    description:
        'Elegant silver birch with peeling papery bark and delicate drooping '
        'branches. One of your own logs, now confirmed by two other members.',
    features: ['Native'],
    exactLocation: _toronto,
    fuzzyLocation: LatLng(_toronto.latitude + 0.002, _toronto.longitude + 0.001),
  ),
  Tree(
    id: 'cherry',
    commonName: 'Ornamental Cherry',
    scientificName: 'Prunus serrulata',
    photoTag: 'cherry',
    heightMeters: 7,
    ageEstimate: '~18 y',
    health: TreeHealth.healthy,
    girthMeters: 0.7,
    confidence: 0,
    verified: false,
    contributor: 'You',
    description:
        'A cloud of pink blossom in early May. Captured offline and waiting in '
        'your sync queue.',
    features: ['Flowering'],
    synced: false,
    exactLocation: LatLng(_toronto.latitude + 0.001, _toronto.longitude - 0.001),
  ),
];

final Map<String, Species> speciesInfo = {
  'oak': const Species(
    commonName: 'English Oak',
    scientificName: 'Quercus robur',
    family: 'Fagaceae',
    nativeRange: 'Europe, W. Asia',
    about:
        'A long-lived deciduous oak supporting more wildlife than almost any '
        'other native tree. Lobed leaves, acorns on long stalks.',
  ),
};

const List<String> trendingSpecies = [
  'English Oak',
  'Cherry Blossom',
  'Eastern White Pine',
  'Jacaranda',
  'Sugar Maple',
];
