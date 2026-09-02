// ABOUTME: Runs the REAL NIP-59 wrap builder and real NIP-44 crypto to prove
// ABOUTME: maxDmMessageContentBytes actually sits below the ceiling NIP-44's
// ABOUTME: u16 length prefix imposes on NIP-17's double encryption (#7331).
//
// Every other test in this change mocks the wrap build. This one does not:
// without it, raising maxDmMessageContentBytes past the real ceiling would
// leave the whole suite green while every large send failed in production.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';

void main() {
  group('maxDmMessageContentBytes vs the real NIP-44 ceiling', () {
    late String senderSk;
    late String senderPk;
    late String recipientPk;

    setUp(() {
      senderSk = generatePrivateKey();
      senderPk = getPublicKey(senderSk);
      recipientPk = getPublicKey(generatePrivateKey());
    });

    /// Builds the real kind-1059 wrap for a kind-14 rumor of [contentLength]
    /// bytes, through the production isolate builder. Returns false when the
    /// NIP-44 chain refuses it.
    Future<bool> wrapBuilds(
      int contentLength, {
      List<List<String>>? tags,
    }) async {
      final rumor = Event(
        senderPk,
        EventKind.privateDirectMessage,
        tags ??
            [
              ['p', recipientPk],
            ],
        'a' * contentLength,
      );
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

    test('a body at the limit really does build a gift wrap', () async {
      expect(await wrapBuilds(maxDmMessageContentBytes), isTrue);
    });

    test('the limit holds for a large group rumor too', () async {
      // The 1:1 ceiling is the best case. Every extra `p` tag enlarges the
      // sealed JSON and lowers the real ceiling, which is why the constant is
      // set well below the measured 1:1 maximum rather than at it.
      final manyRecipients = <List<String>>[
        for (var i = 0; i < 100; i++) ['p', getPublicKey(generatePrivateKey())],
      ];

      expect(
        await wrapBuilds(maxDmMessageContentBytes, tags: manyRecipients),
        isTrue,
      );
    });

    test('the NIP-44 ceiling this guards is real and not far above', () async {
      // Pins the thing the constant exists for. 40,683 bytes of content is the
      // first size that cannot be wrapped — measured, not derived — so a guard
      // above it would let the deterministic throw back through.
      expect(await wrapBuilds(40682), isTrue);
      expect(await wrapBuilds(40683), isFalse);
      expect(
        maxDmMessageContentBytes,
        lessThan(40683),
        reason: 'the guard must sit below the real NIP-44 ceiling',
      );
    });
  });
}
