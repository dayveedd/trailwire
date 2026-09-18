enum SyncStatus {
  idle,
  checkingConnectivity,
  syncing,
  completed,
  error,
}

class SyncResult {
  final bool success;
  final int syncedRoutesCount;
  final int syncedWaypointsCount;
  final int syncedCoordinatesCount;
  final int uploadedMediaCount;
  final String? errorMessage;
  final String? warningMessage;
  final DateTime timestamp;

  const SyncResult({
    required this.success,
    this.syncedRoutesCount = 0,
    this.syncedWaypointsCount = 0,
    this.syncedCoordinatesCount = 0,
    this.uploadedMediaCount = 0,
    this.errorMessage,
    this.warningMessage,
    required this.timestamp,
  });

  factory SyncResult.empty() {
    return SyncResult(
      success: true,
      timestamp: DateTime.now(),
    );
  }

  factory SyncResult.failure(String message) {
    return SyncResult(
      success: false,
      errorMessage: message,
      timestamp: DateTime.now(),
    );
  }
}
