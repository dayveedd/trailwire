import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/core/database/models/trail_route.dart';
import 'package:trailwire/core/database/models/coordinate.dart';
import 'package:trailwire/core/database/models/waypoint.dart';
import 'package:uuid/uuid.dart';

void main() {
  const uuid = Uuid();

  group('TrailRoute Model Tests', () {
    test('initializes with default values and isSynced = false', () {
      final routeId = uuid.v4();
      final now = DateTime.now();

      final route = TrailRoute()
        ..routeId = routeId
        ..name = 'Mount Whitney Summit Trail'
        ..startTime = now
        ..status = 'active'
        ..createdAt = now
        ..updatedAt = now;

      expect(route.routeId, equals(routeId));
      expect(route.name, equals('Mount Whitney Summit Trail'));
      expect(route.isSynced, isFalse);
      expect(route.totalDistanceMeters, equals(0.0));
      expect(route.durationSeconds, equals(0));
      expect(route.status, equals('active'));

      final firestoreData = route.toFirestore();
      expect(firestoreData['routeId'], equals(routeId));
      expect(firestoreData['name'], equals('Mount Whitney Summit Trail'));
      expect(firestoreData['status'], equals('active'));
    });
  });

  group('Coordinate Model Tests', () {
    test('initializes telemetry coordinate linked to routeId', () {
      final routeId = uuid.v4();
      final coordId = uuid.v4();
      final now = DateTime.now();

      final coord = Coordinate()
        ..coordinateId = coordId
        ..routeId = routeId
        ..latitude = 36.5785
        ..longitude = -118.2923
        ..altitude = 4421.0
        ..speed = 1.2
        ..accuracy = 4.5
        ..heading = 180.0
        ..timestamp = now;

      expect(coord.coordinateId, equals(coordId));
      expect(coord.routeId, equals(routeId));
      expect(coord.latitude, closeTo(36.5785, 0.0001));
      expect(coord.longitude, closeTo(-118.2923, 0.0001));
      expect(coord.altitude, equals(4421.0));
      expect(coord.isSynced, isFalse);

      final firestoreData = coord.toFirestore();
      expect(firestoreData['routeId'], equals(routeId));
      expect(firestoreData['coordinateId'], equals(coordId));
      expect(firestoreData['latitude'], equals(36.5785));
    });
  });

  group('Waypoint Model Tests', () {
    test('initializes rich waypoint with local media sandbox paths', () {
      final routeId = uuid.v4();
      final waypointId = uuid.v4();
      final now = DateTime.now();

      final waypoint = Waypoint()
        ..waypointId = waypointId
        ..routeId = routeId
        ..title = 'Crest Trail Water Spring'
        ..notes = 'Fresh spring water running strong'
        ..latitude = 36.5800
        ..longitude = -118.2900
        ..altitude = 4200.0
        ..localPhotoPath = '/documents/media/photo_123.jpg'
        ..timestamp = now
        ..createdAt = now
        ..updatedAt = now;

      expect(waypoint.waypointId, equals(waypointId));
      expect(waypoint.routeId, equals(routeId));
      expect(waypoint.localPhotoPath, equals('/documents/media/photo_123.jpg'));
      expect(waypoint.remotePhotoUrl, isNull);
      expect(waypoint.isSynced, isFalse);

      final firestoreData = waypoint.toFirestore();
      expect(firestoreData['title'], equals('Crest Trail Water Spring'));
      expect(firestoreData['notes'], equals('Fresh spring water running strong'));
    });
  });
}
