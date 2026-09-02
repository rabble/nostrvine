// ABOUTME: Runs the REAL NIP-59 wrap builder and real NIP-44 crypto to prove
// ABOUTME: maxDmRumorBytes actually sits below the ceiling NIP-44's u16 length
// ABOUTME: prefix imposes on NIP-17's double encryption (#7331).
//
// Every other test in this change mocks the wrap build. This one does not:
// without it, raising maxDmRumorBytes past the real ceiling would leave the
// whole suite green while every large send failed in production.

import 'dart:convert';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';

void main() {
  group('maxDmRumorBytes vs the real NIP-44 ceiling', () {
    late String senderSk;
    late String senderPk;
    late String recipientPk;

    setUp(() {
      senderSk = generatePrivateKey();
      senderPk = getPublicKey(senderSk);
      recipientPk = getPublicKey(generatePrivateKey());
    });

    Event rumorOf(int contentLength, {int extraRecipients = 0}) => Event(
      senderPk,
      EventKind.privateDirectMessage,
      [
        ['p', recipientPk],
        for (var i = 0; i < extraRecipients; i++)
          ['p', getPublicKey(generatePrivateKey())],
      ],
      'a' * contentLength,
    );

    int serializedBytes(Event rumor) =>
        utf8.encode(jsonEncode(rumor.toJson())).length;

    /// Builds the real kind-1059 wrap through the production isolate builder.
    /// Returns false when the NIP-44 chain refuses it.
    Future<bool> wrapBuilds(Event rumor) async {
      try {
        final wrap = await buildGiftWrapFromHex(
          senderPrivateKeyHex: senderSk,
          rumorJson: rumor.toJson(),
          receiverPublicKey: recipientPk,
        );
        return wrap != null;
      } on Object {
        return false;
      }
    }

    /// Largest content whose rumor still wraps, for a given recipient count.
    Future<int> maxContentFor(int extraRecipients) async {
      var lo = 1;
      var hi = 60000;
      while (lo < hi) {
        final mid = (lo + hi + 1) ~/ 2;
        if (await wrapBuilds(rumorOf(mid, extraRecipients: extraRecipients))) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      return lo;
    }

    test('a rumor at the limit really does build a gift wrap', () async {
      var content = maxDmRumorBytes;
      while (serializedBytes(rumorOf(content)) > maxDmRumorBytes) {
        content -= 16;
      }

      expect(
        serializedBytes(rumorOf(content)),
        lessThanOrEqualTo(maxDmRumorBytes),
      );
      expect(await wrapBuilds(rumorOf(content)), isTrue);
    });

    test('the ceiling is a property of the rumor, not of the body', () async {
      // This is why the guard measures the rumor: the usable BODY shrinks as
      // recipients are added, while the rumor ceiling does not move.
      final solo = await maxContentFor(0);
      final group = await maxContentFor(50);

      expect(
        group,
        lessThan(solo),
        reason: 'extra p tags must eat into the usable body',
      );
      expect(
        serializedBytes(rumorOf(group, extraRecipients: 50)),
        equals(serializedBytes(rumorOf(solo))),
        reason: 'both maxima must serialize to the same rumor ceiling',
      );
    });

    test('the guard sits below the measured ceiling', () async {
      final solo = await maxContentFor(0);
      final ceiling = serializedBytes(rumorOf(solo));

      // Measured, not derived: 40,969 bytes wraps and 40,970 does not.
      expect(ceiling, equals(40969));
      expect(await wrapBuilds(rumorOf(solo + 1)), isFalse);
      expect(
        maxDmRumorBytes,
        lessThan(ceiling),
        reason: 'the guard must sit below the real NIP-44 ceiling',
      );
    });
  });
}
