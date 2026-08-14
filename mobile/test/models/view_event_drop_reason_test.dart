// ABOUTME: Tests the reportability policy for kind-22236 view-event drops.
// ABOUTME: Structural drops must alarm; expected skips must stay silent.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/view_event_drop_reason.dart';

void main() {
  group(ViewEventDropReason, () {
    test('expected skips are not structural', () {
      expect(ViewEventDropReason.notAuthenticated.isStructural, isFalse);
      expect(ViewEventDropReason.nonAddressableVideoKind.isStructural, isFalse);
      expect(ViewEventDropReason.relayRejected.isStructural, isFalse);
    });

    test('failures to build a publishable event are structural', () {
      expect(ViewEventDropReason.missingAddressableDTag.isStructural, isTrue);
      expect(ViewEventDropReason.signingFailed.isStructural, isTrue);
      expect(ViewEventDropReason.unexpectedError.isStructural, isTrue);
    });

    test('an inverted watch range is structural, not an expected skip', () {
      expect(ViewEventDropReason.invalidWatchRange.isStructural, isTrue);
    });

    test('every reason states its reportability', () {
      for (final reason in ViewEventDropReason.values) {
        expect(
          () => reason.isStructural,
          returnsNormally,
          reason: '$reason must declare whether it is a defect',
        );
      }
    });
  });

  group(ViewEventInvariantException, () {
    test('names the reason without leaking viewer identity', () {
      const exception = ViewEventInvariantException(
        ViewEventDropReason.missingAddressableDTag,
      );

      expect(exception.toString(), contains('missingAddressableDTag'));
      expect(exception.toString(), isNot(contains('npub1')));
      expect(exception.toString(), isNot(contains('nsec1')));
    });
  });
}
