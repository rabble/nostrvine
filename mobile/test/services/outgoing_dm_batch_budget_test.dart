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

    test('retry guard outlives the batch send backstop', () {
      expect(
        OutgoingDmRetryService.interruptedMinAge,
        greaterThan(DmBatchSendBudget.messagePublishTimeout),
      );
    });
  });
}
