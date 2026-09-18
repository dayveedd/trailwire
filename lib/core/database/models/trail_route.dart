import 'package:isar/isar.dart';

part 'trail_route.g.dart';

@collection
class TrailRoute {
  Id id = Isar.autoIncrement;

  /// Globally unique UUID for offline-first generation and Firestore document key.
  @Index(unique: true, replace: true)
  late String routeId;

  /// Associated Firebase User UID or local anonymous identifier.
  String? userId;

  /// User-defined or auto-generated name for the route.
  late String name;

  /// Start timestamp of route recording.
  late DateTime startTime;

  /// End timestamp of route recording, null if ongoing.
  DateTime? endTime;

  /// Aggregated metrics.
  double totalDistanceMeters = 0.0;
  double totalElevationGainMeters = 0.0;
  double totalElevationLossMeters = 0.0;
  int durationSeconds = 0;

  /// Route status: 'active', 'paused', 'completed', 'cancelled'.
  late String status;

  /// Sync flag for deferred synchronization engine.
  @Index()
  bool isSynced = false;

  /// Timestamp when successfully synchronized to Firebase.
  DateTime? syncedAt;

  late DateTime createdAt;
  late DateTime updatedAt;

  Map<String, dynamic> toFirestore() {
    return {
      'routeId': routeId,
      'userId': userId,
      'name': name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'totalDistanceMeters': totalDistanceMeters,
      'totalElevationGainMeters': totalElevationGainMeters,
      'totalElevationLossMeters': totalElevationLossMeters,
      'durationSeconds': durationSeconds,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
