import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/database/models/trail_route.dart';
import '../../../core/database/models/waypoint.dart';
import '../../map/presentation/trail_hud.dart';
import '../../map/presentation/trail_map_view.dart';
import '../../map/services/offline_map_service.dart';
import '../../auth/presentation/value_gate_modal.dart';
import '../../auth/services/auth_service.dart';
import '../../export/services/gpx_service.dart';
import '../../safety/models/sos_trip.dart';
import '../../safety/presentation/sos_trip_setup_view.dart';
import '../../sync/models/sync_result.dart';
import '../../sync/services/sync_service.dart';
import '../../waypoints/presentation/waypoint_modal.dart';
import '../models/app_mode.dart';
import '../services/location_service.dart';
import '../services/trail_recording_service.dart';

class TrailScreen extends StatefulWidget {
  final TrailRecordingService? recordingService;
  final LocationService? locationService;

  const TrailScreen({
    super.key,
    this.recordingService,
    this.locationService,
  });

  @override
  State<TrailScreen> createState() => _TrailScreenState();
}

class _TrailScreenState extends State<TrailScreen> {
  late final TrailRecordingService _recordingService;
  late final LocationService _locationService;

  AppMode _currentMode = AppMode.basecamp;

  final GlobalKey<TrailMapViewState> _mapKey = GlobalKey<TrailMapViewState>();
  final List<LatLng> _trailCoordinates = [];
  final List<Waypoint> _waypoints = [];

  StreamSubscription<TrailRoute?>? _routeSubscription;
  StreamSubscription? _coordinateSubscription;
  StreamSubscription<SyncStatus>? _syncStatusSubscription;

  TrailRoute? _activeRoute;
  double _currentElevation = 0.0;
  double _currentSpeed = 0.0;
  String _currentMapStyle = OfflineMapService.defaultStyleUrl;
  bool _isSyncing = false;
  SosTrip? _activeSosTrip;

  @override
  void initState() {
    super.initState();
    _recordingService = widget.recordingService ?? TrailRecordingService();
    _locationService = widget.locationService ?? LocationService();

    _activeRoute = _recordingService.activeRoute;

    _routeSubscription = _recordingService.activeRouteStream.listen((route) {
      if (mounted) {
        setState(() {
          _activeRoute = route;
        });
      }
    });

    _coordinateSubscription = _recordingService.newCoordinateStream.listen((coord) {
      if (mounted) {
        setState(() {
          _trailCoordinates.add(LatLng(coord.latitude, coord.longitude));
          _currentElevation = coord.altitude ?? _currentElevation;
          _currentSpeed = coord.speed ?? _currentSpeed;
        });
      }
    });

    _syncStatusSubscription = SyncService().syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isSyncing = status == SyncStatus.syncing;
        });
      }
    });

    if (_recordingService.isTracking) {
      _currentMode = AppMode.activeTracking;
    } else {
      _currentMode = AppMode.basecamp;
    }
  }

  Future<void> _handleStartTrip() async {
    final lastCoord = _recordingService.lastCoordinate;
    final currentLoc = lastCoord == null ? await _locationService.getCurrentLocation() : null;
    final lat = lastCoord?.latitude ?? currentLoc?.latitude;
    final lng = lastCoord?.longitude ?? currentLoc?.longitude;

    if (!mounted) return;

    final sosTrip = await SosTripSetupView.show(
      context,
      currentLatitude: lat,
      currentLongitude: lng,
    );

    if (sosTrip != null) {
      _activeSosTrip = sosTrip;
    }

    final now = DateTime.now();
    await _recordingService.startRecording(
      name: sosTrip?.tripName ?? 'Wilderness Trek ${now.month}/${now.day}',
    );

    if (mounted) {
      setState(() {
        _currentMode = AppMode.activeTracking;
        _trailCoordinates.clear();
        _waypoints.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sosTrip != null
                ? 'Trail Mode Active: SOS Armed for ${sosTrip.emergencyContact}'
                : 'Trail Mode Active: Recording trail path...',
          ),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _routeSubscription?.cancel();
    _coordinateSubscription?.cancel();
    _syncStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handlePause() async {
    await _recordingService.pauseRecording();
  }

  Future<void> _handleResume() async {
    await _recordingService.resumeRecording();
  }

  Future<void> _handleFinish() async {
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Finish Trail Recording?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Your path, telemetry, and waypoints will be finalized and stored securely in offline storage.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Finish Trip'),
          ),
        ],
      ),
    );

    if (shouldFinish == true) {
      final completed = await _recordingService.stopRecording();
      if (mounted && completed != null) {
        // Automatically disarm active SOS safety trip when user returns safely
        if (_activeSosTrip != null) {
          await _disarmActiveSosTrip();
        }

        // Trigger deferred cloud sync in the background
        SyncService().syncPendingData();

        // Return UI to Basecamp Mode
        setState(() {
          _currentMode = AppMode.basecamp;
        });

        // Show Post-Trip Summary & Value Gate conversion prompt
        _showPostTripSummary(completed);
      }
    }
  }

  void _showPostTripSummary(TrailRoute route) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF334155), width: 1.5)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Trip Saved to Local Isar DB',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryStat(
                      'TIME',
                      '${(route.durationSeconds ~/ 60)}m',
                    ),
                    _buildSummaryStat(
                      'DISTANCE',
                      '${(route.totalDistanceMeters / 1000).toStringAsFixed(2)} km',
                    ),
                    _buildSummaryStat(
                      'ELEV GAIN',
                      '+${route.totalElevationGainMeters.toStringAsFixed(0)} m',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Direct GPX Track Export Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await GpxService().exportAndShareRoute(
                      context: context,
                      route: route,
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text(
                    'EXPORT GPX TRACK',
                    style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: const Color(0xFF0B0F12),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // The Value Gate Callout (for unlinked guest users)
              if (AuthService().isAnonymous) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        const Color(0xFF00E676).withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, color: Color(0xFF38BDF8), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'VALUE GATE: PRO FEATURES',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Link your account to unlock full GPX Export, Rich Elevation Profile, and automatic Cloud Sync.',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            final linked = await ValueGateModal.show(
                              context,
                              title: 'Unlock GPX & Cloud Sync',
                              description:
                                  'Connect with Apple, Google, or Email to export your GPS tracks and protect your backcountry logs with cloud backup.',
                            );
                            if (linked) {
                              SyncService().syncPendingData();
                            }
                          },
                          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                          label: const Text('Connect with Apple, Google, or Email'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: const Color(0xFF0B0F12),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Future<void> _triggerManualSync() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking network and syncing pending records...'),
        duration: Duration(seconds: 1),
      ),
    );
    final result = await SyncService().syncPendingData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? (result.warningMessage != null
                  ? 'Sync: ${result.syncedRoutesCount} routes, ${result.syncedWaypointsCount} waypoints. (${result.warningMessage})'
                  : 'Sync complete: ${result.syncedRoutesCount} routes, ${result.syncedWaypointsCount} waypoints, ${result.uploadedMediaCount} photos.')
              : 'Sync note: ${result.errorMessage}',
        ),
        backgroundColor: result.success
            ? const Color(0xFF00E676)
            : const Color(0xFF334155),
      ),
    );
  }

  Future<void> _handleMarkWaypoint() async {
    final lastCoord = _recordingService.lastCoordinate;
    final currentLoc = lastCoord == null
        ? await _locationService.getCurrentLocation()
        : null;

    final lat = lastCoord?.latitude ?? currentLoc?.latitude;
    final lng = lastCoord?.longitude ?? currentLoc?.longitude;
    final alt = lastCoord?.altitude ?? currentLoc?.altitude;

    if (!mounted) return;

    final newWaypoint = await WaypointModal.show(
      context,
      recordingService: _recordingService,
      latitude: lat,
      longitude: lng,
      altitude: alt,
    );

    if (newWaypoint != null && mounted) {
      setState(() {
        _waypoints.add(newWaypoint);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked: ${newWaypoint.title}'),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleRecenter() {
    if (_trailCoordinates.isNotEmpty) {
      _mapKey.currentState?.recenterOn(_trailCoordinates.last);
    }
  }

  void _toggleMapStyle() {
    setState(() {
      _currentMapStyle = _currentMapStyle == OfflineMapService.outdoorStyleUrl
          ? OfflineMapService.darkStyleUrl
          : OfflineMapService.outdoorStyleUrl;
    });
    _mapKey.currentState?.setMapStyle(_currentMapStyle);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _currentMapStyle == OfflineMapService.outdoorStyleUrl
              ? 'Active: Outdoor Topo (CARTO Voyager)'
              : 'Active: Tactical Dark Mode (CARTO Dark Matter)',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  Future<void> _showOfflinePackDialog() async {
    final controller = _mapKey.currentState?.controller;
    if (controller == null) return;

    final visibleBounds = await controller.getVisibleRegion();
    if (!mounted) return;

    final nameController = TextEditingController(text: 'Offline Sector ${DateTime.now().day}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cache Offline Vector Tiles',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Download vector tiles for the currently visible map viewport to navigate without internet.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Region Name',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              Navigator.of(ctx).pop();
              if (name.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Caching tiles for "$name"...')),
                );
                await OfflineMapService.downloadOfflineRegion(
                  bounds: visibleBounds,
                  regionName: name,
                  minZoom: 10.0,
                  maxZoom: 15.0,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: const Color(0xFF0B0F12),
            ),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleArmSos() async {
    if (_activeSosTrip != null) {
      _showActiveSosSheet();
    } else {
      final trip = await SosTripSetupView.show(
        context,
        initialTripName: _activeRoute?.name,
        currentLatitude: _trailCoordinates.isNotEmpty ? _trailCoordinates.last.latitude : null,
        currentLongitude: _trailCoordinates.isNotEmpty ? _trailCoordinates.last.longitude : null,
      );

      if (trip != null && mounted) {
        setState(() {
          _activeSosTrip = trip;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SOS Dead Man\'s Switch Armed for ${trip.emergencyContact}!'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showActiveSosSheet() {
    final trip = _activeSosTrip;
    if (trip == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFFEF4444), width: 2.0)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFFEF4444), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Active SOS: ${trip.tripName}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Emergency Contact: ${trip.emergencyContact}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Return Deadline: ${trip.expectedReturnTime.toLocal().toString().split('.').first}',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13)),
                    if (trip.routeIntent != null && trip.routeIntent!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Route Intent: ${trip.routeIntent}',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _disarmActiveSosTrip();
                },
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('DISARM SOS - I RETURNED SAFELY'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: const Color(0xFF0B0F12),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _disarmActiveSosTrip() async {
    final trip = _activeSosTrip;
    if (trip == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('sos_trips')
          .doc(trip.tripId)
          .update({'status': 'COMPLETED', 'completedAt': FieldValue.serverTimestamp()});
    } catch (_) {}

    if (mounted) {
      setState(() {
        _activeSosTrip = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS Trip Disarmed. Glad you returned safely!'),
          backgroundColor: Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F12),
      body: Stack(
        children: [
          // Fullscreen MapLibre View
          TrailMapView(
            key: _mapKey,
            trailCoordinates: _trailCoordinates,
            waypoints: _waypoints,
            styleString: _currentMapStyle,
          ),

          // High-Contrast Trail HUD Overlay (Basecamp Mode & Trail Mode)
          TrailHud(
            mode: _currentMode,
            activeRoute: _activeRoute,
            currentElevationMeters: _currentElevation,
            currentSpeedMps: _currentSpeed,
            isPaused: _recordingService.isPaused,
            onStartTrip: _handleStartTrip,
            onPause: _handlePause,
            onResume: _handleResume,
            onFinish: _handleFinish,
            onMarkWaypoint: _handleMarkWaypoint,
            onRecenter: _handleRecenter,
            onSync: _triggerManualSync,
            onDownloadOffline: _showOfflinePackDialog,
            onToggleMapStyle: _toggleMapStyle,
            onArmSos: _activeSosTrip != null ? _showActiveSosSheet : _handleArmSos,
            isSosArmed: _activeSosTrip != null,
            isSyncing: _isSyncing,
          ),
        ],
      ),
    );
  }
}
