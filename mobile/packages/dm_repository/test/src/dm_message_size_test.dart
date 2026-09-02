// ABOUTME: Guards the pre-enqueue size refusal on DmRepository.sendMessage
// ABOUTME: (#7331): NIP-44's u16 length prefix caps what the NIP-17 double
// ABOUTME: encryption can carry, and the throw is deterministic, so an
// ABOUTME: oversized body must be refused BEFORE a retry-swept row exists.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNIP17MessageService extends Mock implements NIP17MessageService {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

class _MockOutgoingDmsDao extends Mock implements OutgoingDmsDao {}

class _FakeEvent extends Fake implements Event {}

class _FakeOutgoingDm extends Fake implements OutgoingDm {}

const _ownerPubkey =
    'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
const _recipientPubkey =
    'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
const _privateKey =
    'd4e5f6789012345678901234567890abcdef1234567890123456789012ab12c3';

void main() {
  group('$DmRepository oversized message refusal', () {
    late _MockNostrClient nostrClient;
    late _MockNIP17MessageService messageService;
    late _MockOutgoingDmsDao outgoingDao;

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(_FakeOutgoingDm());
      registerFallbackValue(Duration.zero);
    });

    DmRepository buildRepository() {
      return DmRepository(
        nostrClient: nostrClient,
        messageService: messageService,
        directMessagesDao: _MockDirectMessagesDao(),
        conversationsDao: _MockConversationsDao(),
        outgoingDmsDao: outgoingDao,
      )..setCredentials(
        userPubkey: _ownerPubkey,
        signer: LocalNostrSigner(_privateKey),
        messageService: messageService,
      );
    }

    setUp(() {
      nostrClient = _MockNostrClient();
      messageService = _MockNIP17MessageService();
      outgoingDao = _MockOutgoingDmsDao();

      when(() => nostrClient.connectedRelayCount).thenReturn(2);
      when(() => nostrClient.configuredRelayCount).thenReturn(2);
      when(() => outgoingDao.enqueue(any())).thenAnswer((_) async {});
      // The send-policy gate sits immediately AFTER the size guard and also
      // refuses before enqueuing. Stubbed to refuse so a body that clears the
      // size guard stops there with a distinguishable result, instead of
      // running the whole publish path.
      when(
        () => messageService.canSendTo(any()),
      ).thenAnswer((_) async => false);
    });

    test('refuses a body over the byte limit with a tooLong result', () async {
      final repository = buildRepository();

      final result = await repository.sendMessage(
        recipientPubkey: _recipientPubkey,
        content: 'a' * (maxDmMessageContentBytes + 1),
      );

      expect(result.success, isFalse);
      expect(result.tooLong, isTrue);
      expect(result.blocked, isFalse);
      expect(result.retryablePending, isFalse);
    });

    test('leaves no queue row for the retry sweep to re-drive', () async {
      // The whole point of refusing before the enqueue: a hard-failed row is
      // re-driven by OutgoingDmRetryService.sweep() on every foreground and
      // reconnect, and an oversized send fails identically every time, so a
      // row here would burn the retry budget on work that cannot succeed.
      final repository = buildRepository();

      final result = await repository.sendMessage(
        recipientPubkey: _recipientPubkey,
        content: 'a' * (maxDmMessageContentBytes + 1),
      );

      expect(result.queuedRumorId, isNull);
      verifyNever(() => outgoingDao.enqueue(any()));
    });

    test('never reaches the signer or the wrap build', () async {
      final repository = buildRepository();

      final result = await repository.sendMessage(
        recipientPubkey: _recipientPubkey,
        content: 'a' * (maxDmMessageContentBytes + 1),
      );
      expect(result.tooLong, isTrue);

      verifyNever(
        () => messageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          targetRelays: any(named: 'targetRelays'),
          selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
          recipientWrapBuildTimeout: any(named: 'recipientWrapBuildTimeout'),
          selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
        ),
      );
    });

    test('measures UTF-8 bytes, not characters', () async {
      // A character count cannot bound this: '€' is one character and three
      // UTF-8 bytes, so a body well under any sane character limit can still
      // exceed the byte ceiling the NIP-44 chain actually imposes.
      final repository = buildRepository();
      final content = '€' * (maxDmMessageContentBytes ~/ 3 + 1);

      expect(content.length, lessThan(maxDmMessageContentBytes));

      final result = await repository.sendMessage(
        recipientPubkey: _recipientPubkey,
        content: content,
      );

      expect(result.tooLong, isTrue);
    });

    test('an oversized self-send reports the self-send refusal', () async {
      // Ordering matters: a note-to-self can never be delivered whatever its
      // size, so the more fundamental reason is the useful one to surface.
      final repository = buildRepository();

      final result = await repository.sendMessage(
        recipientPubkey: _ownerPubkey,
        content: 'a' * (maxDmMessageContentBytes + 1),
      );

      expect(result.success, isFalse);
      expect(result.tooLong, isFalse);
      expect(result.error, contains('its own sender'));
    });

    test('admits a body exactly at the byte limit', () async {
      // Boundary in the other direction — the guard must not be off by one.
      final repository = buildRepository();

      final result = await repository.sendMessage(
        recipientPubkey: _recipientPubkey,
        content: 'a' * maxDmMessageContentBytes,
      );

      // Stops at the send-policy gate, not the size guard — which is the
      // proof the size guard admitted it.
      expect(
        result.tooLong,
        isFalse,
        reason: 'a body exactly at the limit must pass the size guard',
      );
      expect(result.blocked, isTrue);
    });
  });
}
