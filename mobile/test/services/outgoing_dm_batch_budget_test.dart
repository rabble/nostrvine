// ABOUTME: Guards the app-level NIP-17 batch send and retry timing contract.
// ABOUTME: Pins dm_repository's restated bounds to Keycast's real constants.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/services/outgoing_dm_retry_service.dart';

void main() {
  group('timing budget contract', () {
    test('batch send budget covers its request plus the legacy fallback', () {
      expect(
        DmBatchSendBudget.recipientWrapBuild,
        KeycastRpc.defaultBatchRequestTimeout +
            KeycastRpc.defaultRequestTimeout * 2 +
            const Duration(seconds: 5),
      );
      expect(
        DmBatchSendBudget.chainWorstCase,
        lessThan(DmBatchSendBudget.messagePublishTimeout),
      );
    });

    test('retry guard covers resolution PLUS the whole backstop', () {
      // The load-bearing invariant, and the one the two `greaterThan` checks
      // beside it cannot express: a send can spend its inbox resolution AND
      // its full publish cap, and the sweep must not re-drive it in that
      // window or it publishes a concurrent duplicate of the same rumor.
      //
      // Stated as a sum rather than a literal so it tracks both bounds. The
      // one-sided checks stay green if the margin shrinks to a second; this
      // one does not.
      expect(
        OutgoingDmRetryService.interruptedMinAge,
        greaterThanOrEqualTo(
          DmSendBudget.inboxResolution +
              DmBatchSendBudget.messagePublishTimeout,
        ),
        reason:
            'a guard shorter than resolution + publish re-drives a send '
            'that is still in flight',
      );
    });

    test('the backstop covers the pre-wrap steps inside it', () {
      // The connectivity probe, the send-policy check and the pubkey refresh
      // run inside the cap. They used to be absent from chainWorstCase and so
      // spent its scheduling headroom instead (#7091).
      expect(DmSendBudget.preWrapSeconds, greaterThan(0));
      expect(
        DmBatchSendBudget.chainWorstCase,
        greaterThanOrEqualTo(
          const Duration(seconds: DmSendBudget.preWrapSeconds) +
              DmBatchSendBudget.recipientWrapBuild,
        ),
        reason:
            'the chain must account for the steps that precede the wrap '
            'build, not leave them to headroom',
      );
    });

    test('retry guard outlives the batch send backstop', () {
      expect(
        OutgoingDmRetryService.interruptedMinAge,
        greaterThan(DmBatchSendBudget.messagePublishTimeout),
      );
    });
  });
}
