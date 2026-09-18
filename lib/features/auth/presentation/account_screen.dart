import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/isar_service.dart';
import '../../../core/database/models/trail_route.dart';
import '../../../core/database/models/waypoint.dart';
import '../../export/services/gpx_service.dart';
import '../../sync/services/sync_service.dart';
import '../../tracking/services/location_service.dart';
import '../services/auth_service.dart';
import 'value_gate_modal.dart';

class AccountScreen extends StatefulWidget {
  final AuthService? authService;
  final IsarService? isarService;
  final LocationService? locationService;
  final GpxService? gpxService;
  final SyncService? syncService;

  const AccountScreen({
    super.key,
    this.authService,
    this.isarService,
    this.locationService,
    this.gpxService,
    this.syncService,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with SingleTickerProviderStateMixin {
  late final AuthService _authService;
  late final IsarService _isarService;
  late final LocationService _locationService;
  late final GpxService _gpxService;
  late final SyncService _syncService;

  late TabController _tabController;

  bool _isLoading = true;
  String _locationStatus = 'Checking...';
  List<TrailRoute> _completedRoutes = [];
  List<Waypoint> _waypoints = [];
  int _unsyncedCount = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _isarService = widget.isarService ?? IsarService();
    _locationService = widget.locationService ?? LocationService();
    _gpxService = widget.gpxService ?? GpxService();
    _syncService = widget.syncService ?? SyncService();

    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final locStatus = await _locationService.getAuthorizationStatus();
      final routes = await _isarService.getAllCompletedRoutes();
      final waypoints = await _isarService.getAllWaypoints();
      final unsyncedRoutes = await _isarService.getUnsyncedRoutes();
      final unsyncedWaypoints = await _isarService.getUnsyncedWaypoints();

      if (mounted) {
        setState(() {
          _locationStatus = locStatus;
          _completedRoutes = routes;
          _waypoints = waypoints;
          _unsyncedCount = unsyncedRoutes.length + unsyncedWaypoints.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'water':
        return const Color(0xFF38BDF8);
      case 'hazard':
        return const Color(0xFFEF4444);
      case 'viewpoint':
        return const Color(0xFFA855F7);
      case 'trailhead':
        return const Color(0xFF10B981);
      case 'camp':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'water':
        return Icons.water_drop_rounded;
      case 'hazard':
        return Icons.warning_amber_rounded;
      case 'viewpoint':
        return Icons.landscape_rounded;
      case 'trailhead':
        return Icons.flag_rounded;
      case 'camp':
      default:
        return Icons.cabin_rounded;
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Your offline treks and waypoints will remain safely stored on this device.',
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
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      await _authService.initializeGuestAuth();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out successfully. Switched to guest mode.')),
        );
        _loadData();
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account?', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete your account and remove any cloud-synced routes from the server. Local offline routes on this device will not be deleted.',
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
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.deleteAccount();
        await _authService.initializeGuestAuth();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account and cloud data deleted.')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete account: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleDeleteRoute(TrailRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${route.name}"?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will remove this recorded route and its telemetry from your local database.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _isarService.deleteRoute(route.routeId);
      _loadData();
    }
  }

  Future<void> _handleDeleteWaypoint(Waypoint waypoint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${waypoint.title}"?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This marker will be permanently removed from your saved waypoints.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _isarService.deleteWaypoint(waypoint.waypointId);
      _loadData();
    }
  }

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    final result = await _syncService.syncPendingData();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Sync completed! ${result.syncedRoutesCount} routes, ${result.syncedWaypointsCount} waypoints synced.'
                : 'Sync result: ${result.errorMessage ?? "Offline"}',
          ),
          backgroundColor: result.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isAnonymous = _authService.isAnonymous;
    final email = user?.email;
    final uid = user?.uid ?? 'offline_guest';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Account & Trail Activity',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: _isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                      )
                    : const Icon(Icons.sync_rounded, color: Color(0xFF10B981)),
                tooltip: 'Sync Cloud Data',
                onPressed: _isSyncing ? null : _triggerManualSync,
              ),
              if (_unsyncedCount > 0 && !_isSyncing)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_unsyncedCount',
                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF10B981),
              backgroundColor: const Color(0xFF0F172A),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Identity & Profile Card
                  _buildProfileCard(isAnonymous: isAnonymous, email: email, uid: uid),
                  const SizedBox(height: 16),

                  // 2. Location Permission & Battery Heuristics Card
                  _buildLocationCard(),
                  const SizedBox(height: 16),

                  // 3. Tab Bar for Completed Treks vs Pinned Markers
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF10B981),
                      indicatorWeight: 3,
                      labelColor: const Color(0xFF10B981),
                      unselectedLabelColor: const Color(0xFF94A3B8),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.route_rounded, size: 18),
                          text: 'Completed Treks (${_completedRoutes.length})',
                        ),
                        Tab(
                          icon: const Icon(Icons.place_rounded, size: 18),
                          text: 'Pinned Markers (${_waypoints.length})',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Tab Bar Content
                  SizedBox(
                    height: 480,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTreksList(),
                        _buildMarkersList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard({required bool isAnonymous, String? email, required String uid}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isAnonymous ? const Color(0xFF334155) : const Color(0xFF064E3B),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isAnonymous ? const Color(0xFF64748B) : const Color(0xFF10B981),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isAnonymous ? Icons.person_outline_rounded : Icons.verified_user_rounded,
                  color: isAnonymous ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isAnonymous ? 'Guest Explorer' : (email ?? 'Trailwire Explorer'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAnonymous
                                ? const Color(0x3364748B)
                                : const Color(0x3310B981),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isAnonymous ? 'OFFLINE' : 'SYNCED',
                            style: TextStyle(
                              color: isAnonymous ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: uid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User ID copied to clipboard')),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            'UID: ${uid.length > 16 ? "${uid.substring(0, 16)}..." : uid}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isAnonymous
                ? 'You are browsing as an offline guest. Link an email or Apple/Google account to sync your trails across devices without losing your local treks.'
                : 'Your profile is securely linked. Completed treks and markers sync to the cloud when connected.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (isAnonymous)
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('link_account_btn'),
                    onPressed: () async {
                      final result = await ValueGateModal.show(
                        context,
                        description: 'Link your permanent account to sync trails across devices.',
                      );
                      if (result == true) _loadData();
                    },
                    icon: const Icon(Icons.link_rounded, size: 16),
                    label: const Text('Link Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleSignOut,
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Sign Out', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _handleDeleteAccount,
                child: const Text('Delete Account', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final isAllowed = _locationStatus.toLowerCase().contains('always') ||
        _locationStatus.toLowerCase().contains('wheninuse');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isAllowed ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                    color: isAllowed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Location & Battery Status',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAllowed ? const Color(0x3310B981) : const Color(0x33F59E0B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _locationStatus,
                  style: TextStyle(
                    color: isAllowed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Trailwire runs an aggressive wilderness battery profile: 5.0m displacement filter and fitness activity classification to minimize GPS drain during multi-day expeditions.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _locationService.openAppSettings(),
              icon: const Icon(Icons.settings_rounded, size: 14, color: Color(0xFF38BDF8)),
              label: const Text('Device Settings', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreksList() {
    if (_completedRoutes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terrain_rounded, size: 48, color: const Color(0xFF334155)),
            const SizedBox(height: 12),
            const Text(
              'No Completed Treks',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Recorded trips will be listed here with GPX export.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _completedRoutes.length,
      itemBuilder: (ctx, index) {
        final route = _completedRoutes[index];
        final distanceStr = _formatDistance(route.totalDistanceMeters);
        final durationStr = _formatDuration(route.durationSeconds);
        final elevStr = '+${route.totalElevationGainMeters.toStringAsFixed(0)} m';
        final dateStr = '${route.startTime.month}/${route.startTime.day}/${route.startTime.year}';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF131D2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      route.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF10B981)),
                        tooltip: 'Export GPX',
                        onPressed: () => _gpxService.exportAndShareRoute(context: context, route: route),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF64748B)),
                        tooltip: 'Delete',
                        onPressed: () => _handleDeleteRoute(route),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                dateStr,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildMetricBadge(Icons.timer_outlined, durationStr),
                  const SizedBox(width: 8),
                  _buildMetricBadge(Icons.straighten_rounded, distanceStr),
                  const SizedBox(width: 8),
                  _buildMetricBadge(Icons.trending_up_rounded, elevStr),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarkersList() {
    if (_waypoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.place_outlined, size: 48, color: const Color(0xFF334155)),
            const SizedBox(height: 12),
            const Text(
              'No Pinned Markers',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pins marked during active trail mode appear here.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _waypoints.length,
      itemBuilder: (ctx, index) {
        final waypoint = _waypoints[index];
        final catColor = _getCategoryColor(waypoint.category);
        final catIcon = _getCategoryIcon(waypoint.category);
        final hasPhoto = waypoint.localPhotoPath != null &&
            File(waypoint.localPhotoPath!).existsSync();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF131D2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon / Photo Thumbnail
              if (hasPhoto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(waypoint.localPhotoPath!),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: catColor.withValues(alpha: 0.4)),
                  ),
                  child: Icon(catIcon, color: catColor, size: 22),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            waypoint.title,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF64748B)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _handleDeleteWaypoint(waypoint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(waypoint.category ?? "camp").toUpperCase()} • ${waypoint.latitude.toStringAsFixed(4)}, ${waypoint.longitude.toStringAsFixed(4)}',
                      style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    if (waypoint.notes != null && waypoint.notes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        waypoint.notes!,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF10B981)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
