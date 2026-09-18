import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/core/database/isar_service.dart';
import 'package:trailwire/core/database/models/trail_route.dart';
import 'package:trailwire/core/database/models/waypoint.dart';
import 'package:trailwire/core/models/location_data.dart';
import 'package:trailwire/features/auth/presentation/account_screen.dart';
import 'package:trailwire/features/auth/services/auth_service.dart';
import 'package:trailwire/features/tracking/services/location_service.dart';

class MockLocationService implements LocationService {
  @override
  Stream<LocationData> get locationStream => const Stream.empty();

  @override
  Future<bool> startTracking({required String routeId, double distanceFilterMeters = 5.0}) async => true;

  @override
  Future<bool> pauseTracking() async => true;

  @override
  Future<bool> stopTracking() async => true;

  @override
  Future<bool> isTracking() async => false;

  @override
  Future<String> getTrackingState() async => 'stopped';

  @override
  Future<LocationData?> getCurrentLocation() async => null;

  @override
  Future<String> getAuthorizationStatus() async => 'authorizedAlways';

  @override
  Future<bool> openAppSettings() async => true;
}

class MockIsarService implements IsarService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<TrailRoute>> getAllCompletedRoutes() async => [];

  @override
  Future<List<Waypoint>> getAllWaypoints() async => [];

  @override
  Future<List<TrailRoute>> getUnsyncedRoutes() async => [];

  @override
  Future<List<Waypoint>> getUnsyncedWaypoints() async => [];
}

class MockAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  User? get currentUser => null;

  @override
  bool get isAnonymous => true;

  @override
  String? get currentUserId => 'mock_guest_uid_123';
}

void main() {
  testWidgets('AccountScreen renders profile, location status, and tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          authService: MockAuthService(),
          isarService: MockIsarService(),
          locationService: MockLocationService(),
        ),
      ),
    );

    // Allow async _loadData to resolve
    await tester.pumpAndSettle();

    // Verify AppBar
    expect(find.text('Account & Trail Activity'), findsOneWidget);

    // Verify Profile Section
    expect(find.text('Guest Explorer'), findsOneWidget);
    expect(find.byKey(const ValueKey('link_account_btn')), findsOneWidget);

    // Verify Location & Battery Card
    expect(find.text('Location & Battery Status'), findsOneWidget);
    expect(find.text('authorizedAlways'), findsOneWidget);

    // Verify Tabs
    expect(find.text('Completed Treks (0)'), findsOneWidget);
    expect(find.text('Pinned Markers (0)'), findsOneWidget);

    // Tap Pinned Markers Tab
    await tester.tap(find.text('Pinned Markers (0)'));
    await tester.pumpAndSettle();

    // Verify empty state for pinned markers
    expect(find.text('No Pinned Markers'), findsOneWidget);
  });
}
