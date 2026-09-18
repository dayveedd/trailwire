import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/core/database/models/coordinate.dart';
import 'package:trailwire/core/database/models/trail_route.dart';
import 'package:trailwire/core/database/models/waypoint.dart';
import 'package:trailwire/features/export/services/gpx_service.dart';

void main() {
  group('GpxService XML Generation Tests', () {
    late GpxService gpxService;
    late TrailRoute testRoute;
    late List<Coordinate> testCoordinates;
    late List<Waypoint> testWaypoints;

    setUp(() {
      gpxService = GpxService();

      testRoute = TrailRoute()
        ..routeId = 'route-123'
        ..name = 'Mount Whitney & Trail Crest <East>'
        ..startTime = DateTime.utc(2026, 9, 14, 8, 30, 0)
        ..durationSeconds = 7200
        ..totalDistanceMeters = 14500.0
        ..totalElevationGainMeters = 1800.0
        ..status = 'completed';

      testCoordinates = [
        Coordinate()
          ..coordinateId = 'coord-1'
          ..routeId = 'route-123'
          ..latitude = 36.578581
          ..longitude = -118.291995
          ..altitude = 4421.0
          ..speed = 1.2
          ..timestamp = DateTime.utc(2026, 9, 14, 8, 30, 0),
        Coordinate()
          ..coordinateId = 'coord-2'
          ..routeId = 'route-123'
          ..latitude = 36.578650
          ..longitude = -118.292100
          ..altitude = 4418.5
          ..speed = 1.4
          ..timestamp = DateTime.utc(2026, 9, 14, 8, 31, 0),
      ];

      testWaypoints = [
        Waypoint()
          ..waypointId = 'wp-1'
          ..routeId = 'route-123'
          ..title = 'Summit Hut & Peak'
          ..notes = 'Elevation 14,505 ft & breezy'
          ..category = 'viewpoint'
          ..latitude = 36.578581
          ..longitude = -118.291995
          ..altitude = 4421.0
          ..timestamp = DateTime.utc(2026, 9, 14, 8, 30, 15),
      ];
    });

    test('generateGpxString produces valid GPX 1.1 structure with XML escaping', () {
      final gpx = gpxService.generateGpxString(
        route: testRoute,
        coordinates: testCoordinates,
        waypoints: testWaypoints,
      );

      // Verify header & namespaces
      expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(gpx, contains('<gpx version="1.1"'));
      expect(gpx, contains('xmlns="http://www.topografix.com/GPX/1/1"'));

      // Verify metadata and XML escaping
      expect(gpx, contains('<name>Mount Whitney &amp; Trail Crest &lt;East&gt;</name>'));
      expect(gpx, contains('<time>2026-09-14T08:30:00.000Z</time>'));

      // Verify waypoints
      expect(gpx, contains('<wpt lat="36.5785810" lon="-118.2919950">'));
      expect(gpx, contains('<ele>4421.0</ele>'));
      expect(gpx, contains('<name>Summit Hut &amp; Peak</name>'));
      expect(gpx, contains('<desc>Elevation 14,505 ft &amp; breezy</desc>'));
      expect(gpx, contains('<sym>viewpoint</sym>'));
      expect(gpx, contains('<type>viewpoint</type>'));

      // Verify track and track points
      expect(gpx, contains('<trk>'));
      expect(gpx, contains('<trkseg>'));
      expect(gpx, contains('<trkpt lat="36.5785810" lon="-118.2919950">'));
      expect(gpx, contains('<trkpt lat="36.5786500" lon="-118.2921000">'));
      expect(gpx, contains('<ele>4418.5</ele>'));
      expect(gpx, contains('<speed>1.40</speed>'));
      expect(gpx, contains('</trkseg>'));
      expect(gpx, contains('</trk>'));
      expect(gpx, contains('</gpx>'));
    });

    test('generateGpxString handles empty coordinates and waypoints gracefully', () {
      final gpx = gpxService.generateGpxString(
        route: testRoute,
        coordinates: [],
        waypoints: [],
      );

      expect(gpx, contains('<name>Mount Whitney &amp; Trail Crest &lt;East&gt;</name>'));
      expect(gpx, contains('<trkseg>'));
      expect(gpx, contains('</trkseg>'));
      expect(gpx, isNot(contains('<wpt')));
    });
  });
}
