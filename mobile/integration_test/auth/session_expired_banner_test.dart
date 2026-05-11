// ABOUTME: E2E test for session expired banner "Sign in" navigation flow
// ABOUTME: Verifies tapping "Sign in" on expired session banner reaches login
// ABOUTME: options screen instead of bouncing to home feed.
// ABOUTME: Requires: local Docker stack (mise run local_up)

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  group('Session Expired Banner', () {
    patrolTest(
      'tapping Sign in navigates to login options instead of bouncing home',
      ($) async {
        // Phase 1 of divinevideo/divine-mobile#3359 disabled the BYOK
        // identity-preservation flow this test depends on: the OAuth
        // flow no longer transmits the local nsec, so the server-issued
        // pubkey diverges from the locally generated one and the
        // expired-session setup the test relied on cannot be staged.
        //
        // Restore the body once divinevideo/keycast#197 ships the
        // proof-of-possession contract and Phase 2 lands the new BYOK
        // preservation path. The pre-skip body lives in commit feb110b4f.
        markTestSkipped(
          'Pending Phase 2 of divinevideo/divine-mobile#3359 — BYOK '
          'identity preservation requires server-side proof-of-possession.',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
