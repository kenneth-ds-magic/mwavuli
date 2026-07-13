/// A candidate returned by the identification service, and the reference
/// species record shown on detail screens.
class SpeciesCandidate {
  const SpeciesCandidate({
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    this.photoTag = 'oak',
  });

  final String commonName;
  final String scientificName;
  final int confidence; // 0–100
  /// Client-only UI hint for TreePhoto gradients — not from the ID model.
  final String photoTag;
}

/// Whether `/v1/identify` returned real Pl@ntNet matches, an intentional
/// demo stub (no API key), or an empty result after a provider failure.
enum IdentifySource { plantnet, stub, unavailable }

class IdentifyResponse {
  const IdentifyResponse({
    required this.candidates,
    required this.source,
  });

  final List<SpeciesCandidate> candidates;
  final IdentifySource source;

  bool get isDemo => source == IdentifySource.stub;
  bool get isUnavailable => source == IdentifySource.unavailable;
}

class Species {
  const Species({
    required this.commonName,
    required this.scientificName,
    required this.family,
    required this.nativeRange,
    required this.about,
    this.photoTag = 'oak',
  });

  final String commonName;
  final String scientificName;
  final String family;
  final String nativeRange;
  final String about;
  final String photoTag;
}

/// Maps a common name to a local TreePhoto gradient tag (UI only).
String speciesPhotoTag(String commonName) {
  final n = commonName.toLowerCase();
  if (n.contains('oak')) return 'oak';
  if (n.contains('maple')) return 'maple';
  if (n.contains('pine') || n.contains('spruce') || n.contains('fir')) {
    return 'pine';
  }
  if (n.contains('birch')) return 'birch';
  if (n.contains('cherry') || n.contains('blossom')) return 'cherry';
  if (n.contains('willow')) return 'willow';
  if (n.contains('jacaranda')) return 'jac';
  return 'oak';
}
