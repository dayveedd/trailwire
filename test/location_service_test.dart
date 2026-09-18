import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/features/tracking/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel('com.trailwire/location');
  final List<MethodCall> calls = <MethodCall>[];
  String mockTrackingState = 'stopped';

  setUp(() {
    calls.clear();
    mockTrackingState = 'stopped';

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'startTracking':
          mockTrackingState = 'tracking';
          return true;
        case 'pauseTracking':
          mockTrackingState = 'paused';
          return true;
        case 'stopTracking':
          mockTrackingState = 'stopped';
          return true;
        case 'isTracking':
          return mockTrackingState == 'tracking';
        case 'getTrackingState':
          return mockTrackingState;
        case 'getCurrentLocation':
          return <String, dynamic>{
            'latitude': 37.7749,
            'longitude': -122.4194,
            'altitude': 100.0,
            'speed': 1.0,
            'heading': 0.0,
            'accuracy': 5.0,
            'timestamp': '2026-09-10T12:00:00.000Z',
            'routeId': 'test-route',
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('LocationService startTracking calls native method with parameters', () async {
    final service = LocationService();
    final result = await service.startTracking(
      routeId: 'route-test-1',
      distanceFilterMeters: 5.0,
    );

    expect(result, isTrue);
    expect(calls.last.method, equals('startTracking'));
    expect(calls.last.arguments, equals({
      'routeId': 'route-test-1',
      'distanceFilter': 5.0,
    }));
  });

  test('LocationService pauseTracking calls native pauseTracking', () async {
    final service = LocationService();
    await service.startTracking(routeId: 'route-test-1');
    final paused = await service.pauseTracking();

    expect(paused, isTrue);
    expect(calls.last.method, equals('pauseTracking'));
    expect(await service.getTrackingState(), equals('paused'));
    expect(await service.isTracking(), isFalse);
  });

  test('LocationService stopTracking calls native stopTracking', () async {
    final service = LocationService();
    final stopped = await service.stopTracking();

    expect(stopped, isTrue);
    expect(calls.last.method, equals('stopTracking'));
    expect(await service.getTrackingState(), equals('stopped'));
  });

  test('LocationService getCurrentLocation parses LocationData correctly', () async {
    final service = LocationService();
    final loc = await service.getCurrentLocation();

    expect(loc, isNotNull);
    expect(loc!.latitude, equals(37.7749));
    expect(loc.longitude, equals(-122.4194));
    expect(loc.altitude, equals(100.0));
  });
}
