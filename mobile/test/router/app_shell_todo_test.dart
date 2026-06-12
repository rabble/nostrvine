// ABOUTME: Static-source guard for AppShell transitional TODO hygiene.
// ABOUTME: Prevents closed tracking issues from remaining as removal plans.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppShell does not reference closed migration issue #3339', () {
    final source = File('lib/router/app_shell.dart').readAsStringSync();

    expect(
      source,
      isNot(contains('TODO(#3339)')),
      reason:
          '#3339 is closed. Transitional TODOs must either be removed '
          'or point at an open tracking issue.',
    );
  });
}
