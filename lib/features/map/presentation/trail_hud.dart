import 'package:flutter/material.dart';
import '../../../core/database/models/trail_route.dart';
import '../../tracking/models/app_mode.dart';

class TrailHud extends StatelessWidget {
  final AppMode mode;
  final TrailRoute? activeRoute;
  final double currentElevationMeters;
  final double currentSpeedMps;
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onMarkWaypoint;
  final VoidCallback? onStartTrip;
  final VoidCallback? onRecenter;
  final VoidCallback? onSync;
  final VoidCallback? onDownloadOffline;
  final VoidCallback? onToggleMapStyle;
  final VoidCallback? onArmSos;
  final bool isSyncing;
  final bool isSosArmed;

  const TrailHud({
    super.key,
    this.mode = AppMode.activeTracking,
    required this.activeRoute,
    this.currentElevationMeters = 0.0,
    this.currentSpeedMps = 0.0,
    this.isPaused = false,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onMarkWaypoint,
    this.onStartTrip,
    this.onRecenter,
    this.onSync,
    this.onDownloadOffline,
    this.onToggleMapStyle,
    this.onArmSos,
    this.isSyncing = false,
    this.isSosArmed = false,
  });

  String _formatDuration(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatPace(double meters, int seconds) {
    if (meters < 20 || seconds < 5) return '--:--';
    final paceSecondsPerKm = (seconds / (meters / 1000)).clamp(120, 3600);
    final mins = (paceSecondsPerKm ~/ 60).toString().padLeft(2, '0');
    final secs = (paceSecondsPerKm.toInt() % 60).toString().padLeft(2, '0');
    return '$mins:$secs /km';
  }

  @override
  Widget build(BuildContext context) {
    if (mode == AppMode.basecamp) {
      return _buildBasecampMode(context);
    }
    return _buildTrailMode(context);
  }

  Widget _buildBasecampMode(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Basecamp Top Status Badge
          Positioned(
            top: 12,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xE60B0F12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.terrain_rounded, color: Color(0xFF00E676), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'BASECAMP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Basecamp Vertical Tool Column (Right Edge)
          Positioned(
            top: 12,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleMapStyle != null) ...[
                  _buildHeaderButton(
                    key: const ValueKey('toggle_style_btn'),
                    onPressed: onToggleMapStyle!,
                    tooltip: 'Map Layer Style',
                    icon: Icons.layers_rounded,
                    foregroundColor: const Color(0xFF38BDF8),
                  ),
                  const SizedBox(height: 10),
                ],
                if (onDownloadOffline != null) ...[
                  _buildHeaderButton(
                    key: const ValueKey('offline_pack_btn'),
                    onPressed: onDownloadOffline!,
                    tooltip: 'Cache Offline Map',
                    icon: Icons.cloud_download_rounded,
                    foregroundColor: const Color(0xFF38BDF8),
                  ),
                  const SizedBox(height: 10),
                ],
                if (onSync != null) ...[
                  _buildHeaderButton(
                    key: const ValueKey('cloud_sync_btn'),
                    onPressed: onSync!,
                    tooltip: 'Sync with Cloud',
                    icon: Icons.sync_rounded,
                    foregroundColor: const Color(0xFF00E676),
                    child: isSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: Color(0xFF00E676),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
                if (onRecenter != null)
                  _buildHeaderButton(
                    key: const ValueKey('recenter_btn'),
                    onPressed: onRecenter!,
                    tooltip: 'Recenter GPS',
                    icon: Icons.my_location,
                    foregroundColor: Colors.white,
                  ),
              ],
            ),
          ),

          // Basecamp Prominent Full-Width "Start Trip" Button
          if (onStartTrip != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xE60B0F12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  key: const ValueKey('start_trip_btn'),
                  onPressed: onStartTrip,
                  icon: const Icon(Icons.navigation_rounded, size: 22),
                  label: const Text(
                    'START TRIP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: const Color(0xFF0B0F12),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailMode(BuildContext context) {
    final durationSeconds = activeRoute?.durationSeconds ?? 0;
    final distanceMeters = activeRoute?.totalDistanceMeters ?? 0.0;
    final elevationGain = activeRoute?.totalElevationGainMeters ?? 0.0;

    return SafeArea(
      child: Stack(
        children: [
          // Top Trail Bar: Status Badge (Left) + SOS & Recenter (Right)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Active State Badge
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xE60B0F12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPaused
                            ? const Color(0xFFFFB300)
                            : const Color(0xFF00E676),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPaused
                                ? const Color(0xFFFFB300)
                                : const Color(0xFF00E676),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isPaused ? 'TRACKING PAUSED' : 'LIVE RECORDING',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: isPaused
                                  ? const Color(0xFFFFB300)
                                  : const Color(0xFF00E676),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Trail Mode Action Controls (Only SOS & Recenter)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onArmSos != null) ...[
                      _buildHeaderButton(
                        key: const ValueKey('sos_trip_btn'),
                        onPressed: onArmSos!,
                        tooltip: isSosArmed ? 'SOS Safety Armed' : 'Arm SOS Trip',
                        icon: isSosArmed ? Icons.shield_rounded : Icons.shield_outlined,
                        foregroundColor: isSosArmed ? const Color(0xFF00E676) : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (onRecenter != null)
                      _buildHeaderButton(
                        key: const ValueKey('recenter_btn'),
                        onPressed: onRecenter!,
                        tooltip: 'Recenter GPS',
                        icon: Icons.my_location,
                        foregroundColor: Colors.white,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Floating "Mark Waypoint" Button
          Positioned(
            right: 16,
            bottom: 210,
            child: FloatingActionButton.extended(
              key: const ValueKey('waypoint_fab'),
              heroTag: 'waypoint_fab',
              onPressed: onMarkWaypoint,
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: const Color(0xFF0B0F12),
              elevation: 6,
              icon: const Icon(Icons.add_location_alt_rounded, size: 22),
              label: const Text(
                'MARK PIN',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          // Bottom High-Contrast Telemetry Dashboard
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xF20B0F12), // Deep OLED black
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Metrics Grid (Time, Distance, Elevation, Pace)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem(
                        label: 'TIME',
                        value: _formatDuration(durationSeconds),
                        color: Colors.white,
                      ),
                      _buildDivider(),
                      _buildMetricItem(
                        label: 'DISTANCE',
                        value: _formatDistance(distanceMeters),
                        color: const Color(0xFF00E676),
                      ),
                      _buildDivider(),
                      _buildMetricItem(
                        label: 'ELEV GAIN',
                        value: '+${elevationGain.toStringAsFixed(0)} m',
                        color: const Color(0xFF38BDF8),
                      ),
                      _buildDivider(),
                      _buildMetricItem(
                        label: 'PACE',
                        value: _formatPace(distanceMeters, durationSeconds),
                        color: const Color(0xFFFBBF24),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFF1E293B), height: 1),
                  const SizedBox(height: 12),

                  // Action Buttons: Pause/Resume + Finish Trip
                  Row(
                    children: [
                      // Pause / Resume Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isPaused ? onResume : onPause,
                          icon: Icon(
                            isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            size: 20,
                          ),
                          label: Text(
                            isPaused ? 'RESUME' : 'PAUSE',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPaused
                                ? const Color(0xFF00E676)
                                : const Color(0xFF1E293B),
                            foregroundColor: isPaused
                                ? const Color(0xFF0B0F12)
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Finish Trip Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onFinish,
                          icon: const Icon(Icons.stop_rounded, size: 20),
                          label: const Text(
                            'FINISH TRIP',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0xFF1E293B),
    );
  }

  Widget _buildHeaderButton({
    Key? key,
    required VoidCallback onPressed,
    required String tooltip,
    required IconData icon,
    required Color foregroundColor,
    Widget? child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        key: key,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xE60B0F12),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF334155), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Center(
              child: child ?? Icon(icon, size: 18, color: foregroundColor),
            ),
          ),
        ),
      ),
    );
  }
}
