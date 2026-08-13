// ABOUTME: Closes the Patrol/flutter_test race that fails the first test of a
// ABOUTME: bundle when the platform enables semantics mid-test.

import 'package:flutter/widgets.dart';

/// Pre-empts Flutter's platform semantics handler before `flutter_test`
/// snapshots the outstanding-`SemanticsHandle` count.
///
/// Call it as the first statement of a Patrol suite's `main()`.
///
/// `SemanticsBinding` installs `platformDispatcher.onSemanticsEnabledChanged`,
/// and that handler calls `ensureSemantics()` — creating a handle that is only
/// released when the platform disables semantics again. Under Patrol on
/// Android the platform enables semantics shortly after launch, because the
/// instrumentation's UiAutomation turns accessibility on. So that handle can
/// appear *during* the first test rather than before it.
///
/// `testWidgets` snapshots the handle count before running the body, and
/// `WidgetTester._endOfTestVerifications` fails the test when the count grew:
/// "A SemanticsHandle was active at the end of the test." The failure lands
/// after the body, so Patrol reports it to the native side with a null detail
/// — the JUnit side only shows `Dart test failed: <name>`.
///
/// `patrolTest` installs this exact no-op itself, but as the first statement of
/// the test *body*, which is after the snapshot. Calling it from `main()`
/// closes the window, because group declaration runs before any test body.
///
/// Semantics stay available inside tests: `patrolTest` defaults to
/// `semanticsEnabled: true`, so `testWidgets` still holds its own handle for
/// the duration of every test.
// TODO(#7260): Remove once Patrol installs its no-op handler during
// PatrolBinding initialization instead of in the test body.
void ignorePlatformSemanticsHandle() {
  WidgetsBinding.instance.platformDispatcher.onSemanticsEnabledChanged = () {};
}
