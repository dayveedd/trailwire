import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/features/auth/presentation/value_gate_modal.dart';

void main() {
  testWidgets('ValueGateModal renders value propositions and handles guest dismiss', (WidgetTester tester) async {
    bool? modalResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                modalResult = await ValueGateModal.show(
                  context,
                  title: 'Unlock Cloud Features',
                  description: 'Export GPX tracks and arm SOS safety switch.',
                );
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    );

    // Open modal
    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Verify modal header and perks are rendered
    expect(find.text('Unlock Cloud Features'), findsOneWidget);
    expect(find.text('Export GPX tracks and arm SOS safety switch.'), findsOneWidget);
    expect(find.text('Seamless Cloud Backup'), findsOneWidget);
    expect(find.text('SOS Dead Man\'s Switch'), findsOneWidget);
    expect(find.text('Full GPX & Telemetry Export'), findsOneWidget);

    // Verify Sign In Buttons
    expect(find.text('Sign in with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue Offline as Guest'), findsOneWidget);

    // Scroll to and tap "Continue Offline as Guest"
    final guestButton = find.text('Continue Offline as Guest');
    await tester.ensureVisible(guestButton);
    await tester.pumpAndSettle();
    await tester.tap(guestButton);
    await tester.pumpAndSettle();

    // Verify modal closed and returned false
    expect(modalResult, isFalse);
    expect(find.text('Unlock Cloud Features'), findsNothing);
  });
}
