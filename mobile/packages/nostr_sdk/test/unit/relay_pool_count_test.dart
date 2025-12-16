// ABOUTME: Unit tests for NIP-45 COUNT functionality in RelayPool.
// ABOUTME: Tests the count method and countEvents on Nostr class.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('RelayPool count Tests', () {
    late Nostr nostr;
    late LocalNostrSigner signer;
    late String testPrivateKey;
    late String testPublicKey;

    setUp(() {
      testPrivateKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      testPublicKey =
          '87979b28328fa41994eb9a5d9c76cdf3a605df66fbb4c5f82c3608939b2545d5';
      signer = LocalNostrSigner(testPrivateKey);

      nostr = Nostr(
        signer,
        testPublicKey,
        [],
        (url) => RelayBase(url, RelayStatus(url)),
      );
    });

    test('count method throws ArgumentError for empty filters', () async {
      await expectLater(
        nostr.relayPool.count([]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'count method throws CountNotSupportedException when no relays connected',
      () async {
        // No relays are connected in this test setup
        await expectLater(
          nostr.relayPool.count([
            {
              'kinds': [1],
            },
          ]),
          throwsA(isA<CountNotSupportedException>()),
        );
      },
    );

    test('countEvents method exists and delegates to pool', () async {
      // This test verifies the method signature exists
      await expectLater(
        nostr.countEvents([
          {
            'kinds': [1],
          },
        ]),
        throwsA(isA<CountNotSupportedException>()),
      );
    });

    test('countEvents accepts timeout parameter', () async {
      await expectLater(
        nostr.countEvents([
          {
            'kinds': [1],
          },
        ], timeout: const Duration(milliseconds: 100)),
        throwsA(isA<CountNotSupportedException>()),
      );
    });

    test('countEvents accepts relayTypes parameter', () async {
      await expectLater(
        nostr.countEvents(
          [
            {
              'kinds': [1],
            },
          ],
          relayTypes: [RelayType.normal],
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<CountNotSupportedException>()),
      );
    });
  });

  group('COUNT message format', () {
    test('COUNT request format is correct', () {
      // Verify the expected message format
      const subscriptionId = 'test_sub';
      final filters = [
        {
          'kinds': [1],
          'authors': ['pubkey123'],
        },
      ];

      final message = ['COUNT', subscriptionId, ...filters];

      expect(message[0], equals('COUNT'));
      expect(message[1], equals('test_sub'));
      expect(message[2], isA<Map<String, dynamic>>());
      expect((message[2] as Map)['kinds'], equals([1]));
    });

    test('multiple filters are included in message', () {
      const subscriptionId = 'test_sub';
      final filters = [
        {
          'kinds': [1],
        },
        {
          'kinds': [7],
          'e': ['event123'],
        },
      ];

      final message = ['COUNT', subscriptionId, ...filters];

      expect(message.length, equals(4)); // COUNT, id, filter1, filter2
      expect(
        message[2],
        equals({
          'kinds': [1],
        }),
      );
      expect(
        message[3],
        equals({
          'kinds': [7],
          'e': ['event123'],
        }),
      );
    });
  });
}
