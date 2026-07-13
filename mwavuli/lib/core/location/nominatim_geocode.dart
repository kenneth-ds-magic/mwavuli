import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// A place returned from OpenStreetMap Nominatim search.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.label,
    required this.point,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final LatLng point;
}

/// Reverse geocoding via OpenStreetMap Nominatim (not OSRM — that is for routing).
class NominatimGeocode {
  NominatimGeocode({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              headers: {
                'User-Agent': 'mwavuli/0.1.0 (https://github.com/mwavuli)',
              },
            ));

  final Dio _dio;

  Future<String?> reverseLabel(LatLng point) async {
    final r = await _dio.get<Map<String, dynamic>>(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'lat': point.latitude,
        'lon': point.longitude,
        'format': 'json',
        'zoom': 10,
        'addressdetails': 1,
      },
    );
    final data = r.data;
    if (data == null) return null;
    final address = data['address'];
    if (address is Map) {
      final label = formatAddress(address.cast<String, dynamic>());
      if (label != null) return label;
    }
    final display = data['display_name'];
    return display is String ? display : null;
  }

  Future<List<PlaceSuggestion>> searchPlaces(String query, {int limit = 6}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final r = await _dio.get<List<dynamic>>(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'q': q,
        'format': 'json',
        'addressdetails': 1,
        'limit': limit,
      },
    );

    final seen = <String>{};
    final results = <PlaceSuggestion>[];
    for (final item in r.data ?? const []) {
      if (item is! Map) continue;
      final suggestion = suggestionFromNominatimResult(item.cast<String, dynamic>());
      if (suggestion == null || seen.contains(suggestion.label)) continue;
      seen.add(suggestion.label);
      results.add(suggestion);
    }
    return results;
  }
}

/// Build a short city/region label from a Nominatim address object.
String? formatAddress(Map<String, dynamic> address) {
  final place = address['city'] ??
      address['town'] ??
      address['village'] ??
      address['municipality'] ??
      address['county'];
  final region = address['state'] ?? address['region'];
  final country = address['country'];

  if (place != null && region != null) return '$place, $region';
  if (place != null && country != null) return '$place, $country';
  if (place != null) return place.toString();
  if (region != null && country != null) return '$region, $country';
  return null;
}

PlaceSuggestion? suggestionFromNominatimResult(Map<String, dynamic> item) {
  final address = item['address'];
  String label;
  if (address is Map) {
    label = formatAddress(address.cast<String, dynamic>()) ??
        shortDisplayName(item['display_name']);
  } else {
    label = shortDisplayName(item['display_name']);
  }
  if (label.isEmpty) return null;

  final lat = double.tryParse('${item['lat']}');
  final lon = double.tryParse('${item['lon']}');
  if (lat == null || lon == null) return null;

  final display = item['display_name'];
  final subtitle =
      display is String && display != label ? display : null;
  return PlaceSuggestion(label: label, subtitle: subtitle, point: LatLng(lat, lon));
}

String shortDisplayName(Object? displayName) {
  if (displayName is! String || displayName.trim().isEmpty) return '';
  final parts = displayName.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
  return parts.take(2).join(', ');
}
