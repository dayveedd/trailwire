import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/core/platform/location_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('com.usetrailwire.trailwire/location');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'startTracking':
          return true;
        case 'stopTracking':
          return true;
        case 'isTracking':
          return true;
        case 'getCurrentLocation':
          return <String, dynamic>{
            'routeId': 'test-route-123',
            'latitude': 37.7749,
            'longitude': -122.4194,
            'altitude': 15.0,
            'speed': 1.5,
            'accuracy': 5.0,
            'heading': 90.0,
            'timestamp': '2026-09-10T12:00:00Z',
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('startTracking calls native channel with routeId and distanceFilter', () async {
    final result = await LocationChannel.startTracking(
      routeId: 'test-route-123',
      distanceFilterMeters: 10.0,
    );

    expect(result, isTrue);
    expect(log, hasLength(1));
    expect(log.first.method, equals('startTracking'));
    expect(log.first.arguments, equals({
      'routeId': 'test-route-123',
      'distanceFilter': 10.0,
    }));
  });

  test('stopTracking calls native channel', () async {
    final result = await LocationChannel.stopTracking();

    expect(result, isTrue);
    expect(log, hasLength(1));
    expect(log.first.method, equals('stopTracking'));
  });

  test('isTracking queries native tracking status', () async {
    final result = await LocationChannel.isTracking();

    expect(result, isTrue);
    expect(log, hasLength(1));
    expect(log.first.method, equals('isTracking'));
  });

  test('getCurrentLocation parses dictionary from native side', () async {
    final location = await LocationChannel.getCurrentLocation();

    expect(location, isNotNull);
    expect(location!['routeId'], equals('test-route-123'));
    expect(location['latitude'], equals(37.7749));
    expect(location['longitude'], equals(-122.4194));
  });
}
