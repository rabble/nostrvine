// ABOUTME: Regression test for localized copy usage in E2E navigation helpers
// ABOUTME: Prevents helpers from drifting back to hardcoded auth labels

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth navigation helpers resolve auth labels from l10n', () {
    final source = File(
      'integration_test/helpers/navigation_helpers.dart',
    ).readAsStringSync();

    expect(source, contains('lookupAppLocalizations'));
    expect(source, isNot(contains("'Create a new Divine account'")));
    expect(source, isNot(contains("'Sign in with an existing account'")));
    expect(source, isNot(contains("'Create account'")));
    expect(source, isNot(contains("'Sign in'")));
  });
}
