// ABOUTME: Contract tests for the production Future.delayed numeric ceiling.
// ABOUTME: Shares detector and ratchet semantics with the test-scoped guard.

import 'package:flutter_test/flutter_test.dart';

import 'helpers/future_delayed_ceiling_test_harness.dart';

void main() {
  group('production guard', () {
    defineFutureDelayedCeilingTests(
      scriptName: 'check_future_delayed_production_ceiling.sh',
      baselineName: 'future_delayed_production_counts.txt',
      sourceDirectoryName: 'lib',
      allowNoBaseVariable: 'FUTURE_DELAYED_PROD_CEILING_ALLOW_NO_BASE',
    );
  });
}
