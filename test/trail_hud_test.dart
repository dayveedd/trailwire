import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/core/database/models/trail_route.dart';
import 'package:trailwire/features/map/presentation/trail_hud.dart';
import 'package:trailwire/features/tracking/models/app_mode.dart';

void main() {
  testWidgets('TrailHud renders metrics and responds to actions', (WidgetTester tester) async {
    bool paused = false;
    bool finished = false;
    bool marked = false;

    final route = TrailRoute()
      ..routeId = 'test-route'
      ..name = 'Yosemite Falls'
      ..startTime = DateTime.now()
      ..durationSeconds = 3665 // 01:01:05
      ..totalDistanceMeters = 5420.0 // 5.42 km
      ..totalElevationGainMeters = 420.0
      ..status = 'active';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrailHud(
            activeRoute: route,
            currentElevationMeters: 1200.0,
            currentSpeedMps: 1.4,
            isPaused: false,
            onPause: () => paused = true,
            onResume: () {},
            onFinish: () => finished = true,
            onMarkWaypoint: () => marked = true,
          ),
        ),
      ),
    );

    // Verify metrics formatting
    expect(find.text('01:01:05'), findsOneWidget);
    expect(find.text('5.42 km'), findsOneWidget);
    expect(find.text('+420 m'), findsOneWidget);
    expect(find.text('LIVE RECORDING'), findsOneWidget);

    // Tap PAUSE
    await tester.tap(find.text('PAUSE'));
    await tester.pump();
    expect(paused, isTrue);

    // Tap FINISH TRIP
    await tester.tap(find.text('FINISH TRIP'));
    await tester.pump();
    expect(finished, isTrue);

    // Tap MARK PIN
    await tester.tap(find.text('MARK PIN'));
    await tester.pump();
    expect(marked, isTrue);
  });

  testWidgets('TrailHud Basecamp Mode renders tool column and Start Trip button without telemetry', (WidgetTester tester) async {
    bool synced = false;
    bool downloaded = false;
    bool toggledStyle = false;
    bool recentered = false;
    bool startedTrip = false;

    bool openedAccount = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrailHud(
            mode: AppMode.basecamp,
            activeRoute: null,
            onStartTrip: () => startedTrip = true,
            onOpenAccount: () => openedAccount = true,
            onPause: () {},
            onResume: () {},
            onFinish: () {},
            onMarkWaypoint: () {},
            onSync: () => synced = true,
            onDownloadOffline: () => downloaded = true,
            onToggleMapStyle: () => toggledStyle = true,
            onRecenter: () => recentered = true,
          ),
        ),
      ),
    );

    // Verify Basecamp brand badge, account button, and tools exist
    expect(find.text('BASECAMP'), findsOneWidget);
    expect(find.byKey(const ValueKey('account_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('toggle_style_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('offline_pack_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('cloud_sync_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('recenter_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('start_trip_btn')), findsOneWidget);

    // Verify telemetry HUD, FAB, and live pills are HIDDEN
    expect(find.text('TIME'), findsNothing);
    expect(find.text('DISTANCE'), findsNothing);
    expect(find.byKey(const ValueKey('waypoint_fab')), findsNothing);
    expect(find.text('LIVE RECORDING'), findsNothing);
    expect(find.text('TRACKING PAUSED'), findsNothing);

    // Tap account button
    await tester.tap(find.byKey(const ValueKey('account_btn')));
    expect(openedAccount, isTrue);

    // Tap each button
    await tester.tap(find.byKey(const ValueKey('toggle_style_btn')));
    expect(toggledStyle, isTrue);

    await tester.tap(find.byKey(const ValueKey('offline_pack_btn')));
    expect(downloaded, isTrue);

    await tester.tap(find.byKey(const ValueKey('cloud_sync_btn')));
    expect(synced, isTrue);

    await tester.tap(find.byKey(const ValueKey('recenter_btn')));
    expect(recentered, isTrue);

    await tester.tap(find.byKey(const ValueKey('start_trip_btn')));
    expect(startedTrip, isTrue);
  });

  testWidgets('TrailHud Trail Mode hides tools and shows telemetry HUD and Mark Pin FAB', (WidgetTester tester) async {
    bool armedSosTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrailHud(
            mode: AppMode.activeTracking,
            activeRoute: null,
            isSosArmed: true,
            onArmSos: () => armedSosTapped = true,
            onPause: () {},
            onResume: () {},
            onFinish: () {},
            onMarkWaypoint: () {},
            onSync: () {},
            onDownloadOffline: () {},
            onToggleMapStyle: () {},
            onRecenter: () {},
          ),
        ),
      ),
    );

    // Basecamp tools and Start Trip button must be hidden
    expect(find.byKey(const ValueKey('start_trip_btn')), findsNothing);
    expect(find.byKey(const ValueKey('toggle_style_btn')), findsNothing);
    expect(find.byKey(const ValueKey('offline_pack_btn')), findsNothing);
    expect(find.byKey(const ValueKey('cloud_sync_btn')), findsNothing);

    // Trail Mode telemetry HUD, SOS shield, and FAB must be visible
    expect(find.byKey(const ValueKey('waypoint_fab')), findsOneWidget);
    expect(find.byKey(const ValueKey('sos_trip_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('recenter_btn')), findsOneWidget);
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('DISTANCE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sos_trip_btn')));
    expect(armedSosTapped, isTrue);
  });

  testWidgets('TrailHud does not overflow on narrow mobile screens (375px width)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrailHud(
            mode: AppMode.activeTracking,
            activeRoute: null,
            isPaused: true,
            isSosArmed: true,
            isSyncing: true,
            onPause: () {},
            onResume: () {},
            onFinish: () {},
            onMarkWaypoint: () {},
            onSync: () {},
            onDownloadOffline: () {},
            onToggleMapStyle: () {},
            onArmSos: () {},
            onRecenter: () {},
          ),
        ),
      ),
    );

    final err = tester.takeException();
    expect(err, isNull);
    expect(find.text('TRACKING PAUSED'), findsOneWidget);
  });
}
