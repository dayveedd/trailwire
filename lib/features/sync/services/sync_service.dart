import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/database/isar_service.dart';
import '../../../core/database/models/coordinate.dart';
import '../../../core/database/models/trail_route.dart';
import '../../../core/database/models/waypoint.dart';
import '../../auth/services/auth_service.dart';
import '../models/sync_result.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  final IsarService _isarService;
  final AuthService _authService;
  final FirebaseFirestore? _customFirestore;
  final FirebaseStorage? _customStorage;
  final Connectivity _connectivity;

  SyncService._internal({
    IsarService? isarService,
    AuthService? authService,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    Connectivity? connectivity,
  })  : _isarService = isarService ?? IsarService(),
        _authService = authService ?? AuthService(),
        _customFirestore = firestore,
        _customStorage = storage,
        _connectivity = connectivity ?? Connectivity();

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FirebaseStorage get _storage => _customStorage ?? FirebaseStorage.instance;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _statusController.stream;

  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;

  /// Start background connectivity listener
  void initialize() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);

    // Initial check on boot
    _checkAndTriggerSync();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isConnected =
        results.any((result) => result != ConnectivityResult.none);
    if (isConnected) {
      _checkAndTriggerSync();
    }
  }

  Future<void> _checkAndTriggerSync() async {
    if (_isSyncing) return;
    await syncPendingData();
  }

  /// Manually or automatically trigger deferred cloud synchronization
  Future<SyncResult> syncPendingData() async {
    if (_isSyncing) {
      return SyncResult.failure('A sync operation is already in progress.');
    }

    // 1. Verify Network Connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    final isOnline = connectivityResults.any(
      (result) => result != ConnectivityResult.none,
    );

    if (!isOnline) {
      _setStatus(SyncStatus.idle);
      return SyncResult.failure('Offline: No network connection available.');
    }

    // 2. Verify User Authentication (Anonymous or Permanent)
    var userId = _authService.currentUserId;
    if (userId == null) {
      final guestUser = await _authService.initializeGuestAuth();
      userId = guestUser?.uid;
    }

    if (userId == null) {
      _setStatus(SyncStatus.idle);
      return SyncResult.failure('Authentication required for cloud sync.');
    }

    _isSyncing = true;
    _setStatus(SyncStatus.syncing);

    try {
      final isar = await _isarService.db;

      // 3. Query Unsynced Records from Isar
      final unsyncedRoutes = await _isarService.getUnsyncedRoutes();
      final unsyncedWaypoints = await _isarService.getUnsyncedWaypoints();
      final unsyncedCoordinates = await _isarService.getUnsyncedCoordinates(limit: 500);

      if (unsyncedRoutes.isEmpty &&
          unsyncedWaypoints.isEmpty &&
          unsyncedCoordinates.isEmpty) {
        _isSyncing = false;
        _setStatus(SyncStatus.completed);
        return SyncResult.empty();
      }

      int uploadedPhotos = 0;
      int pendingPhotos = 0;
      bool storageBucketUnavailable = false;
      String? storageWarning;

      // 4. Media Upload: Batch upload waypoint photos to Cloud Storage
      for (final waypoint in unsyncedWaypoints) {
        if (waypoint.localPhotoPath != null &&
            waypoint.localPhotoPath!.isNotEmpty) {
          pendingPhotos++;
          final file = File(waypoint.localPhotoPath!);
          if (await file.exists()) {
            if (storageBucketUnavailable) {
              // Fail fast: skip further photo uploads in this sync if bucket unavailable
              continue;
            }
            try {
              final storageRef = _storage.ref(
                'users/$userId/routes/${waypoint.routeId}/waypoints/${waypoint.waypointId}.jpg',
              );
              // Aggressive timeout (8s) so spotty wilderness cellular or unprovisioned buckets never freeze the app
              final uploadTask = storageRef.putFile(
                file,
                SettableMetadata(contentType: 'image/jpeg'),
              );
              final snapshot = await uploadTask.timeout(
                const Duration(seconds: 8),
                onTimeout: () {
                  uploadTask.cancel();
                  throw TimeoutException('Storage upload timed out after 8s');
                },
              );
              if (snapshot.state == TaskState.success) {
                final downloadUrl = await snapshot.ref.getDownloadURL().timeout(
                  const Duration(seconds: 5),
                );
                waypoint.remotePhotoUrl = downloadUrl;
                uploadedPhotos++;
              }
            } catch (e) {
              // ignore: avoid_print
              print('[SyncService] Failed photo upload for waypoint ${waypoint.waypointId}: $e');
              final errorStr = e.toString().toLowerCase();
              if (errorStr.contains('object-not-found') ||
                  errorStr.contains('bucket') ||
                  errorStr.contains('not found')) {
                storageBucketUnavailable = true;
                storageWarning = 'Photos saved locally; Firebase Storage bucket not yet provisioned.';
                // ignore: avoid_print
                print('[SyncService] Cloud Storage bucket unavailable. Proceeding with metadata sync.');
              } else if (errorStr.contains('timeout')) {
                storageWarning = 'Photo upload timed out (spotty connection); metadata synced.';
              } else {
                storageWarning = 'Photos saved locally (upload deferred).';
              }
            }
          }
        }
      }

      // 5. Firestore Batch Writes
      // Write TrailRoutes
      final userDoc = _firestore.collection('users').doc(userId);

      // Firestore batches are limited to 500 operations. We chunk operations safely at 400.
      WriteBatch currentBatch = _firestore.batch();
      int currentBatchCount = 0;

      for (final route in unsyncedRoutes) {
        route.userId = userId;
        final routeRef = userDoc.collection('routes').doc(route.routeId);
        currentBatch.set(routeRef, route.toFirestore(), SetOptions(merge: true));
        currentBatchCount++;

        if (currentBatchCount >= 400) {
          await currentBatch.commit();
          currentBatch = _firestore.batch();
          currentBatchCount = 0;
        }
      }

      // Write Waypoints
      for (final waypoint in unsyncedWaypoints) {
        final wpRef = userDoc
            .collection('routes')
            .doc(waypoint.routeId)
            .collection('waypoints')
            .doc(waypoint.waypointId);
        currentBatch.set(wpRef, waypoint.toFirestore(), SetOptions(merge: true));
        currentBatchCount++;

        if (currentBatchCount >= 400) {
          await currentBatch.commit();
          currentBatch = _firestore.batch();
          currentBatchCount = 0;
        }
      }

      // Write Coordinates
      for (final coord in unsyncedCoordinates) {
        final coordRef = userDoc
            .collection('routes')
            .doc(coord.routeId)
            .collection('coordinates')
            .doc(coord.coordinateId);
        currentBatch.set(coordRef, coord.toFirestore(), SetOptions(merge: true));
        currentBatchCount++;

        if (currentBatchCount >= 400) {
          await currentBatch.commit();
          currentBatch = _firestore.batch();
          currentBatchCount = 0;
        }
      }

      // Commit any remaining operations
      if (currentBatchCount > 0) {
        await currentBatch.commit();
      }

      // 6. Update Local Isar Records (Mark isSynced = true)
      final now = DateTime.now();
      await isar.writeTxn(() async {
        for (final route in unsyncedRoutes) {
          route.isSynced = true;
          route.syncedAt = now;
          await isar.trailRoutes.put(route);
        }

        for (final waypoint in unsyncedWaypoints) {
          if (waypoint.localPhotoPath != null &&
              waypoint.localPhotoPath!.isNotEmpty &&
              waypoint.remotePhotoUrl == null) {
            // Keep isSynced = false so photo upload will be retried in future sync passes.
            waypoint.isSynced = false;
          } else {
            waypoint.isSynced = true;
          }
          await isar.waypoints.put(waypoint);
        }

        for (final coord in unsyncedCoordinates) {
          coord.isSynced = true;
          await isar.coordinates.put(coord);
        }
      });

      _isSyncing = false;
      _setStatus(SyncStatus.completed);

      return SyncResult(
        success: true,
        syncedRoutesCount: unsyncedRoutes.length,
        syncedWaypointsCount: unsyncedWaypoints.length,
        syncedCoordinatesCount: unsyncedCoordinates.length,
        uploadedMediaCount: uploadedPhotos,
        warningMessage: (pendingPhotos > uploadedPhotos) ? storageWarning : null,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _isSyncing = false;
      _setStatus(SyncStatus.error);
      // ignore: avoid_print
      print('[SyncService] Cloud sync error: $e');
      return SyncResult.failure(e.toString());
    }
  }

  void _setStatus(SyncStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}
