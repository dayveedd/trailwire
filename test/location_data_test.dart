import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/core/models/location_data.dart';

void main() {
  group('LocationData Model Tests', () {
    test('fromMap parses valid CoreLocation dictionary payload', () {
      final map = {
        'latitude': 37.7749,
        'longitude': -122.4194,
        'altitude': 120.5,
        'speed': 2.1,
        'heading': 185.0,
        'accuracy': 4.2,
        'timestamp': '2026-09-10T14:30:00.000Z',
        'routeId': 'test-route-abc',
      };

      final location = LocationData.fromMap(map);

      expect(location.latitude, equals(37.7749));
      expect(location.longitude, equals(-122.4194));
      expect(location.altitude, equals(120.5));
      expect(location.speed, equals(2.1));
      expect(location.heading, equals(185.0));
      expect(location.accuracy, equals(4.2));
      expect(location.routeId, equals('test-route-abc'));
      expect(location.timestamp, equals(DateTime.parse('2026-09-10T14:30:00.000Z')));
    });

    test('toCoordinate converts LocationData to Isar Coordinate entity', () {
      final location = LocationData(
        latitude: 45.1234,
        longitude: -121.5678,
        altitude: 2100.0,
        speed: 1.5,
        heading: 90.0,
        accuracy: 3.0,
        timestamp: DateTime.now(),
        routeId: 'route-xyz',
      );

      final coord = location.toCoordinate(routeId: 'route-xyz', coordinateId: 'coord-123');

      expect(coord.coordinateId, equals('coord-123'));
      expect(coord.routeId, equals('route-xyz'));
      expect(coord.latitude, equals(45.1234));
      expect(coord.longitude, equals(-121.5678));
      expect(coord.altitude, equals(2100.0));
      expect(coord.isSynced, isFalse);
    });
  });
}
