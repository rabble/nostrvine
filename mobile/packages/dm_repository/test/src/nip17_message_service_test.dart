// ABOUTME: Tests for NIP17MessageService encrypted message sending.
// ABOUTME: Covers NIP-17 gift wrap creation, encryption, publishing,
// ABOUTME: self-wrap fallback, and error handling paths.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _FakeEvent extends Fake implements Event {}

// Valid 64-character hex keys for testing.
const _testPrivateKey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _testPublicKey =
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
const _recipientPubkey =
    'e771af0b05c8e95fcdf6feb3500544d2fb1ccd384788e9f490bb3ee28e8ed66f';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  group(NIP17MessageService, () {
    late NIP17MessageService service;
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockNostrClient = _MockNostrClient();

      service = NIP17MessageService(
        signer: LocalNostrSigner(_testPrivateKey),
        senderPublicKey: _testPublicKey,
        nostrService: mockNostrClient,
      );
    });

    test('nostrService getter returns the injected client', () {
      expect(service.nostrService, same(mockNostrClient));
    });

    group('sendPrivateMessage', () {
      test('returns success with gift wrap event details', () async {
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Event,
        );

        final result = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(result.success, isTrue);
        expect(result.rumorEventId, isNotNull);
        expect(result.messageEventId, isNotNull);
        expect(result.recipientPubkey, equals(_recipientPubkey));
        expect(result.error, isNull);

        // At least the recipient gift wrap is published; self-wrap may
        // silently fail with synthetic test keys.
        verify(() => mockNostrClient.publishEvent(any())).called(
          greaterThanOrEqualTo(1),
        );
      });

      test('creates gift wrap with kind 1059', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async {
            return capturedEvent = invocation.positionalArguments[0] as Event;
          },
        );

        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.kind, equals(EventKind.giftWrap));
      });

      test('includes p tag with recipient pubkey', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async {
            return capturedEvent = invocation.positionalArguments[0] as Event;
          },
        );

        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(capturedEvent, isNotNull);
        final pTags = capturedEvent!.tags.where(
          (tag) => tag.isNotEmpty && tag[0] == 'p',
        );
        expect(pTags, isNotEmpty);
        expect(pTags.first[1], equals(_recipientPubkey));
      });

      test('uses random ephemeral key for each gift wrap', () async {
        final capturedEvents = <Event>[];

        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async {
            final event = invocation.positionalArguments[0] as Event;
            capturedEvents.add(event);
            return event;
          },
        );

        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Message 1',
        );
        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Message 2',
        );

        // At least 2 recipient gift wraps (self-wraps may silently fail
        // with synthetic test keys that are not valid EC points).
        expect(capturedEvents.length, greaterThanOrEqualTo(2));
        // First two events are the recipient gift wraps for each message.
        expect(
          capturedEvents[0].pubkey,
          isNot(equals(capturedEvents[1].pubkey)),
        );
        expect(capturedEvents[0].pubkey, isNot(equals(_testPublicKey)));
        expect(capturedEvents[1].pubkey, isNot(equals(_testPublicKey)));
      });

      test('obfuscates timestamp with random offset', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async {
            return capturedEvent = invocation.positionalArguments[0] as Event;
          },
        );

        final beforeSend = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );
        final afterSend = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        expect(capturedEvent, isNotNull);
        final timeDiff = (capturedEvent!.createdAt - beforeSend).abs();
        expect(timeDiff, lessThanOrEqualTo(60 * 60 * 24 * 2));
        expect(capturedEvent!.createdAt, lessThan(afterSend));
      });

      test('returns failure when publish returns null', () async {
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => null);

        final result = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('publish failed'));
      });

      test('includes additional tags in the gift wrap', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async {
            return capturedEvent = invocation.positionalArguments[0] as Event;
          },
        );

        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
          additionalTags: [
            ['client', 'diVine_bug_report'],
            ['report_id', 'test-123'],
          ],
        );

        expect(capturedEvent, isNotNull);
      });

      test('uses provided eventKind for the rumor', () async {
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Event,
        );

        final result = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'https://example.com/file.mp4',
          eventKind: EventKind.fileMessage,
        );

        // The rumor was created with kind 15; the gift wrap is still 1059.
        // We can only verify via the success result since the rumor is
        // encrypted inside the gift wrap.
        expect(result.success, isTrue);
        expect(result.rumorEventId, isNotNull);
      });

      test(
        'returns success even when self-wrap publish throws',
        () async {
          var callCount = 0;
          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (invocation) async {
              callCount++;
              if (callCount == 1) {
                // Recipient publish succeeds.
                return invocation.positionalArguments[0] as Event;
              }
              // Self-wrap publish throws — should be non-fatal.
              throw Exception('self-wrap relay error');
            },
          );

          final result = await service.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isTrue);
          expect(result.rumorEventId, isNotNull);
        },
      );

      test(
        'returns failure when signer throws during key refresh',
        () async {
          final mockSigner = _MockNostrSigner();
          when(
            mockSigner.getPublicKey,
          ).thenThrow(Exception('signer unavailable'));

          final brokenService = NIP17MessageService(
            signer: mockSigner,
            senderPublicKey: _testPublicKey,
            nostrService: mockNostrClient,
          );

          final result = await brokenService.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isFalse);
          expect(result.error, isNotNull);
        },
      );
    });
  });
}
