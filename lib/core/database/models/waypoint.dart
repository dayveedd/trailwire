import 'package:isar/isar.dart';

part 'waypoint.g.dart';

@collection
class Waypoint {
  Id id = Isar.autoIncrement;

  /// Globally unique UUID for this waypoint.
  @Index(unique: true, replace: true)
  late String waypointId;

  /// Foreign key referencing TrailRoute.routeId.
  @Index()
  late String routeId;

  late String title;
  String? notes;
  String? category; // e.g. 'water_source', 'campsite', 'hazard', 'viewpoint'

  late double latitude;
  late double longitude;
  double? altitude;

  /// Local device sandbox paths (offline-first media storage).
  String? localPhotoPath;
  String? localAudioPath;

  /// Remote Firebase Cloud Storage URLs (populated after deferred sync).
  String? remotePhotoUrl;
  String? remoteAudioUrl;

  late DateTime timestamp;

  /// Sync flag for deferred synchronization.
  @Index()
  bool isSynced = false;

  late DateTime createdAt;
  late DateTime updatedAt;

  Map<String, dynamic> toFirestore() {
    return {
      'waypointId': waypointId,
      'routeId': routeId,
      'title': title,
      'notes': notes,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'remotePhotoUrl': remotePhotoUrl,
      'remoteAudioUrl': remoteAudioUrl,
      'timestamp': timestamp.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
