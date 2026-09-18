import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils Tests', () {
    test('calculateDistanceMeters returns 0 for identical points', () {
      final distance = GeoUtils.calculateDistanceMeters(37.7749, -122.4194, 37.7749, -122.4194);
      expect(distance, equals(0.0));
    });

    test('calculateDistanceMeters accurately computes distance between known coordinates', () {
      // Distance between SF (37.7749, -122.4194) and LA (34.0522, -118.2437) is approx 559 km (559,000m)
      final distance = GeoUtils.calculateDistanceMeters(37.7749, -122.4194, 34.0522, -118.2437);
      expect(distance, closeTo(559100.0, 5000.0));
    });

    test('calculateDistanceMeters calculates short trail walk accurately', () {
      // Approx 111 meters for 0.001 deg latitude difference at equator
      final distance = GeoUtils.calculateDistanceMeters(0.0, 0.0, 0.001, 0.0);
      expect(distance, closeTo(111.2, 0.5));
    });

    test('calculateElevationDelta filters out noise below threshold', () {
      final delta = GeoUtils.calculateElevationDelta(100.0, 100.8, noiseThresholdMeters: 1.5);
      expect(delta, equals(0.0));
    });

    test('calculateElevationDelta records climb and descent above threshold', () {
      final gain = GeoUtils.calculateElevationDelta(100.0, 105.0, noiseThresholdMeters: 1.5);
      expect(gain, equals(5.0));

      final loss = GeoUtils.calculateElevationDelta(105.0, 95.0, noiseThresholdMeters: 1.5);
      expect(loss, equals(-10.0));
    });
  });
}
