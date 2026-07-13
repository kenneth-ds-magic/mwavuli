import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mwavuli/core/location/location_service.dart';

void main() {
  test('fuzz stays within the radius', () {
    final svc = LocationService();
    const c = LatLng(43.6489, -79.3817);
    const distance = Distance();
    for (var i = 0; i < 500; i++) {
      final p = svc.fuzz(c, radiusMeters: 500);
      expect(distance(c, p) <= 520, isTrue);
    }
  });

  test('fuzz moves the point', () {
    final svc = LocationService();
    const c = LatLng(43.6489, -79.3817);
    final p = svc.fuzz(c);
    expect(p.latitude != c.latitude || p.longitude != c.longitude, isTrue);
  });
}
