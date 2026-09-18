import 'dart:math' as math;

class GeoUtils {
  static const double earthRadiusMeters = 6371000.0;

  /// Calculate distance between two lat/lng coordinates in meters using the Haversine formula.
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Calculate elevation delta, ignoring minor noise below a threshold.
  static double calculateElevationDelta(
    double? prevAlt,
    double? currAlt, {
    double noiseThresholdMeters = 1.5,
  }) {
    if (prevAlt == null || currAlt == null) return 0.0;
    final delta = currAlt - prevAlt;
    if (delta.abs() < noiseThresholdMeters) return 0.0;
    return delta;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
