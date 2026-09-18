import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/features/sync/models/sync_result.dart';

void main() {
  group('SyncResult Tests', () {
    test('SyncResult.empty initializes success and zero counts', () {
      final result = SyncResult.empty();
      expect(result.success, isTrue);
      expect(result.syncedRoutesCount, equals(0));
      expect(result.syncedWaypointsCount, equals(0));
      expect(result.syncedCoordinatesCount, equals(0));
      expect(result.uploadedMediaCount, equals(0));
      expect(result.errorMessage, isNull);
    });

    test('SyncResult.failure sets error message and success = false', () {
      final result = SyncResult.failure('Network timeout');
      expect(result.success, isFalse);
      expect(result.errorMessage, equals('Network timeout'));
    });

    test('SyncResult with counts initializes properly', () {
      final now = DateTime.now();
      final result = SyncResult(
        success: true,
        syncedRoutesCount: 3,
        syncedWaypointsCount: 12,
        syncedCoordinatesCount: 450,
        uploadedMediaCount: 5,
        timestamp: now,
      );

      expect(result.success, isTrue);
      expect(result.syncedRoutesCount, equals(3));
      expect(result.syncedWaypointsCount, equals(12));
      expect(result.syncedCoordinatesCount, equals(450));
      expect(result.uploadedMediaCount, equals(5));
      expect(result.timestamp, equals(now));
    });
  });
}
