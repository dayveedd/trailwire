import 'package:isar/isar.dart';

part 'coordinate.g.dart';

@collection
class Coordinate {
  Id id = Isar.autoIncrement;

  /// Globally unique UUID for this coordinate.
  @Index(unique: true, replace: true)
  late String coordinateId;

  /// Foreign key referencing TrailRoute.routeId.
  @Index()
  late String routeId;

  late double latitude;
  late double longitude;
  double? altitude;
  double? speed;
  double? accuracy;
  double? heading;

  late DateTime timestamp;

  /// Sync flag for deferred synchronization.
  @Index()
  bool isSynced = false;

  Map<String, dynamic> toFirestore() {
    return {
      'coordinateId': coordinateId,
      'routeId': routeId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'accuracy': accuracy,
      'heading': heading,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
