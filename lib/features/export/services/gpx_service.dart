import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/isar_service.dart';
import '../../../core/database/models/coordinate.dart';
import '../../../core/database/models/trail_route.dart';
import '../../../core/database/models/waypoint.dart';
import '../../auth/presentation/value_gate_modal.dart';
import '../../auth/services/auth_service.dart';

class GpxService {
  static final GpxService _instance = GpxService._internal();
  factory GpxService() => _instance;
  GpxService._internal();

  /// Converts a TrailRoute, its telemetry coordinates, and waypoints into standard GPX 1.1 XML
  String generateGpxString({
    required TrailRoute route,
    required List<Coordinate> coordinates,
    required List<Waypoint> waypoints,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<gpx version="1.1" creator="Trailwire Wilderness Utility - https://usetrailwire.com" '
      'xmlns="http://www.topografix.com/GPX/1/1" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
      'xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">',
    );

    // Metadata section
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>${_escapeXml(route.name)}</name>');
    buffer.writeln('    <desc>Logged with Trailwire Offline Navigation</desc>');
    buffer.writeln('    <time>${route.startTime.toUtc().toIso8601String()}</time>');
    buffer.writeln('  </metadata>');

    // Waypoint Markers (<wpt>)
    for (final wp in waypoints) {
      buffer.writeln('  <wpt lat="${wp.latitude.toStringAsFixed(7)}" lon="${wp.longitude.toStringAsFixed(7)}">');
      if (wp.altitude != null) {
        buffer.writeln('    <ele>${wp.altitude!.toStringAsFixed(1)}</ele>');
      }
      buffer.writeln('    <time>${wp.timestamp.toUtc().toIso8601String()}</time>');
      buffer.writeln('    <name>${_escapeXml(wp.title)}</name>');
      if (wp.notes != null && wp.notes!.isNotEmpty) {
        buffer.writeln('    <desc>${_escapeXml(wp.notes!)}</desc>');
      }
      if (wp.category != null && wp.category!.isNotEmpty) {
        buffer.writeln('    <sym>${_escapeXml(wp.category!)}</sym>');
        buffer.writeln('    <type>${_escapeXml(wp.category!)}</type>');
      }
      buffer.writeln('  </wpt>');
    }

    // Track Section (<trk>)
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${_escapeXml(route.name)}</name>');
    buffer.writeln('    <type>Hiking</type>');
    buffer.writeln('    <trkseg>');

    for (final coord in coordinates) {
      buffer.writeln('      <trkpt lat="${coord.latitude.toStringAsFixed(7)}" lon="${coord.longitude.toStringAsFixed(7)}">');
      if (coord.altitude != null) {
        buffer.writeln('        <ele>${coord.altitude!.toStringAsFixed(1)}</ele>');
      }
      buffer.writeln('        <time>${coord.timestamp.toUtc().toIso8601String()}</time>');
      if (coord.speed != null && coord.speed! >= 0) {
        buffer.writeln('        <speed>${coord.speed!.toStringAsFixed(2)}</speed>');
      }
      buffer.writeln('      </trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  /// Saves the generated GPX XML string to a local sandbox file
  Future<File> saveGpxToFile({
    required TrailRoute route,
    required String gpxContent,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final sanitizedName = route.name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    final filename = '${sanitizedName}_${route.startTime.millisecondsSinceEpoch}.gpx';
    final file = File('${tempDir.path}/$filename');
    await file.writeAsString(gpxContent, flush: true);
    return file;
  }

  /// Exports and shares the route via iOS Share Sheet.
  /// Gated by ValueGateModal: unauthenticated/anonymous guests are prompted to link/sign-in first.
  Future<bool> exportAndShareRoute({
    required BuildContext context,
    required TrailRoute route,
    List<Coordinate>? coordinates,
    List<Waypoint>? waypoints,
    AuthService? authService,
    IsarService? isarService,
  }) async {
    final auth = authService ?? AuthService();
    final isar = isarService ?? IsarService();

    // 1. The Value Gate Check
    if (auth.isAnonymous) {
      final unlocked = await ValueGateModal.show(
        context,
        title: 'Unlock GPX Track Export',
        description:
            'Create a free account to export high-resolution GPX route logs and waypoint markers for Gaia GPS, CalTopo, and Garmin devices.',
        targetFeature: 'gpx_export',
        authService: auth,
      );

      if (!unlocked) {
        return false;
      }
    }

    // 2. Fetch coordinates & waypoints from Isar if not passed
    final resolvedCoordinates = coordinates ??
        await isar.getCoordinatesForRoute(route.routeId);
    final resolvedWaypoints = waypoints ??
        await isar.getWaypointsForRoute(route.routeId);

    // 3. Generate GPX XML string
    final gpxXml = generateGpxString(
      route: route,
      coordinates: resolvedCoordinates,
      waypoints: resolvedWaypoints,
    );

    // 4. Save to local temporary file
    final gpxFile = await saveGpxToFile(
      route: route,
      gpxContent: gpxXml,
    );

    // 5. Trigger Native Share Sheet
    final xFile = XFile(
      gpxFile.path,
      mimeType: 'application/gpx+xml',
      name: '${route.name}.gpx',
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: 'Wilderness GPS Track: ${route.name}',
        subject: route.name,
      ),
    );

    return true;
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
