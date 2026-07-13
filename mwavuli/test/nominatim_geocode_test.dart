import 'package:flutter_test/flutter_test.dart';
import 'package:mwavuli/core/location/nominatim_geocode.dart';

void main() {
  group('formatAddress', () {
    test('prefers city and state', () {
      expect(
        formatAddress({'city': 'Nairobi', 'state': 'Nairobi County'}),
        'Nairobi, Nairobi County',
      );
    });

    test('falls back to town and country', () {
      expect(
        formatAddress({'town': 'Kisumu', 'country': 'Kenya'}),
        'Kisumu, Kenya',
      );
    });

    test('returns null when no useful fields', () {
      expect(formatAddress({'road': 'Main St'}), isNull);
    });
  });

  group('suggestionFromNominatimResult', () {
    test('uses formatted address with full display as subtitle', () {
      final suggestion = suggestionFromNominatimResult({
        'lat': '-1.286389',
        'lon': '36.817223',
        'display_name': 'Nairobi, Nairobi County, Kenya',
        'address': {'city': 'Nairobi', 'state': 'Nairobi County'},
      });
      expect(suggestion?.label, 'Nairobi, Nairobi County');
      expect(suggestion?.subtitle, 'Nairobi, Nairobi County, Kenya');
      expect(suggestion?.point.latitude, closeTo(-1.286389, 0.0001));
    });

    test('falls back to short display name', () {
      final suggestion = suggestionFromNominatimResult({
        'lat': '-0.1022',
        'lon': '34.7617',
        'display_name': 'Kisumu, Kisumu County, Kenya',
      });
      expect(suggestion?.label, 'Kisumu, Kisumu County');
      expect(suggestion?.point.longitude, closeTo(34.7617, 0.0001));
    });

    test('returns null without coordinates', () {
      expect(
        suggestionFromNominatimResult({
          'display_name': 'Nowhere',
        }),
        isNull,
      );
    });
  });

  group('shortDisplayName', () {
    test('keeps first two comma-separated parts', () {
      expect(
        shortDisplayName('Nairobi, Nairobi County, Kenya'),
        'Nairobi, Nairobi County',
      );
    });
  });
}
