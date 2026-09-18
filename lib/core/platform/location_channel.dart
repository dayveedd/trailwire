import 'dart:async';
import 'package:flutter/services.dart';

class LocationChannel {
  static const MethodChannel _methodChannel =
      MethodChannel('com.usetrailwire.trailwire/location');
  static const EventChannel _eventChannel =
      EventChannel('com.usetrailwire.trailwire/location_stream');

  static Stream<Map<String, dynamic>>? _locationStream;

  /// Start background GPS tracking for a given route.
  /// Native side configures CLLocationManager with .fitness activity type and distanceFilter.
  static Future<bool> startTracking({
    required String routeId,
    double distanceFilterMeters = 5.0,
  }) async {
    try {
      final bool? result = await _methodChannel.invokeMethod<bool>(
        'startTracking',
        {
          'routeId': routeId,
          'distanceFilter': distanceFilterMeters,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('Failed to start native tracking: ${e.message}');
      return false;
    }
  }

  /// Stop background GPS tracking.
  static Future<bool> stopTracking() async {
    try {
      final bool? result = await _methodChannel.invokeMethod<bool>('stopTracking');
      return result ?? false;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('Failed to stop native tracking: ${e.message}');
      return false;
    }
  }

  /// Query if native location manager is currently tracking.
  static Future<bool> isTracking() async {
    try {
      final bool? result = await _methodChannel.invokeMethod<bool>('isTracking');
      return result ?? false;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('Failed to query isTracking: ${e.message}');
      return false;
    }
  }

  /// Fetch a single one-shot location reading.
  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getCurrentLocation');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('Failed to get current location: ${e.message}');
      return null;
    }
  }

  /// Stream of location updates emitted from native CoreLocation.
  static Stream<Map<String, dynamic>> get locationStream {
    _locationStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _locationStream!;
  }
}
