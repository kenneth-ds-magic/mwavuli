import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fuzz } from '../../src/services/location';

// Haversine (metres) for verifying the offset stays within the radius.
function metres(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const R = 6_371_000;
  const dLat = ((bLat - aLat) * Math.PI) / 180;
  const dLng = ((bLng - aLng) * Math.PI) / 180;
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((aLat * Math.PI) / 180) *
      Math.cos((bLat * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

test('fuzz stays within the radius (1000 samples)', () => {
  const lat = 43.6489, lng = -79.3817;
  for (let i = 0; i < 1000; i++) {
    const p = fuzz(lat, lng, 500);
    const d = metres(lat, lng, p.lat, p.lng);
    assert.ok(d <= 520, `offset ${d.toFixed(1)}m should be <= ~500m`);
  }
});

test('fuzz actually moves the point', () => {
  const p = fuzz(43.6489, -79.3817, 500);
  assert.ok(p.lat !== 43.6489 || p.lng !== -79.3817);
});
