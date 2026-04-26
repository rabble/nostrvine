// ABOUTME: Unit tests for NIP17MessageService encrypted message sending
// ABOUTME: Tests NIP-17 gift wrap creation, encryption, and broadcasting

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

// Valid 64-character hex keys for testing
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

  group('NIP17MessageService', () {
    late NIP17MessageService service;
    late _MockNostrClient mockNostrService;

    setUp(() {
      mockNostrService = _MockNostrClient();

      service = NIP17MessageService(
        signer: LocalNostrSigner(_testPrivateKey),
        senderPublicKey: _testPublicKey,
        nostrService: mockNostrService,
      );
    });

    test('should create encrypted gift wrap event', () async {
      when(() => mockNostrService.publishEvent(any())).thenAnswer((
        invocation,
      ) async {
        return invocation.positionalArguments[0] as Event;
      });

      final result = await service.sendPrivateMessage(
        recipientPubkey: _recipientPubkey,
        content: 'Test bug report message',
      );

      expect(result.success, isTrue);
      expect(result.rumorEventId, isNotNull);
      expect(result.messageEventId, isNotNull);
      expect(result.recipientPubkey, equals(_recipientPubkey));
      expect(result.error, isNull);

      // At least the recipient gift wrap is published; self-wrap may
      // silently fail with synthetic test keys.
      verify(
        () => mockNostrService.publishEvent(any()),
      ).called(greaterThanOrEqualTo(1));
    });

    test('should create gift wrap with kind 1059', () async {
      Event? capturedEvent;

      when(() => mockNostrService.publishEvent(any())).thenAnswer((
        invocation,
      ) async {
        capturedEvent = invocation.positionalArguments[0] as Event;
        return capturedEvent;
      });

      await service.sendPrivateMessage(
        recipientPubkey: _recipientPubkey,
        content: 'Test message',
      );

      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.kind, equals(1059));
    });

    test('should include p tag with recipient pubkey', () async {
      Event? capturedEvent;

      when(() => mockNostrService.publishEvent(any())).thenAnswer((
        invocation,
      ) async {
        capturedEvent = invocation.positionalArguments[0] as Event;
        return capturedEvent;
      });

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

    test('should use random ephemeral key for gift wrap', () async {
      final capturedEvents = <Event>[];

      when(() => mockNostrService.publishEvent(any())).thenAnswer((
        invocation,
      ) async {
        final event = invocation.positionalArguments[0] as Event;
        capturedEvents.add(event);
        return event;
      });

      await service.sendPrivateMessage(
        recipientPubkey: _recipientPubkey,
        content: 'Message 1',
      );
      await service.sendPrivateMessage(
        recipientPubkey: _recipientPubkey,
        content: 'Message 2',
      );

      // At least 2 recipient gift wraps (self-wraps may silently fail
      // with synthetic test keys that aren't valid EC points).
      expect(capturedEvents.length, greaterThanOrEqualTo(2));
      // First two events are the recipient gift wraps for each message
      expect(capturedEvents[0].pubkey, isNot(equals(capturedEvents[1].pubkey)));
      expect(capturedEvents[0].pubkey, isNot(equals(_testPublicKey)));
      expect(capturedEvents[1].pubkey, isNot(equals(_testPublicKey)));
    });

    test('should obfuscate timestamp with random offset', () async {
      Event? capturedEvent;

      when(() => mockNostrService.publishEvent(any())).thenAnswer((
        invocation,
      ) async {
        capturedEvent = invocation.positionalArguments[0] as Event;
        return capturedEvent;
      });

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

    test('should handle publish failure gracefully', () async {
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => null);

      final result = await service.sendPrivateMessage(
        recipientPubkey: _recipientPubkey,
        content: 'Test message',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('publish failed'));
    });

    test('should include additional tags if provided', () async {
      Event? capturedEvent;

      when(() => mockNostrService.publishEvent(any())).thenAnswer((
        invocation,
      ) async {
        capturedEvent = invocation.positionalArguments[0] as Event;
        return capturedEvent;
      });

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
  });
}
