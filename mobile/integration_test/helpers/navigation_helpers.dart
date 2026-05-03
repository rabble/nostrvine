// ABOUTME: Navigation helpers for E2E integration tests
// ABOUTME: Reusable UI interactions for welcome screen, auth flows, registration

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Navigate from the welcome screen to the create account screen.
///
/// The welcome screen has a passive terms notice — no checkboxes needed.
/// Taps "Create a new Divine account" to reach the registration screen.
/// Waits for the invite guard to resolve and the form to appear.
Future<void> navigateToCreateAccount(WidgetTester tester) async {
  final createButton = find.text('Create a new Divine account');
  expect(
    createButton,
    findsOneWidget,
    reason: 'Welcome screen should show "Create a new Divine account"',
  );
  await tester.tap(createButton);
  await tester.pumpAndSettle(const Duration(seconds: 1));

  // Wait for the invite guard to resolve and show the create account form.
  // The InviteProtectedCreateAccountScreen fetches config asynchronously.
  final foundForm = await waitForWidget(
    tester,
    find.byType(DivineAuthTextField),
    maxSeconds: 20,
  );
  if (!foundForm) {
    fail(
      'Create account form did not appear within 20s. '
      'The invite guard may have redirected to the invite gate screen. '
      'Ensure the invite server returns OnboardingMode.open for LOCAL env.',
    );
  }
}

/// Navigate from the welcome screen to the login options screen.
///
/// Taps "Sign in with a different account" to reach the sign-in screen.
Future<void> navigateToLoginOptions(WidgetTester tester) async {
  final signInButton = find.text('Sign in with a different account');
  expect(
    signInButton,
    findsOneWidget,
    reason: 'Welcome screen should show "Sign in with a different account"',
  );
  await tester.tap(signInButton);
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

/// Fill the create account form and submit.
///
/// Expects to be on the CreateAccountScreen. Fills email and password,
/// dismisses keyboard, and taps "Create account".
Future<void> registerNewUser(
  WidgetTester tester,
  String email,
  String password, {
  String? confirmPassword,
}) async {
  // CreateAccountScreen uses AuthFormScaffold with email, password, and
  // confirm password fields.
  final textFields = find.byType(DivineAuthTextField);
  expect(
    textFields,
    findsNWidgets(3),
    reason:
        'Create account screen should show email, password, and confirmation',
  );

  await tester.enterText(textFields.at(0), email);
  await tester.pumpAndSettle();
  await tester.enterText(textFields.at(1), password);
  await tester.pumpAndSettle();
  await tester.enterText(textFields.at(2), confirmPassword ?? password);
  await tester.pumpAndSettle();

  // Dismiss keyboard
  await tester.tapAt(const Offset(10, 100));
  await tester.pumpAndSettle();

  // Submit — use widgetWithText to avoid matching the page title
  final submitButton = find.widgetWithText(
    DivineButton,
    'Create account',
  );
  expect(submitButton, findsOneWidget);
  await tester.tap(submitButton);
}

/// Fill email and password on the login screen and submit.
///
/// Expects to be on the LoginOptionsScreen (2 fields: email, password).
Future<void> loginWithCredentials(
  WidgetTester tester,
  String email,
  String password,
) async {
  final textFields = find.byType(DivineAuthTextField);
  expect(
    textFields,
    findsNWidgets(2),
    reason: 'Login screen should show email and password fields',
  );

  await tester.enterText(textFields.at(0), email);
  await tester.pumpAndSettle();
  await tester.enterText(textFields.at(1), password);
  await tester.pumpAndSettle();

  // Dismiss keyboard
  await tester.tapAt(const Offset(10, 100));
  await tester.pumpAndSettle();

  // Submit — use widgetWithText to avoid matching the page title
  final submitButton = find.widgetWithText(DivineButton, 'Sign in');
  expect(submitButton, findsOneWidget);
  await tester.tap(submitButton);
}

/// Wait for a widget with the given text to appear, using pump loops.
///
/// Cannot use pumpAndSettle when polling timers are active (e.g.
/// EmailVerificationCubit polls every 3s). Returns true if found.
///
/// Pumps every 250ms for faster detection (vs 1s). Total wait time
/// is still [maxSeconds].
Future<bool> waitForText(
  WidgetTester tester,
  String text, {
  int maxSeconds = 15,
}) async {
  final iterations = maxSeconds * 4; // 250ms per pump
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(text).evaluate().isNotEmpty) return true;
  }
  return false;
}

/// Wait for a widget with the given text to disappear, using pump loops.
///
/// Returns true if the text disappeared within the timeout.
/// Pumps every 250ms for faster detection.
Future<bool> waitForTextGone(
  WidgetTester tester,
  String text, {
  int maxSeconds = 30,
}) async {
  final iterations = maxSeconds * 4;
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(text).evaluate().isEmpty) return true;
  }
  return false;
}

/// Tap a bottom navigation tab by its semantic identifier.
///
/// Valid identifiers: 'home_tab', 'explore_tab', 'inbox_tab',
/// 'profile_tab'.
Future<void> tapBottomNavTab(
  WidgetTester tester,
  String semanticId,
) async {
  final tab = find.byWidgetPredicate(
    (widget) =>
        widget is Semantics && widget.properties.identifier == semanticId,
  );
  expect(
    tab,
    findsOneWidget,
    reason: 'Bottom nav should have tab with id "$semanticId"',
  );
  await tester.tap(tab);
  await tester.pump(const Duration(milliseconds: 500));
}

/// Tap a widget identified by its [Semantics.identifier].
///
/// Useful for action buttons (like_button, comments_button, etc.)
/// that have semantic IDs but no unique text labels.
/// Pumps every 250ms for faster detection.
Future<void> tapSemantic(
  WidgetTester tester,
  String semanticId, {
  int maxWaitSeconds = 10,
}) async {
  Finder finder() => find.byWidgetPredicate(
    (widget) =>
        widget is Semantics && widget.properties.identifier == semanticId,
  );

  final iterations = maxWaitSeconds * 4;
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder().evaluate().isNotEmpty) {
      await tester.tap(finder().first);
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
  }
  fail('Semantic widget "$semanticId" not found within ${maxWaitSeconds}s');
}

/// Wait for any widget matching [finder] to appear, using pump loops.
///
/// Returns true if found within [maxSeconds].
/// Pumps every 250ms for faster detection.
Future<bool> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  int maxSeconds = 15,
}) async {
  final iterations = maxSeconds * 4;
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}
