import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/features/safety/models/sos_trip.dart';
import 'package:trailwire/features/safety/presentation/sos_trip_setup_view.dart';

void main() {
  group('SosTrip Model Tests', () {
    test('serializes to and from Firestore map properly', () {
      final now = DateTime.utc(2026, 9, 14, 10, 0, 0);
      final returnTime = now.add(const Duration(hours: 4));

      final trip = SosTrip(
        tripId: 'trip-999',
        userId: 'user-abc',
        tripName: 'Desolation Wilderness Loop',
        routeIntent: 'Parked at Echo Lakes Chalet, heading towards Lake Aloha',
        emergencyContact: '+15551234567',
        expectedReturnTime: returnTime,
        status: 'ACTIVE',
        createdAt: now,
        lastKnownLatitude: 38.825,
        lastKnownLongitude: -120.045,
      );

      final map = trip.toFirestore();
      expect(map['tripId'], 'trip-999');
      expect(map['userId'], 'user-abc');
      expect(map['tripName'], 'Desolation Wilderness Loop');
      expect(map['routeIntent'], contains('Lake Aloha'));
      expect(map['emergencyContact'], '+15551234567');
      expect(map['status'], 'ACTIVE');
      expect(map['lastKnownLatitude'], 38.825);
      expect(map['lastKnownLongitude'], -120.045);
      expect(map['expectedReturnTime'], isA<Timestamp>());

      // Test fromFirestore
      final deserialized = SosTrip.fromFirestore(map, 'trip-999');
      expect(deserialized.tripId, 'trip-999');
      expect(deserialized.userId, 'user-abc');
      expect(deserialized.tripName, 'Desolation Wilderness Loop');
      expect(deserialized.expectedReturnTime.year, returnTime.year);
      expect(deserialized.status, 'ACTIVE');
    });
  });

  group('SosTripSetupView Widget Tests', () {
    testWidgets('renders setup form and validates required fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SosTripSetupView(
              initialTripName: 'Half Dome Cables',
            ),
          ),
        ),
      );

      expect(find.text('SOS Dead Man\'s Switch'), findsOneWidget);
      expect(find.text('ARM SOS TRIP & START HIKE'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Trip Name'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Emergency Contact Phone'), findsOneWidget);
      expect(find.text('EXPECTED RETURN TIME'), findsOneWidget);

      // Attempt to arm without filling emergency contact
      final armButton = find.text('ARM SOS TRIP & START HIKE');
      await tester.ensureVisible(armButton);
      await tester.pumpAndSettle();
      await tester.tap(armButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter an emergency contact phone number.'), findsOneWidget);
    });

    testWidgets('quick preset chips update the return deadline', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SosTripSetupView(),
          ),
        ),
      );

      // Scroll to chip and tap +8h
      final chipFinder = find.text('+8h');
      await tester.ensureVisible(chipFinder);
      await tester.pumpAndSettle();

      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('in 7h') == true || w.data?.contains('in 8h') == true),
        ),
        findsOneWidget,
      );
    });
  });
}
