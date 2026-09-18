import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/isar_service.dart';
import '../../../core/database/models/coordinate.dart';
import '../../../core/database/models/trail_route.dart';
import '../../../core/database/models/waypoint.dart';
import '../../../core/models/location_data.dart';
import '../../../core/utils/geo_utils.dart';
import 'location_service.dart';

class TrailRecordingService with WidgetsBindingObserver {
  static final TrailRecordingService _instance =
      TrailRecordingService._internal();
  factory TrailRecordingService() => _instance;

  final LocationService _locationService;
  final IsarService _isarService;
  final Uuid _uuid;

  TrailRecordingService._internal({
    LocationService? locationService,
    IsarService? isarService,
    Uuid? uuid,
  })  : _locationService = locationService ?? LocationService(),
        _isarService = isarService ?? IsarService(),
        _uuid = uuid ?? const Uuid() {
    WidgetsBinding.instance.addObserver(this);
  }

  TrailRoute? _activeRoute;
  Coordinate? _lastCoordinate;
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _metricsTimer;

  final List<Coordinate> _coordinateBatch = [];
  static const int _batchFlushThreshold = 5;

  final StreamController<TrailRoute?> _activeRouteController =
      StreamController<TrailRoute?>.broadcast();
  final StreamController<Coordinate> _newCoordinateController =
      StreamController<Coordinate>.broadcast();

  TrailRoute? get activeRoute => _activeRoute;
  bool get isTracking => _activeRoute != null;
  bool get isRecording => _activeRoute != null && _activeRoute!.status == 'active';
  bool get isPaused => _activeRoute != null && _activeRoute!.status == 'paused';
  Coordinate? get lastCoordinate => _lastCoordinate;

  Stream<TrailRoute?> get activeRouteStream => _activeRouteController.stream;
  Stream<Coordinate> get newCoordinateStream => _newCoordinateController.stream;

  /// Start recording a new trail session and create its initial Isar TrailRoute record.
  Future<TrailRoute> startRecording({
    required String name,
    String? userId,
    double distanceFilterMeters = 5.0,
  }) async {
    // If an active session is already running, return it or finalize it first
    if (_activeRoute != null) {
      if (isPaused) {
        await resumeRecording();
        return _activeRoute!;
      }
      return _activeRoute!;
    }

    final isar = await _isarService.db;
    final routeId = _uuid.v4();
    final now = DateTime.now();

    final newRoute = TrailRoute()
      ..routeId = routeId
      ..userId = userId
      ..name = name.trim().isEmpty ? 'Trail Trek ${now.month}/${now.day}' : name
      ..startTime = now
      ..totalDistanceMeters = 0.0
      ..totalElevationGainMeters = 0.0
      ..totalElevationLossMeters = 0.0
      ..durationSeconds = 0
      ..status = 'active'
      ..isSynced = false
      ..createdAt = now
      ..updatedAt = now;

    // Persist immediately to local Isar DB (Single Source of Truth)
    await isar.writeTxn(() async {
      await isar.trailRoutes.put(newRoute);
    });

    _activeRoute = newRoute;
    _lastCoordinate = null;
    _coordinateBatch.clear();
    _activeRouteController.add(_activeRoute);

    // Start native background tracking
    await _locationService.startTracking(
      routeId: routeId,
      distanceFilterMeters: distanceFilterMeters,
    );

    // Subscribe to incoming location coordinates
    _locationSubscription = _locationService.locationStream.listen(
      _handleLocationUpdate,
      onError: (error) {
        // ignore: avoid_print
        print('[TrailRecordingService] Location stream error: $error');
      },
    );

    // Start timer for duration tracking
    _startMetricsTimer();

    return _activeRoute!;
  }

  /// Pause current recording. Flushes queued coordinates to Isar.
  Future<void> pauseRecording() async {
    if (_activeRoute == null || _activeRoute!.status != 'active') return;

    await _locationService.pauseTracking();
    _metricsTimer?.cancel();

    _activeRoute!.status = 'paused';
    _activeRoute!.updatedAt = DateTime.now();

    await _flushBatch();
    _activeRouteController.add(_activeRoute);
  }

  /// Resume paused recording.
  Future<void> resumeRecording() async {
    if (_activeRoute == null || _activeRoute!.status != 'paused') return;

    await _locationService.startTracking(routeId: _activeRoute!.routeId);
    _activeRoute!.status = 'active';
    _activeRoute!.updatedAt = DateTime.now();

    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      await isar.trailRoutes.put(_activeRoute!);
    });

    _startMetricsTimer();
    _activeRouteController.add(_activeRoute);
  }

  /// Finalize and stop current recording session, committing all final telemetry.
  Future<TrailRoute?> stopRecording() async {
    if (_activeRoute == null) return null;

    await _locationService.stopTracking();
    _metricsTimer?.cancel();
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    final now = DateTime.now();
    _activeRoute!.status = 'completed';
    _activeRoute!.endTime = now;
    _activeRoute!.updatedAt = now;

    // Flush any pending coordinates and update route
    await _flushBatch();

    final completedRoute = _activeRoute;
    _activeRoute = null;
    _lastCoordinate = null;
    _activeRouteController.add(null);

    return completedRoute;
  }

  /// Record a rich waypoint attached to the current active route.
  Future<Waypoint> addWaypoint({
    required String title,
    String? notes,
    String? category,
    String? localPhotoPath,
    String? localAudioPath,
    double? latitudeOverride,
    double? longitudeOverride,
    double? altitudeOverride,
  }) async {
    if (_activeRoute == null) {
      throw StateError('Cannot add waypoint without an active recording session.');
    }

    final isar = await _isarService.db;
    final now = DateTime.now();

    // Coordinates: use override if supplied, else last coordinate, else single-shot current location
    double latitude = latitudeOverride ?? 0.0;
    double longitude = longitudeOverride ?? 0.0;
    double? altitude = altitudeOverride;

    if (latitudeOverride == null && longitudeOverride == null) {
      if (_lastCoordinate != null) {
        latitude = _lastCoordinate!.latitude;
        longitude = _lastCoordinate!.longitude;
        altitude = _lastCoordinate!.altitude;
      } else {
        final currentLoc = await _locationService.getCurrentLocation();
        if (currentLoc != null) {
          latitude = currentLoc.latitude;
          longitude = currentLoc.longitude;
          altitude = currentLoc.altitude;
        }
      }
    }

    final waypoint = Waypoint()
      ..waypointId = _uuid.v4()
      ..routeId = _activeRoute!.routeId
      ..title = title
      ..notes = notes
      ..category = category
      ..latitude = latitude
      ..longitude = longitude
      ..altitude = altitude
      ..localPhotoPath = localPhotoPath
      ..localAudioPath = localAudioPath
      ..timestamp = now
      ..isSynced = false
      ..createdAt = now
      ..updatedAt = now;

    await isar.writeTxn(() async {
      await isar.waypoints.put(waypoint);
    });

    return waypoint;
  }

  /// Process incoming location payload from native CoreLocation.
  void _handleLocationUpdate(LocationData locationData) {
    if (_activeRoute == null || _activeRoute!.status != 'active') return;

    final coordinate = locationData.toCoordinate(
      routeId: _activeRoute!.routeId,
      coordinateId: _uuid.v4(),
    );

    // Calculate rolling distance
    if (_lastCoordinate != null) {
      final distanceDelta = GeoUtils.calculateDistanceMeters(
        _lastCoordinate!.latitude,
        _lastCoordinate!.longitude,
        coordinate.latitude,
        coordinate.longitude,
      );

      // Filter out spurious jumps (e.g. > 150m between points on foot)
      if (distanceDelta < 150.0) {
        _activeRoute!.totalDistanceMeters += distanceDelta;
      }

      // Calculate elevation gain/loss
      final elevationDelta = GeoUtils.calculateElevationDelta(
        _lastCoordinate!.altitude,
        coordinate.altitude,
      );

      if (elevationDelta > 0) {
        _activeRoute!.totalElevationGainMeters += elevationDelta;
      } else if (elevationDelta < 0) {
        _activeRoute!.totalElevationLossMeters += elevationDelta.abs();
      }
    }

    _lastCoordinate = coordinate;
    _coordinateBatch.add(coordinate);
    _newCoordinateController.add(coordinate);

    // Flush batch when reaching batch size limit
    if (_coordinateBatch.length >= _batchFlushThreshold) {
      _flushBatch();
    }
  }

  /// Write accumulated coordinates and updated route metrics to Isar in a single transaction.
  Future<void> _flushBatch() async {
    if (_activeRoute == null) return;

    final isar = await _isarService.db;
    final batchToPersist = List<Coordinate>.from(_coordinateBatch);
    _coordinateBatch.clear();

    _activeRoute!.updatedAt = DateTime.now();

    await isar.writeTxn(() async {
      if (batchToPersist.isNotEmpty) {
        await isar.coordinates.putAll(batchToPersist);
      }
      await isar.trailRoutes.put(_activeRoute!);
    });

    _activeRouteController.add(_activeRoute);
  }

  /// Manually trigger a batch flush (public for testing and lifecycle hooks).
  Future<void> flushBatch() async {
    await _flushBatch();
  }

  void _startMetricsTimer() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeRoute != null && _activeRoute!.status == 'active') {
        _activeRoute!.durationSeconds += 1;
        _activeRouteController.add(_activeRoute);
      }
    });
  }

  // MARK: - App Lifecycle Observer

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is moving into the background or being suspended.
        // Flush all in-memory coordinates to Isar disk immediately.
        _flushBatch();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _flushBatch();
        break;
      case AppLifecycleState.resumed:
        // App resumed into foreground.
        if (_activeRoute != null && _activeRoute!.status == 'active') {
          _activeRouteController.add(_activeRoute);
        }
        break;
    }
  }

  /// Teardown observer and timers.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsTimer?.cancel();
    _locationSubscription?.cancel();
    _activeRouteController.close();
    _newCoordinateController.close();
  }
}
