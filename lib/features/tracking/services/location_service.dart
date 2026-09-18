import 'dart:async';
import 'package:flutter/services.dart';
import '../../../core/models/location_data.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const MethodChannel _methodChannel =
      MethodChannel('com.trailwire/location');
  static const EventChannel _eventChannel =
      EventChannel('com.trailwire/location_stream');

  Stream<LocationData>? _locationStream;

  /// Stream of location payloads emitted from native CoreLocation.
  Stream<LocationData> get locationStream {
    _locationStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) {
          if (event is Map) {
            return LocationData.fromMap(event);
          }
          throw PlatformException(
            code: 'INVALID_DATA',
            message: 'Received invalid location data type: ${event.runtimeType}',
          );
        });
    return _locationStream!;
  }

  /// Start background GPS tracking for a given route.
  Future<bool> startTracking({
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
      print('[LocationService] Failed to start native tracking: ${e.message}');
      return false;
    }
  }

  /// Pause background GPS tracking without tearing down route session.
  Future<bool> pauseTracking() async {
    try {
      final bool? result = await _methodChannel.invokeMethod<bool>('pauseTracking');
      return result ?? false;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[LocationService] Failed to pause tracking: ${e.message}');
      return false;
    }
  }

  /// Stop background GPS tracking and release location hardware updates.
  Future<bool> stopTracking() async {
    try {
      final bool? result = await _methodChannel.invokeMethod<bool>('stopTracking');
      return result ?? false;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[LocationService] Failed to stop tracking: ${e.message}');
      return false;
    }
  }

  /// Check whether native tracking is actively logging points.
  Future<bool> isTracking() async {
    try {
      final bool? result = await _methodChannel.invokeMethod<bool>('isTracking');
      return result ?? false;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[LocationService] Failed to query isTracking: ${e.message}');
      return false;
    }
  }

  /// Query native tracking state ('stopped', 'tracking', 'paused').
  Future<String> getTrackingState() async {
    try {
      final String? result =
          await _methodChannel.invokeMethod<String>('getTrackingState');
      return result ?? 'stopped';
    } on PlatformException catch (_) {
      return 'stopped';
    }
  }

  /// Fetch a single one-shot location reading from native CoreLocation.
  Future<LocationData?> getCurrentLocation() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getCurrentLocation');
      if (result != null) {
        return LocationData.fromMap(result);
      }
      return null;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[LocationService] Failed to fetch current location: ${e.message}');
      return null;
    }
  }

  /// Query location authorization status from native CoreLocation.
  /// Returns 'authorizedAlways', 'authorizedWhenInUse', 'denied', 'restricted', 'notDetermined', or 'unknown'.
  Future<String> getAuthorizationStatus() async {
    try {
      final String? result =
          await _methodChannel.invokeMethod<String>('getAuthorizationStatus');
      return result ?? 'notDetermined';
    } on PlatformException catch (_) {
      return 'unknown';
    }
  }

  /// Open iOS/Android device app settings for Trailwire.
  Future<bool> openAppSettings() async {
    try {
      final bool? result =
          await _methodChannel.invokeMethod<bool>('openAppSettings');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
