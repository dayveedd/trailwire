import '../database/models/coordinate.dart';
import 'package:uuid/uuid.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? heading;
  final double? accuracy;
  final DateTime timestamp;
  final String? routeId;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.heading,
    this.accuracy,
    required this.timestamp,
    this.routeId,
  });

  factory LocationData.fromMap(Map<dynamic, dynamic> map) {
    DateTime parsedTimestamp;
    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is String) {
      parsedTimestamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else if (rawTimestamp is int) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else {
      parsedTimestamp = DateTime.now();
    }

    return LocationData(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      timestamp: parsedTimestamp,
      routeId: map['routeId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'routeId': routeId,
    };
  }

  /// Convert to an Isar Coordinate entity with an offline UUID
  Coordinate toCoordinate({required String routeId, String? coordinateId}) {
    return Coordinate()
      ..coordinateId = coordinateId ?? const Uuid().v4()
      ..routeId = routeId
      ..latitude = latitude
      ..longitude = longitude
      ..altitude = altitude
      ..speed = speed
      ..heading = heading
      ..accuracy = accuracy
      ..timestamp = timestamp
      ..isSynced = false;
  }
}
