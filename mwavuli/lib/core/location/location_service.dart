import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'nominatim_geocode.dart';

/// GPS fix used when logging a tree (exact point + optional accuracy).
class DeviceLocation {
  const DeviceLocation(this.point, {this.accuracyM});

  final LatLng point;
  final double? accuracyM;
}

/// Wraps geolocation. Publishing fuzz (±500 m) is applied **on the server**
/// when `isFuzzy` is true — [fuzz] is only for on-device preview circles.
class LocationService {
  LocationService([Random? random]) : _random = random ?? Random();
  final Random _random;

  /// Current device position, or null if unavailable / permission denied.
  Future<LatLng?> current() async {
    final fix = await currentFix();
    return fix?.point;
  }

  /// Current fix including horizontal accuracy (metres), when available.
  Future<DeviceLocation?> currentFix() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return DeviceLocation(
        LatLng(pos.latitude, pos.longitude),
        accuracyM: pos.accuracy.isFinite ? pos.accuracy : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Last cached OS position — useful offline when a fresh fix fails.
  Future<DeviceLocation?> lastKnownFix() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return null;
      return DeviceLocation(
        LatLng(pos.latitude, pos.longitude),
        accuracyM: pos.accuracy.isFinite ? pos.accuracy : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Preview-only: randomise a point within [radiusMeters] (default ~500 m).
  /// Do **not** send this point as the tree's `lat`/`lng` — the API stores the
  /// exact fix and builds `fuzzy_geom` server-side.
  LatLng fuzz(LatLng exact, {double radiusMeters = 500}) {
    final u = _random.nextDouble();
    final v = _random.nextDouble();
    final w = radiusMeters * sqrt(u);
    final t = 2 * pi * v;
    final dxMeters = w * cos(t);
    final dyMeters = w * sin(t);
    const metersPerDegLat = 111320.0;
    final dLat = dyMeters / metersPerDegLat;
    final dLng =
        dxMeters / (metersPerDegLat * cos(exact.latitude * pi / 180.0));
    return LatLng(exact.latitude + dLat, exact.longitude + dLng);
  }

  /// GPS position → human-readable place via OpenStreetMap Nominatim.
  Future<String?> currentLocationLabel(NominatimGeocode geocode) async {
    final point = await current();
    if (point == null) return null;
    return geocode.reverseLabel(point);
  }
}

final locationServiceProvider = Provider((_) => LocationService());
final nominatimGeocodeProvider = Provider((_) => NominatimGeocode());
