import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/database/models/waypoint.dart';
import '../services/offline_map_service.dart';

class TrailMapView extends StatefulWidget {
  final List<LatLng> trailCoordinates;
  final List<Waypoint> waypoints;
  final LatLng? initialCenter;
  final double initialZoom;
  final String styleString;
  final bool isTrackingUser;
  final void Function(MapLibreMapController controller)? onMapCreated;
  final void Function(LatLng point)? onMapClick;

  const TrailMapView({
    super.key,
    this.trailCoordinates = const [],
    this.waypoints = const [],
    this.initialCenter,
    this.initialZoom = 14.0,
    this.styleString = OfflineMapService.defaultStyleUrl,
    this.isTrackingUser = true,
    this.onMapCreated,
    this.onMapClick,
  });

  @override
  State<TrailMapView> createState() => TrailMapViewState();
}

class TrailMapViewState extends State<TrailMapView> {
  MapLibreMapController? _mapController;
  Line? _trailLine;
  final Map<String, Symbol> _waypointSymbols = {};
  bool _styleLoaded = false;

  MapLibreMapController? get controller => _mapController;

  @override
  void didUpdateWidget(covariant TrailMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapController != null) {
      if (oldWidget.styleString != widget.styleString) {
        _styleLoaded = false;
        _mapController!.setStyle(widget.styleString);
      } else if (_styleLoaded) {
        if (oldWidget.trailCoordinates != widget.trailCoordinates) {
          _updateTrailPolyline();
        }
        if (oldWidget.waypoints != widget.waypoints) {
          _updateWaypoints();
        }
      }
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    widget.onMapCreated?.call(controller);
  }

  void _onStyleLoaded() {
    setState(() {
      _styleLoaded = true;
    });
    _updateTrailPolyline();
    _updateWaypoints();
  }

  Future<void> _updateTrailPolyline() async {
    if (_mapController == null || !_styleLoaded) return;

    final coords = widget.trailCoordinates;
    if (coords.length < 2) {
      if (_trailLine != null) {
        await _mapController!.removeLine(_trailLine!);
        _trailLine = null;
      }
      return;
    }

    try {
      if (_trailLine == null) {
        _trailLine = await _mapController!.addLine(
          LineOptions(
            geometry: coords,
            lineColor: '#00E676', // High-contrast neon green for outdoor sunlight visibility
            lineWidth: 5.0,
            lineOpacity: 0.95,
            lineJoin: 'round',
          ),
        );
      } else {
        await _mapController!.updateLine(
          _trailLine!,
          LineOptions(geometry: coords),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[TrailMapView] Error updating polyline: $e');
    }
  }

  Future<void> _updateWaypoints() async {
    if (_mapController == null || !_styleLoaded) return;

    final currentWaypointIds = widget.waypoints.map((w) => w.waypointId).toSet();

    // Remove symbols no longer in list
    final toRemove = _waypointSymbols.keys
        .where((id) => !currentWaypointIds.contains(id))
        .toList();
    for (final id in toRemove) {
      final symbol = _waypointSymbols.remove(id);
      if (symbol != null) {
        await _mapController!.removeSymbol(symbol);
      }
    }

    // Add new symbols
    for (final waypoint in widget.waypoints) {
      if (!_waypointSymbols.containsKey(waypoint.waypointId)) {
        try {
          final symbol = await _mapController!.addSymbol(
            SymbolOptions(
              geometry: LatLng(waypoint.latitude, waypoint.longitude),
              textField: waypoint.title,
              textSize: 12.0,
              textColor: '#FFFFFF',
              textHaloColor: '#000000',
              textHaloWidth: 1.5,
              textOffset: const Offset(0, 1.2),
              iconColor: _getCategoryColor(waypoint.category),
              iconSize: 1.5,
            ),
          );
          _waypointSymbols[waypoint.waypointId] = symbol;
        } catch (e) {
          // ignore: avoid_print
          print('[TrailMapView] Error adding waypoint symbol: $e');
        }
      }
    }
  }

  String _getCategoryColor(String? category) {
    switch (category) {
      case 'water_source':
        return '#00B0FF'; // Blue
      case 'campsite':
        return '#FFD600'; // Amber
      case 'hazard':
        return '#FF1744'; // Red
      case 'viewpoint':
        return '#A855F7'; // Purple
      default:
        return '#00E676'; // Green
    }
  }

  /// Update the active vector tile style URL
  Future<void> setMapStyle(String styleUrl) async {
    if (_mapController == null) return;
    _styleLoaded = false;
    await _mapController!.setStyle(styleUrl);
  }

  /// Recenter map on specific coordinate
  Future<void> recenterOn(LatLng point, {double? zoom}) async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: point,
          zoom: zoom ?? widget.initialZoom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultPosition = widget.initialCenter ??
        (widget.trailCoordinates.isNotEmpty
            ? widget.trailCoordinates.last
            : const LatLng(37.7749, -122.4194));

    return MapLibreMap(
      styleString: widget.styleString,
      initialCameraPosition: CameraPosition(
        target: defaultPosition,
        zoom: widget.initialZoom,
      ),
      myLocationEnabled: true,
      myLocationTrackingMode: widget.isTrackingUser
          ? MyLocationTrackingMode.tracking
          : MyLocationTrackingMode.none,
      myLocationRenderMode: MyLocationRenderMode.compass,
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onMapClick: (point, latLng) => widget.onMapClick?.call(latLng),
      compassEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      trackCameraPosition: true,
    );
  }
}
