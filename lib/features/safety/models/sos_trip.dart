import 'package:cloud_firestore/cloud_firestore.dart';

class SosTrip {
  final String tripId;
  final String userId;
  final String tripName;
  final String? routeIntent;
  final String emergencyContact;
  final DateTime expectedReturnTime;
  final String status; // 'ACTIVE', 'COMPLETED', 'CANCELLED', 'OVERDUE'
  final DateTime createdAt;
  final double? lastKnownLatitude;
  final double? lastKnownLongitude;

  const SosTrip({
    required this.tripId,
    required this.userId,
    required this.tripName,
    this.routeIntent,
    required this.emergencyContact,
    required this.expectedReturnTime,
    this.status = 'ACTIVE',
    required this.createdAt,
    this.lastKnownLatitude,
    this.lastKnownLongitude,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'tripId': tripId,
      'userId': userId,
      'tripName': tripName,
      'routeIntent': routeIntent ?? '',
      'emergencyContact': emergencyContact,
      'expectedReturnTime': Timestamp.fromDate(expectedReturnTime),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastKnownLatitude': lastKnownLatitude,
      'lastKnownLongitude': lastKnownLongitude,
      'expiresAtMillis': expectedReturnTime.millisecondsSinceEpoch,
    };
  }

  factory SosTrip.fromFirestore(Map<String, dynamic> data, String id) {
    return SosTrip(
      tripId: id,
      userId: data['userId'] as String? ?? '',
      tripName: data['tripName'] as String? ?? 'Wilderness Trek',
      routeIntent: data['routeIntent'] as String?,
      emergencyContact: data['emergencyContact'] as String? ?? '',
      expectedReturnTime: data['expectedReturnTime'] is Timestamp
          ? (data['expectedReturnTime'] as Timestamp).toDate()
          : DateTime.tryParse(data['expectedReturnTime']?.toString() ?? '') ?? DateTime.now(),
      status: data['status'] as String? ?? 'ACTIVE',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
      lastKnownLatitude: (data['lastKnownLatitude'] as num?)?.toDouble(),
      lastKnownLongitude: (data['lastKnownLongitude'] as num?)?.toDouble(),
    );
  }

  SosTrip copyWith({
    String? status,
    double? lastKnownLatitude,
    double? lastKnownLongitude,
  }) {
    return SosTrip(
      tripId: tripId,
      userId: userId,
      tripName: tripName,
      routeIntent: routeIntent,
      emergencyContact: emergencyContact,
      expectedReturnTime: expectedReturnTime,
      status: status ?? this.status,
      createdAt: createdAt,
      lastKnownLatitude: lastKnownLatitude ?? this.lastKnownLatitude,
      lastKnownLongitude: lastKnownLongitude ?? this.lastKnownLongitude,
    );
  }
}
