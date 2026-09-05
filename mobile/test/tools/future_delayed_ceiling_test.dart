// ABOUTME: Contract tests for the test-scoped Future.delayed numeric ceiling.
// ABOUTME: Shares detector and ratchet semantics with the production guard.

import 'package:flutter_test/flutter_test.dart';

import 'helpers/future_delayed_ceiling_test_harness.dart';

void main() {
  group('test-scoped guard', () {
    defineFutureDelayedCeilingTests(
      scriptName: 'check_future_delayed_ceiling.sh',
      baselineName: 'future_delayed_tests.txt',
      sourceDirectoryName: 'test',
      allowNoBaseVariable: 'FUTURE_DELAYED_CEILING_ALLOW_NO_BASE',
    );
  });
}
