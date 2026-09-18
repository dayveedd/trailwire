import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/features/auth/presentation/email_auth_form.dart';

void main() {
  group('EmailAuthForm Widget Tests', () {
    testWidgets('renders Link Email Account mode and validates empty inputs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmailAuthForm(initialMode: EmailAuthMode.link),
          ),
        ),
      );

      expect(find.text('Link Email Account'), findsOneWidget);
      expect(find.text('Save & Link Account'), findsOneWidget);
      expect(find.text('Already have an account?'), findsOneWidget);

      // Tap submit with empty fields
      await tester.tap(find.text('Save & Link Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email address.'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);
    });

    testWidgets('validates invalid email format and short passwords', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmailAuthForm(initialMode: EmailAuthMode.link),
          ),
        ),
      );

      // Enter invalid email and short password
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'notanemail');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), '123');

      await tester.tap(find.text('Save & Link Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);
    });

    testWidgets('switches between Link, Sign In, and Reset Password modes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmailAuthForm(initialMode: EmailAuthMode.link),
          ),
        ),
      );

      // Switch from Link to Sign In
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Sign In with Email'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);

      // Switch to Reset Password
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.text('Back to Sign In'), findsOneWidget);
    });
  });
}
