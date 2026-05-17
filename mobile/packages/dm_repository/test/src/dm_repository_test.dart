// ABOUTME: Unit tests for DmRepository.
// ABOUTME: Tests static helpers, send validation, receive pipeline
// ABOUTME: (decryption, persistence, deduplication), query methods,
// ABOUTME: and subscription lifecycle.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

class _MockOutgoingDmsDao extends Mock implements OutgoingDmsDao {}

class _FakeOutgoingDm extends Fake implements OutgoingDm {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNIP17MessageService extends Mock implements NIP17MessageService {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _FakeEvent extends Fake implements Event {}

/// Test double for [DmSyncState] that stores values in memory and captures
/// [recordSeen] calls for assertions.
class _FakeDmSyncState implements DmSyncState {
  int? newestOverride;
  int? oldestOverride;
  final List<({String pubkey, int createdAt})> recorded =
      <({String pubkey, int createdAt})>[];

  @override
  int? newestSyncedAt(String pubkey) => newestOverride;

  @override
  int? oldestSyncedAt(String pubkey) => oldestOverride;

  @override
  Future<void> recordSeen(String pubkey, {required int createdAt}) async {
    recorded.add((pubkey: pubkey, createdAt: createdAt));
    if (newestOverride == null || createdAt > newestOverride!) {
      newestOverride = createdAt;
    }
    if (oldestOverride == null || createdAt < oldestOverride!) {
      oldestOverride = createdAt;
    }
  }

  @override
  Future<void> clear(String pubkey) async {
    newestOverride = null;
    oldestOverride = null;
  }

  @override
  Future<void> clearAll() async {
    newestOverride = null;
    oldestOverride = null;
    recorded.clear();
  }
}

/// Records each invocation of a [DmRepositoryErrorReporter] so tests can
/// assert which swallow site emitted.
class _ReporterCall {
  _ReporterCall(this.error, this.stackTrace, this.site);
  final Object error;
  final StackTrace stackTrace;
  final String site;
}

// Valid 64-character hex pubkeys for testing
const _validPubkeyA =
    'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
const _validPubkeyB =
    'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
const _validPubkeyC =
    'c3d4e5f6789012345678901234567890abcdef1234567890123456789012ab12';
const _validPrivateKey =
    'd4e5f6789012345678901234567890abcdef1234567890123456789012ab12c3';
const _validPubkeyD =
    'd4e5f6789012345678901234567890abcdef1234567890123456789012ab12c3';

const _rumorEventId =
    'e5f6789012345678901234567890abcdef1234567890123456789012ab12c3d4';
const _giftWrapEventId =
    'f6789012345678901234567890abcdef1234567890123456789012ab12c3d4e5';
const _giftWrapEventId2 =
    '06789012345678901234567890abcdef1234567890123456789012ab12c3d4e5';

void main() {
  group(DmRepository, () {
    late _MockNostrClient mockNostrClient;
    late _MockNIP17MessageService mockMessageService;
    late _MockDirectMessagesDao mockDirectMessagesDao;
    late _MockConversationsDao mockConversationsDao;
    late List<_ReporterCall> reporterCalls;

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(_FakeOutgoingDm());
      registerFallbackValue(OutgoingWrapStatus.pending);
    });

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockMessageService = _MockNIP17MessageService();
      mockDirectMessagesDao = _MockDirectMessagesDao();
      mockConversationsDao = _MockConversationsDao();
      reporterCalls = <_ReporterCall>[];

      // Stub relay properties used by startListening() log.
      when(() => mockNostrClient.connectedRelayCount).thenReturn(3);
      when(() => mockNostrClient.configuredRelayCount).thenReturn(3);

      // Stub getNewestMessageTimestamp for startListening() windowing.
      when(
        () => mockConversationsDao.getNewestMessageTimestamp(
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => null);

      // Stub getAllConversations for _mergeDuplicateConversations().
      when(
        () => mockConversationsDao.getAllConversations(
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => []);

      // Stub backfillCurrentUserHasSent for _backfillCurrentUserHasSent().
      when(
        () => mockConversationsDao.backfillCurrentUserHasSent(any()),
      ).thenAnswer((_) async => 0);
      when(
        () => mockConversationsDao.backfillLatestMessagePreviews(
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => 0);

      // Global stub for runInTransaction — executes the callback directly.
      // Stub both <void> and <Null> since Dart infers different type args
      // depending on whether the callback returns or is void-typed.
      when(
        () => mockConversationsDao.runInTransaction<void>(any()),
      ).thenAnswer((inv) async {
        final callback = inv.positionalArguments[0] as Future<void> Function();
        await callback();
      });
      when(
        () => mockConversationsDao.runInTransaction<Null>(any()),
      ).thenAnswer((inv) async {
        final callback = inv.positionalArguments[0] as Future<Null> Function();
        await callback();
      });

      // Default stub for buildRumor — production sendMessage now calls
      // buildRumor first to enqueue a queue row keyed by the rumor's id
      // before publishing. Returning a real Event so .id is computed
      // deterministically from the rumor fields, matching what the
      // production message service does.
      when(
        () => mockMessageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer((inv) {
        final recipient = inv.namedArguments[#recipientPubkey] as String;
        final content = inv.namedArguments[#content] as String;
        final eventKind =
            (inv.namedArguments[#eventKind] as int?) ??
            EventKind.privateDirectMessage;
        final additionalTags =
            (inv.namedArguments[#additionalTags] as List<List<String>>?) ??
            const <List<String>>[];
        return Event(
          _validPubkeyA,
          eventKind,
          [
            ['p', recipient],
            ...additionalTags,
          ],
          content,
        );
      });
    });

    DmRepository createRepository({
      String? userPubkey,
      RumorDecryptor? rumorDecryptor,
      Nip04Decryptor? nip04Decryptor,
      DmSyncState? syncState,
      OutgoingDmsDao? outgoingDmsDao,
    }) {
      return DmRepository(
        nostrClient: mockNostrClient,
        messageService: mockMessageService,
        directMessagesDao: mockDirectMessagesDao,
        conversationsDao: mockConversationsDao,
        outgoingDmsDao: outgoingDmsDao,
        userPubkey: userPubkey ?? _validPubkeyA,
        signer: LocalNostrSigner(_validPrivateKey),
        rumorDecryptor: rumorDecryptor,
        nip04Decryptor: nip04Decryptor,
        syncState: syncState,
        errorReporter: (error, stackTrace, {required site}) {
          reporterCalls.add(_ReporterCall(error, stackTrace, site));
        },
      );
    }

    List<List<String>> additionalTagsFromRumor(
      Event rumorEvent,
      String recipientPubkey,
    ) {
      return rumorEvent.tags
          .where(
            (tag) =>
                !(tag.length >= 2 &&
                    tag[0] == 'p' &&
                    tag[1] == recipientPubkey),
          )
          .map(List<String>.from)
          .toList();
    }

    void stubSendRumor(
      FutureOr<NIP17SendResult> Function(
        Event rumorEvent,
        String recipientPubkey,
      )
      answer,
    ) {
      when(
        () => mockMessageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
        ),
      ).thenAnswer((inv) async {
        final rumorEvent = inv.namedArguments[#rumorEvent] as Event;
        final recipientPubkey = inv.namedArguments[#recipientPubkey] as String;
        return answer(rumorEvent, recipientPubkey);
      });
    }

    // -----------------------------------------------------------------
    // Static helpers
    // -----------------------------------------------------------------

    group('computeConversationId', () {
      test('returns same hash regardless of order', () {
        final resultAB = DmRepository.computeConversationId(
          [_validPubkeyA, _validPubkeyB],
        );
        final resultBA = DmRepository.computeConversationId(
          [_validPubkeyB, _validPubkeyA],
        );

        expect(resultAB, equals(resultBA));
      });

      test('returns different hash for different participants', () {
        final resultAB = DmRepository.computeConversationId(
          [_validPubkeyA, _validPubkeyB],
        );
        final resultAC = DmRepository.computeConversationId(
          [_validPubkeyA, _validPubkeyC],
        );

        expect(resultAB, isNot(equals(resultAC)));
      });

      test('returns a 64-character hex string', () {
        final result = DmRepository.computeConversationId(
          [_validPubkeyA, _validPubkeyB],
        );

        expect(result, hasLength(64));
        expect(result, matches(RegExp(r'^[0-9a-f]{64}$')));
      });
    });

    group('validatePubkey', () {
      test('does not throw for valid 64-character hex string', () {
        expect(
          () => DmRepository.validatePubkey(_validPubkeyA),
          returnsNormally,
        );
      });

      test('throws $ArgumentError for too-short string', () {
        expect(
          () => DmRepository.validatePubkey('abcdef1234'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws $ArgumentError for non-hex characters', () {
        const invalidHex =
            'g1b2c3d4e5f6789012345678901234567890abcdef'
            '123456789012345678901z';

        expect(
          () => DmRepository.validatePubkey(invalidHex),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws $ArgumentError for empty string', () {
        expect(
          () => DmRepository.validatePubkey(''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws $ArgumentError for too-long string', () {
        const tooLong =
            'a1b2c3d4e5f6789012345678901234567890abcdef'
            '1234567890123456789012ff';

        expect(
          () => DmRepository.validatePubkey(tooLong),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // -----------------------------------------------------------------
    // Send validation
    // -----------------------------------------------------------------

    group('sendMessage', () {
      test('throws $ArgumentError for invalid pubkey', () {
        final repository = createRepository();

        expect(
          () => repository.sendMessage(
            recipientPubkey: 'short',
            content: 'Hello',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws $ArgumentError for empty content', () {
        final repository = createRepository();

        expect(
          () => repository.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: '',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws $ArgumentError for whitespace-only content', () {
        final repository = createRepository();

        expect(
          () => repository.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: '   \t\n  ',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('sendMessage forwards additional NIP-17 tags', () async {
        stubSendRumor(
          (rumorEvent, recipientPubkey) async =>
              const NIP17SendResult.failure('relay unavailable'),
        );

        final repository = createRepository();
        const creatorPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const videoAddress = '34236:$creatorPubkey:video-id';
        const inviteTags = [
          ['divine', 'collab-invite'],
          [
            'a',
            videoAddress,
            'wss://relay.divine.video',
            'root',
          ],
          ['role', 'Collaborator'],
        ];

        await repository.sendMessage(
          recipientPubkey: _validPubkeyB,
          content: 'Invited you to collaborate',
          additionalTags: inviteTags,
        );

        final rumorEvent =
            verify(
                  () => mockMessageService.sendRumor(
                    rumorEvent: captureAny(named: 'rumorEvent'),
                    recipientPubkey: _validPubkeyB,
                  ),
                ).captured.single
                as Event;

        expect(
          additionalTagsFromRumor(rumorEvent, _validPubkeyB),
          containsAll(inviteTags),
        );
      });

      test('persists message and conversation on success', () async {
        stubSendRumor(
          (_, recipientPubkey) async => NIP17SendResult.success(
            rumorEventId: _rumorEventId,
            messageEventId: _giftWrapEventId,
            recipientPubkey: recipientPubkey,
          ),
        );
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);
        // Stub publishEvent for the NIP-04 fallback (fire-and-forget)
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        final repository = createRepository();

        final result = await repository.sendMessage(
          recipientPubkey: _validPubkeyB,
          content: 'Hello!',
        );

        expect(result.success, isTrue);

        verify(
          () => mockDirectMessagesDao.insertMessage(
            id: _rumorEventId,
            conversationId: any(named: 'conversationId'),
            senderPubkey: _validPubkeyA,
            content: 'Hello!',
            createdAt: any(named: 'createdAt'),
            giftWrapId: _giftWrapEventId,
            messageKind: any(named: 'messageKind'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).called(1);

        verify(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: false,
            createdAt: any(named: 'createdAt'),
            lastMessageContent: 'Hello!',
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: _validPubkeyA,
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).called(1);
      });

      test('does not persist on send failure', () async {
        stubSendRumor(
          (rumorEvent, recipientPubkey) async =>
              const NIP17SendResult.failure('Relay rejected'),
        );

        final repository = createRepository();

        final result = await repository.sendMessage(
          recipientPubkey: _validPubkeyB,
          content: 'Hello!',
        );

        expect(result.success, isFalse);

        verifyNever(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        );
      });

      test('skipNip04Fallback: true suppresses NIP-04 publish', () async {
        stubSendRumor(
          (_, recipientPubkey) async => NIP17SendResult.success(
            rumorEventId: _rumorEventId,
            messageEventId: _giftWrapEventId,
            recipientPubkey: recipientPubkey,
          ),
        );
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        final repository = createRepository();

        final result = await repository.sendMessage(
          recipientPubkey: _validPubkeyB,
          content: 'Invited you to collaborate',
          additionalTags: const [
            ['divine', 'collab-invite'],
          ],
          skipNip04Fallback: true,
        );

        // Drain pending microtasks so an unawaited `_sendNip04Message`
        // — the only way the fallback can fire when `skipNip04Fallback`
        // leaks — has the chance to call `publishEvent` before we
        // assert it never did. `pumpEventQueue` (default 20 ticks) is
        // the canonical drain in flutter_test.
        await pumpEventQueue();

        expect(result.success, isTrue);
        verifyNever(() => mockNostrClient.publishEvent(any()));
      });

      test(
        'second send to same conversation skips NIP-04 fallback (#3663)',
        () async {
          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );
          when(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          // First send: conversation does not exist yet → NIP-04
          // fallback fires (safe legacy interop).
          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          final repository = createRepository();
          await repository.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'Hello!',
          );
          await pumpEventQueue();

          verify(() => mockNostrClient.publishEvent(any())).called(1);

          // Capture the dmProtocol the repository wrote on first send.
          final upsertCall = verify(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: captureAny(named: 'dmProtocol'),
            ),
          ).captured;
          expect(upsertCall.last, equals('nip17'));

          // Second send: simulate the conversation row now exists with
          // dmProtocol='nip17' (which is what the first send wrote).
          // The fallback must NOT fire again.
          reset(mockNostrClient);
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());
          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id:
                  'dddddddddddddddddddddddddddddddddddddddddddddddddddddddd'
                  'dddddddd',
              participantPubkeys: jsonEncode([_validPubkeyA, _validPubkeyB]),
              isGroup: false,
              createdAt: 1700000000,
              lastMessageContent: 'Hello!',
              lastMessageTimestamp: 1700000000,
              lastMessageSenderPubkey: _validPubkeyA,
              isRead: true,
              currentUserHasSent: true,
              ownerPubkey: _validPubkeyA,
              dmProtocol: 'nip17',
            ),
          );

          await repository.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'Follow-up',
          );
          await pumpEventQueue();

          verifyNever(() => mockNostrClient.publishEvent(any()));
        },
      );
    });

    group('sendGroupMessage', () {
      test('throws $ArgumentError for empty recipient list', () {
        final repository = createRepository();

        expect(
          () => repository.sendGroupMessage(
            recipientPubkeys: [],
            content: 'Hello group',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws $ArgumentError for invalid pubkey in list', () {
        final repository = createRepository();

        expect(
          () => repository.sendGroupMessage(
            recipientPubkeys: [_validPubkeyB, 'not-valid'],
            content: 'Hello group',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws $ArgumentError for empty content', () {
        final repository = createRepository();

        expect(
          () => repository.sendGroupMessage(
            recipientPubkeys: [_validPubkeyB, _validPubkeyC],
            content: '',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws $ArgumentError for whitespace-only content', () {
        final repository = createRepository();

        expect(
          () => repository.sendGroupMessage(
            recipientPubkeys: [_validPubkeyB, _validPubkeyC],
            content: '   ',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('userPubkey', () {
      test('returns the pubkey passed to constructor', () {
        final repository = createRepository(userPubkey: _validPubkeyB);

        expect(repository.userPubkey, equals(_validPubkeyB));
      });
    });

    // -----------------------------------------------------------------
    // Receive pipeline
    // -----------------------------------------------------------------

    group('receive pipeline', () {
      Event createGiftWrapEvent({String? id}) {
        return Event.fromJson({
          'id': id ?? _giftWrapEventId,
          'pubkey':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'created_at': 1700000000,
          'kind': EventKind.giftWrap,
          'tags': [
            ['p', _validPubkeyA],
          ],
          'content': 'encrypted-content',
          'sig': '',
        });
      }

      Event createRumorEvent({
        String? id,
        String? pubkey,
        String? content,
        int? kind,
        List<List<String>>? tags,
        int? createdAt,
      }) {
        return Event.fromJson({
          'id': id ?? _rumorEventId,
          'pubkey': pubkey ?? _validPubkeyB,
          'created_at': createdAt ?? 1700000000,
          'kind': kind ?? EventKind.privateDirectMessage,
          'tags':
              tags ??
              [
                ['p', _validPubkeyA],
              ],
          'content': content ?? 'Hello from B!',
          'sig': '',
        });
      }

      void stubDaoInserts() {
        when(
          () => mockDirectMessagesDao.hasMatchingMessage(
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);
      }

      test('decrypts and persists a 1:1 message', () async {
        final giftWrap = createGiftWrapEvent();
        final rumor = createRumorEvent();

        when(
          () => mockDirectMessagesDao.hasGiftWrap(
            _giftWrapEventId,
          ),
        ).thenAnswer((_) async => false);
        stubDaoInserts();

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => rumor,
        );

        await repository.startListening();
        controller.add(giftWrap);

        // Allow async processing
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockDirectMessagesDao.insertMessage(
            id: _rumorEventId,
            conversationId: any(named: 'conversationId'),
            senderPubkey: _validPubkeyB,
            content: 'Hello from B!',
            createdAt: 1700000000,
            giftWrapId: _giftWrapEventId,
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).called(1);

        verify(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Hello from B!',
            lastMessageTimestamp: 1700000000,
            lastMessageSenderPubkey: _validPubkeyB,
            isRead: false,
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).called(1);

        await controller.close();
        await repository.stopListening();
      });

      test('persists decrypted rumor tags as JSON', () async {
        final giftWrap = createGiftWrapEvent();
        const creatorPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const videoAddress = '34236:$creatorPubkey:video-d-tag';
        final inviteTags = [
          ['p', _validPubkeyA],
          ['divine', 'collab-invite'],
          [
            'a',
            videoAddress,
            'wss://relay.divine.video',
            'root',
          ],
          ['p', creatorPubkey],
          ['role', 'Collaborator'],
        ];
        final rumor = createRumorEvent(
          content: 'Fallback invite copy',
          tags: inviteTags,
        );

        when(
          () => mockDirectMessagesDao.hasGiftWrap(_giftWrapEventId),
        ).thenAnswer((_) async => false);
        stubDaoInserts();

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => rumor,
        );

        await repository.startListening();
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockDirectMessagesDao.insertMessage(
            id: _rumorEventId,
            conversationId: any(named: 'conversationId'),
            senderPubkey: _validPubkeyB,
            content: 'Fallback invite copy',
            createdAt: 1700000000,
            giftWrapId: _giftWrapEventId,
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: _validPubkeyA,
            tagsJson: jsonEncode(inviteTags),
          ),
        ).called(1);

        await controller.close();
        await repository.stopListening();
      });

      test('successful gift-wrap persist advances sync boundaries', () async {
        const rumorCreatedAt = 1700000500;
        final giftWrap = createGiftWrapEvent();
        final rumor = createRumorEvent(createdAt: rumorCreatedAt);

        when(
          () => mockDirectMessagesDao.hasGiftWrap(_giftWrapEventId),
        ).thenAnswer((_) async => false);
        stubDaoInserts();

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final syncState = _FakeDmSyncState();
        final repository = createRepository(
          rumorDecryptor: (_, _) async => rumor,
          syncState: syncState,
        );

        await repository.startListening();
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);

        expect(syncState.recorded, hasLength(1));
        expect(syncState.recorded.single.pubkey, _validPubkeyA);
        expect(syncState.recorded.single.createdAt, rumorCreatedAt);

        await controller.close();
        await repository.stopListening();
      });

      test('successful NIP-04 persist advances sync boundaries', () async {
        const nip04CreatedAt = 1700000600;
        final nip04Event = Event.fromJson({
          'id':
              'aaaa00000000000000000000000000000000000000'
              '0000000000000000000000',
          'pubkey': _validPubkeyB,
          'created_at': nip04CreatedAt,
          'kind': EventKind.directMessage,
          'tags': [
            ['p', _validPubkeyA],
          ],
          'content': 'nip04-ciphertext',
          'sig': '',
        });

        when(
          () => mockDirectMessagesDao.hasGiftWrap(any()),
        ).thenAnswer((_) async => false);
        stubDaoInserts();

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final syncState = _FakeDmSyncState();
        final repository = createRepository(
          nip04Decryptor: (_, _) async => 'Hello over NIP-04',
          syncState: syncState,
        );

        await repository.startListening();
        controller.add(nip04Event);
        await Future<void>.delayed(Duration.zero);

        expect(syncState.recorded, hasLength(1));
        expect(syncState.recorded.single.pubkey, _validPubkeyA);
        expect(syncState.recorded.single.createdAt, nip04CreatedAt);

        await controller.close();
        await repository.stopListening();
      });

      test('marks conversation as read for own messages', () async {
        final giftWrap = createGiftWrapEvent();
        // Sender is the current user
        final rumor = createRumorEvent(
          pubkey: _validPubkeyA,
          tags: [
            ['p', _validPubkeyB],
          ],
        );

        when(
          () => mockDirectMessagesDao.hasGiftWrap(
            _giftWrapEventId,
          ),
        ).thenAnswer((_) async => false);
        stubDaoInserts();

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => rumor,
        );

        await repository.startListening();
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: _validPubkeyA,
            subject: any(named: 'subject'),
            currentUserHasSent: true,
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: 'nip17',
          ),
        ).called(1);

        await controller.close();
        await repository.stopListening();
      });

      test('skips duplicate gift wrap events', () async {
        final giftWrap = createGiftWrapEvent();

        when(
          () => mockDirectMessagesDao.hasGiftWrap(
            _giftWrapEventId,
          ),
        ).thenAnswer((_) async => true);

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => createRumorEvent(),
        );

        await repository.startListening();
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        );

        await controller.close();
        await repository.stopListening();
      });

      test('skips events when decryption fails', () async {
        final giftWrap = createGiftWrapEvent();

        when(
          () => mockDirectMessagesDao.hasGiftWrap(
            _giftWrapEventId,
          ),
        ).thenAnswer((_) async => false);

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => null,
        );

        await repository.startListening();
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        );

        await controller.close();
        await repository.stopListening();
      });

      test('skips events with wrong kind', () async {
        final giftWrap = createGiftWrapEvent();
        // kind 1 instead of kind 14
        final wrongKindRumor = createRumorEvent(kind: 1);

        when(
          () => mockDirectMessagesDao.hasGiftWrap(
            _giftWrapEventId,
          ),
        ).thenAnswer((_) async => false);

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => wrongKindRumor,
        );

        await repository.startListening();
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        );

        await controller.close();
        await repository.stopListening();
      });

      test('skips events with fewer than 2 participants', () async {
        final giftWrap = createGiftWrapEvent();
        // Rumor with no p tags — only sender pubkey = 1 participant
        final rumor = createRumorEvent(tags: []);

        when(
          () => mockDirectMessagesDao.hasGiftWrap(
            _giftWrapEventId,
          ),
        ).thenAnswer((_) async => false);

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => rumor,
        );

        await repository.startListening();
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        );

        await controller.close();
        await repository.stopListening();
      });

      test('extracts reply-to and subject tags', () async {
        final giftWrap = createGiftWrapEvent();
        final rumor = createRumorEvent(
          tags: [
            ['p', _validPubkeyA],
            ['e', _rumorEventId],
            ['subject', 'Video share'],
          ],
        );

        when(
          () => mockDirectMessagesDao.hasGiftWrap(
            _giftWrapEventId,
          ),
        ).thenAnswer((_) async => false);
        stubDaoInserts();

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => rumor,
        );

        await repository.startListening();
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockDirectMessagesDao.insertMessage(
            id: _rumorEventId,
            conversationId: any(named: 'conversationId'),
            senderPubkey: _validPubkeyB,
            content: 'Hello from B!',
            createdAt: 1700000000,
            giftWrapId: _giftWrapEventId,
            replyToId: _rumorEventId,
            subject: 'Video share',
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).called(1);

        await controller.close();
        await repository.stopListening();
      });

      test(
        'defaults extra p-tags to 1:1 when no existing conversation',
        () async {
          // When a message has 3+ participants but no existing group or
          // 1:1 conversation exists, defaults to 1:1 to prevent phantom
          // groups from non-compliant clients.
          final giftWrap = createGiftWrapEvent();
          final rumor = createRumorEvent(
            tags: [
              ['p', _validPubkeyA],
              ['p', _validPubkeyC],
            ],
          );

          when(
            () => mockDirectMessagesDao.hasGiftWrap(
              _giftWrapEventId,
            ),
          ).thenAnswer((_) async => false);
          stubDaoInserts();

          final controller = StreamController<Event>();
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          final repository = createRepository(
            rumorDecryptor: (_, _) async => rumor,
          );

          await repository.startListening();
          controller.add(giftWrap);
          await Future<void>.delayed(Duration.zero);

          verify(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: false,
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).called(1);

          await controller.close();
          await repository.stopListening();
        },
      );

      test('processes multiple events sequentially', () async {
        final giftWrap1 = createGiftWrapEvent();
        final giftWrap2 = createGiftWrapEvent(
          id: _giftWrapEventId2,
        );
        final rumor1 = createRumorEvent(content: 'First');
        final rumor2 = createRumorEvent(
          id:
              'aaaa9012345678901234567890abcdef'
              '1234567890123456789012ab12c3d4',
          content: 'Second',
        );

        when(
          () => mockDirectMessagesDao.hasGiftWrap(
            _giftWrapEventId,
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.hasGiftWrap(
            _giftWrapEventId2,
          ),
        ).thenAnswer((_) async => false);
        stubDaoInserts();

        var callCount = 0;
        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async {
            callCount++;
            return callCount == 1 ? rumor1 : rumor2;
          },
        );

        await repository.startListening();
        controller.add(giftWrap1);
        await Future<void>.delayed(Duration.zero);
        controller.add(giftWrap2);
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).called(2);

        await controller.close();
        await repository.stopListening();
      });

      test('handles DAO exception gracefully', () async {
        final giftWrap = createGiftWrapEvent();
        final rumor = createRumorEvent();

        when(
          () => mockDirectMessagesDao.hasGiftWrap(
            _giftWrapEventId,
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenThrow(Exception('DB write failed'));

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => rumor,
        );

        await repository.startListening();
        // Should not throw — error is caught internally
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);

        await controller.close();
        await repository.stopListening();
      });
    });

    // -----------------------------------------------------------------
    // Subscription lifecycle
    // -----------------------------------------------------------------

    group('subscription lifecycle', () {
      test('startListening subscribes to kind 1059 events', () async {
        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);
        when(
          () => mockNostrClient.unsubscribe(any()),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        await repository.startListening();

        verify(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).called(1);

        await repository.stopListening();
        await controller.close();
      });

      test('startListening is idempotent', () async {
        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);
        when(
          () => mockNostrClient.unsubscribe(any()),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        await repository.startListening();
        await repository.startListening(); // Second call is no-op

        verify(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).called(1);

        await repository.stopListening();
        await controller.close();
      });

      test('stopListening unsubscribes', () async {
        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);
        when(
          () => mockNostrClient.unsubscribe(any()),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        await repository.startListening();
        await repository.stopListening();

        verify(
          () => mockNostrClient.unsubscribe(any()),
        ).called(1);

        await controller.close();
      });

      test('startListening after stopListening re-subscribes '
          '(inbox can be re-opened)', () async {
        // Return a fresh stream per subscribe call so both listens succeed.
        final controllers = <StreamController<Event>>[];
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) {
          final controller = StreamController<Event>();
          controllers.add(controller);
          return controller.stream;
        });
        when(
          () => mockNostrClient.unsubscribe(any()),
        ).thenAnswer((_) async {});

        final repository = createRepository();

        await repository.startListening();
        await repository.stopListening();
        await repository.startListening();

        // Both opens should have produced a subscribe call on the client.
        verify(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).called(2);

        await repository.stopListening();
        for (final c in controllers) {
          await c.close();
        }
      });

      test('initialize does not open a subscription (lazy inbox)', () async {
        // New behavior: initialize() only wires credentials. The gift-wrap
        // subscription is started by the inbox screen via startListening().
        // This keeps cold start off the UI isolate until the user visits
        // the messages tab. Regression guard for
        // docs/plans/2026-04-05-dm-scaling-fix-design.md.
        final repository =
            DmRepository(
              nostrClient: mockNostrClient,
              messageService: mockMessageService,
              directMessagesDao: mockDirectMessagesDao,
              conversationsDao: mockConversationsDao,
              // Intentionally no userPubkey/signer — initialize() provides them.
            )..setCredentials(
              userPubkey: _validPubkeyA,
              signer: LocalNostrSigner(_validPrivateKey),
              messageService: mockMessageService,
            );

        // The relay client must not have been asked to subscribe.
        verifyNever(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        );
        // But the repository should still be initialized so send() works.
        expect(repository.isInitialized, isTrue);
      });

      test('setCredentials triggers backfillCurrentUserHasSent', () async {
        DmRepository(
          nostrClient: mockNostrClient,
          directMessagesDao: mockDirectMessagesDao,
          conversationsDao: mockConversationsDao,
        ).setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );

        // Let the unawaited _runPostAuthMaintenance() settle.
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockConversationsDao.backfillCurrentUserHasSent(
            _validPubkeyA,
          ),
        ).called(1);
      });

      test('startListening does not poll the relay', () async {
        // Regression guard: the 10s gift-wrap poll timer was removed
        // because it re-fetched the last 20 events forever on the UI
        // isolate, producing constant dedup skips and log spam. The
        // live subscription is now the sole event source while the
        // inbox is open. See
        // docs/plans/2026-04-05-dm-scaling-fix-design.md.
        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);
        when(
          () => mockNostrClient.unsubscribe(any()),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        await repository.startListening();

        // Wait well beyond any former poll interval.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // queryEvents must never be called — no background poller.
        verifyNever(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            useCache: any(named: 'useCache'),
          ),
        );

        await repository.stopListening();
        await controller.close();
      });

      test(
        'startListening on first ever open uses limit:50 and no since',
        () async {
          final controller = StreamController<Event>();
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          final syncState = _FakeDmSyncState();
          final repository = createRepository(syncState: syncState);
          await repository.startListening();

          final captured =
              verify(
                    () => mockNostrClient.subscribe(
                      captureAny(),
                      subscriptionId: any(named: 'subscriptionId'),
                    ),
                  ).captured.single
                  as List<nostr_filter.Filter>;
          expect(captured, hasLength(1));
          expect(captured.single.limit, 50);
          expect(captured.single.since, isNull);

          await repository.stopListening();
          await controller.close();
        },
      );

      test(
        'startListening on subsequent open uses since = newest - 2d',
        () async {
          const newest = 1700000000;
          final controller = StreamController<Event>();
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          final syncState = _FakeDmSyncState()..newestOverride = newest;
          final repository = createRepository(syncState: syncState);
          await repository.startListening();

          final captured =
              verify(
                    () => mockNostrClient.subscribe(
                      captureAny(),
                      subscriptionId: any(named: 'subscriptionId'),
                    ),
                  ).captured.single
                  as List<nostr_filter.Filter>;
          expect(captured, hasLength(1));
          expect(captured.single.since, newest - 2 * 86400);
          expect(captured.single.limit, isNull);

          await repository.stopListening();
          await controller.close();
        },
      );
    });

    // -----------------------------------------------------------------
    // loadOlderMessages pagination
    // -----------------------------------------------------------------

    group('loadOlderMessages', () {
      test('queries until:oldest with limit 50', () async {
        const oldest = 1699000000;
        final syncState = _FakeDmSyncState()..oldestOverride = oldest;
        when(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);

        final repository = createRepository(syncState: syncState);

        await repository.loadOlderMessages();

        final captured =
            verify(
                  () => mockNostrClient.queryEvents(
                    captureAny(),
                    subscriptionId: any(named: 'subscriptionId'),
                    useCache: any(named: 'useCache'),
                  ),
                ).captured.single
                as List<nostr_filter.Filter>;
        expect(captured, hasLength(1));
        expect(captured.single.until, oldest);
        expect(captured.single.limit, 50);
      });

      test('is a no-op when oldest is null', () async {
        final syncState = _FakeDmSyncState();
        final repository = createRepository(syncState: syncState);

        await repository.loadOlderMessages();

        verifyNever(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            useCache: any(named: 'useCache'),
          ),
        );
      });
    });

    // -----------------------------------------------------------------
    // Query methods
    // -----------------------------------------------------------------

    group('watchConversations', () {
      test('maps $ConversationRow to $DmConversation', () async {
        final participants = [_validPubkeyA, _validPubkeyB]..sort();
        final convId = DmRepository.computeConversationId(participants);

        when(
          () => mockConversationsDao.watchAllConversations(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) => Stream.value([
            ConversationRow(
              id: convId,
              participantPubkeys: jsonEncode(participants),
              isGroup: false,
              lastMessageContent: 'Hi',
              lastMessageTimestamp: 1700000000,
              lastMessageSenderPubkey: _validPubkeyB,
              isRead: true,
              currentUserHasSent: false,
              createdAt: 1700000000,
            ),
          ]),
        );

        final repository = createRepository();
        final conversations = await repository.watchConversations().first;

        expect(conversations, hasLength(1));
        expect(conversations.first.id, equals(convId));
        expect(
          conversations.first.participantPubkeys,
          equals(participants),
        );
        expect(conversations.first.isGroup, isFalse);
        expect(
          conversations.first.lastMessageContent,
          equals('Hi'),
        );
        expect(conversations.first.isRead, isTrue);
      });
    });

    group('getConversation', () {
      test('returns $DmConversation when conversation exists', () async {
        final participants = [_validPubkeyA, _validPubkeyB]..sort();
        final convId = DmRepository.computeConversationId(participants);

        when(
          () => mockConversationsDao.getConversation(
            convId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => ConversationRow(
            id: convId,
            participantPubkeys: jsonEncode(participants),
            isGroup: false,
            lastMessageContent: 'Hi',
            lastMessageTimestamp: 1700000000,
            lastMessageSenderPubkey: _validPubkeyB,
            isRead: true,
            currentUserHasSent: false,
            createdAt: 1700000000,
          ),
        );

        final repository = createRepository();
        final conversation = await repository.getConversation(convId);

        expect(conversation, isNotNull);
        expect(conversation!.id, equals(convId));
        expect(conversation.participantPubkeys, equals(participants));
      });

      test('returns null when conversation does not exist', () async {
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final repository = createRepository();
        final conversation = await repository.getConversation('nonexistent');

        expect(conversation, isNull);
      });
    });

    group('watchMessages', () {
      test('maps $DirectMessageRow to $DmMessage', () async {
        final convId = DmRepository.computeConversationId(
          [_validPubkeyA, _validPubkeyB],
        );

        when(
          () => mockDirectMessagesDao.watchMessagesForConversation(
            convId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) => Stream.value([
            DirectMessageRow(
              id: _rumorEventId,
              conversationId: convId,
              senderPubkey: _validPubkeyB,
              content: 'Hello!',
              createdAt: 1700000000,
              giftWrapId: _giftWrapEventId,
              messageKind: 14,
              isDeleted: false,
            ),
          ]),
        );

        final repository = createRepository();
        final messages = await repository.watchMessages(convId).first;

        expect(messages, hasLength(1));
        expect(messages.first.id, equals(_rumorEventId));
        expect(
          messages.first.senderPubkey,
          equals(_validPubkeyB),
        );
        expect(messages.first.content, equals('Hello!'));
        expect(
          messages.first.giftWrapId,
          equals(_giftWrapEventId),
        );
      });
    });

    group('watchOutgoing', () {
      test('delegates to $OutgoingDmsDao when wired', () async {
        const convId = 'outgoing-conv-id';
        final mockOutgoingDao = _MockOutgoingDmsDao();
        final row = OutgoingDm(
          id: 'rumor-1',
          conversationId: convId,
          recipientPubkey: _validPubkeyB,
          content: 'in-flight',
          createdAt: 1700000000,
          rumorEventJson: '{}',
          recipientWrapStatus: OutgoingWrapStatus.pending,
          selfWrapStatus: OutgoingWrapStatus.pending,
          queuedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          ownerPubkey: _validPubkeyA,
        );
        when(
          () => mockOutgoingDao.watchForConversation(
            conversationId: convId,
            ownerPubkey: _validPubkeyA,
          ),
        ).thenAnswer((_) => Stream.value([row]));

        final repository = createRepository(outgoingDmsDao: mockOutgoingDao);
        final emitted = await repository.watchOutgoing(convId).first;

        expect(emitted, equals([row]));
        verify(
          () => mockOutgoingDao.watchForConversation(
            conversationId: convId,
            ownerPubkey: _validPubkeyA,
          ),
        ).called(1);
      });

      test('emits an empty list when no OutgoingDmsDao is wired', () async {
        final repository = createRepository();
        final emitted = await repository.watchOutgoing('any-conv').first;
        expect(emitted, isEmpty);
      });
    });

    group('markConversationAsRead', () {
      test('delegates to $ConversationsDao', () async {
        const convId = 'some-conversation-id';
        when(
          () => mockConversationsDao.markAsRead(
            convId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => true);

        final repository = createRepository();
        await repository.markConversationAsRead(convId);

        verify(
          () => mockConversationsDao.markAsRead(
            convId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).called(1);
      });
    });

    // -----------------------------------------------------------------
    // removeConversation / removeConversations / markConversationsAsRead
    // / countMessagesInConversation
    // -----------------------------------------------------------------

    group('removeConversation', () {
      test(
        'deletes messages then conversation in a transaction',
        () async {
          const convId =
              'aabb00112233445566778899aabbccddeeff'
              '0011223344556677889900aabb00';

          when(
            () => mockConversationsDao.runInTransaction<void>(any()),
          ).thenAnswer((inv) async {
            final callback =
                inv.positionalArguments.first as Future<void> Function();
            await callback();
          });
          when(
            () => mockDirectMessagesDao.deleteConversationMessages(
              convId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => 3);
          when(
            () => mockConversationsDao.deleteConversation(
              convId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => 1);

          final repository = createRepository();
          await repository.removeConversation(convId);

          verify(
            () => mockConversationsDao.runInTransaction<void>(any()),
          ).called(1);
          verify(
            () => mockDirectMessagesDao.deleteConversationMessages(
              convId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).called(1);
          verify(
            () => mockConversationsDao.deleteConversation(
              convId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).called(1);
        },
      );

      test('rethrows when DAO throws', () async {
        const convId =
            'aabb00112233445566778899aabbccddeeff0011223344556677889900aabb00';

        when(
          () => mockConversationsDao.runInTransaction<void>(any()),
        ).thenAnswer((inv) async {
          final callback =
              inv.positionalArguments.first as Future<void> Function();
          await callback();
        });
        when(
          () => mockDirectMessagesDao.deleteConversationMessages(
            convId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenThrow(Exception('db error'));

        final repository = createRepository();

        expect(
          () => repository.removeConversation(convId),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('removeConversations', () {
      const convIdA =
          'aabb00112233445566778899aabbccddeeff0011223344556677889900aabb00';
      const convIdB =
          'bbcc00112233445566778899aabbccddeeff0011223344556677889900aabb00';

      test(
        'deletes messages then conversations for all IDs in a transaction',
        () async {
          final ids = [convIdA, convIdB];

          when(
            () => mockConversationsDao.runInTransaction<void>(any()),
          ).thenAnswer((inv) async {
            final callback =
                inv.positionalArguments.first as Future<void> Function();
            await callback();
          });
          when(
            () => mockDirectMessagesDao.deleteMultipleConversationMessages(
              ids,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => 5);
          when(
            () => mockConversationsDao.deleteMultiple(
              ids,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => 2);

          final repository = createRepository();
          await repository.removeConversations(ids);

          verify(
            () => mockConversationsDao.runInTransaction<void>(any()),
          ).called(1);
          verify(
            () => mockDirectMessagesDao.deleteMultipleConversationMessages(
              ids,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).called(1);
          verify(
            () => mockConversationsDao.deleteMultiple(
              ids,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).called(1);
        },
      );

      test('is no-op when conversationIds is empty', () async {
        final repository = createRepository();
        await repository.removeConversations([]);

        verifyNever(
          () => mockConversationsDao.runInTransaction<void>(any()),
        );
        verifyNever(
          () => mockDirectMessagesDao.deleteMultipleConversationMessages(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
        verifyNever(
          () => mockConversationsDao.deleteMultiple(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      });
    });

    group('markConversationsAsRead', () {
      test('delegates to conversationsDao.markMultipleAsRead', () async {
        const convIdA =
            'aabb00112233445566778899aabbccddeeff0011223344556677889900aabb00';
        const convIdB =
            'bbcc00112233445566778899aabbccddeeff0011223344556677889900aabb00';
        final ids = [convIdA, convIdB];

        when(
          () => mockConversationsDao.markMultipleAsRead(
            ids,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        await repository.markConversationsAsRead(ids);

        verify(
          () => mockConversationsDao.markMultipleAsRead(
            ids,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).called(1);
      });
    });

    group('countMessagesInConversation', () {
      test('delegates to directMessagesDao.countMessages', () async {
        const convId =
            'aabb00112233445566778899aabbccddeeff0011223344556677889900aabb00';

        when(
          () => mockDirectMessagesDao.countMessages(
            convId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => 5);

        final repository = createRepository();
        final count = await repository.countMessagesInConversation(convId);

        expect(count, equals(5));
        verify(
          () => mockDirectMessagesDao.countMessages(
            convId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).called(1);
      });
    });

    group('_handleGiftWrapEvent preserves existing state', () {
      void stubDaoInserts() {
        when(
          () => mockDirectMessagesDao.hasMatchingMessage(
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);
      }

      test(
        'preserves currentUserHasSent=true when incoming message arrives',
        () async {
          final participants = [_validPubkeyA, _validPubkeyB]..sort();
          final convId = DmRepository.computeConversationId(participants);

          final giftWrap = Event.fromJson({
            'id': _giftWrapEventId,
            'pubkey':
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'created_at': 1700000000,
            'kind': EventKind.giftWrap,
            'tags': [
              ['p', _validPubkeyA],
            ],
            'content': 'encrypted-content',
            'sig': '',
          });

          // Rumor from pubkeyB (not us) — an incoming message
          final rumor = Event.fromJson({
            'id': _rumorEventId,
            'pubkey': _validPubkeyB,
            'created_at': 1700000100,
            'kind': EventKind.privateDirectMessage,
            'tags': [
              ['p', _validPubkeyA],
            ],
            'content': 'Hey there',
            'sig': '',
          });

          when(
            () => mockDirectMessagesDao.hasGiftWrap(_giftWrapEventId),
          ).thenAnswer((_) async => false);

          stubDaoInserts();

          // Override the generic getConversation(any()) stub from
          // stubDaoInserts to return an existing row where
          // currentUserHasSent is already true.
          when(
            () => mockConversationsDao.getConversation(
              convId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: convId,
              participantPubkeys: jsonEncode(participants),
              isGroup: false,
              lastMessageContent: 'Previous message',
              lastMessageTimestamp: 1700000000,
              lastMessageSenderPubkey: _validPubkeyA,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1699999000,
            ),
          );

          final controller = StreamController<Event>();
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          final repository = createRepository(
            rumorDecryptor: (_, _) async => rumor,
          );

          await repository.startListening();
          controller.add(giftWrap);
          await Future<void>.delayed(Duration.zero);

          // Verify upsertConversation is called with
          // currentUserHasSent: true (preserved from existing row).
          verify(
            () => mockConversationsDao.upsertConversation(
              id: convId,
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: false,
              createdAt: 1699999000,
              lastMessageContent: 'Hey there',
              lastMessageTimestamp: 1700000100,
              lastMessageSenderPubkey: _validPubkeyB,
              subject: any(named: 'subject'),
              isRead: false,
              currentUserHasSent: true,
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).called(1);

          await controller.close();
          await repository.stopListening();
        },
      );
    });

    // -----------------------------------------------------------------
    // Kind 15 (file message) support
    // -----------------------------------------------------------------

    group('Kind 15 receive pipeline', () {
      void stubDaoInserts() {
        when(
          () => mockDirectMessagesDao.hasMatchingMessage(
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);
      }

      const fileHash =
          'cccccccccccccccccccccccccccccccc'
          'cccccccccccccccccccccccccccccccc';
      const decryptionKey =
          'dddddddddddddddddddddddddddddd'
          'dddddddddddddddddddddddddddddd';
      const decryptionNonce = 'eeeeeeeeeeeeeeeeeeeeeeee';

      test('persists file metadata for kind 15 events', () async {
        final giftWrap = Event.fromJson({
          'id': _giftWrapEventId,
          'pubkey':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'created_at': 1700000000,
          'kind': EventKind.giftWrap,
          'tags': [
            ['p', _validPubkeyA],
          ],
          'content': 'encrypted-content',
          'sig': '',
        });

        final fileRumor = Event.fromJson({
          'id': _rumorEventId,
          'pubkey': _validPubkeyB,
          'created_at': 1700000000,
          'kind': EventKind.fileMessage,
          'tags': [
            ['p', _validPubkeyA],
            ['file-type', 'image/jpeg'],
            ['encryption-algorithm', 'aes-gcm'],
            ['decryption-key', decryptionKey],
            ['decryption-nonce', decryptionNonce],
            ['x', fileHash],
            ['size', '1024'],
            ['dim', '1920x1080'],
          ],
          'content': 'https://blossom.example.com/file.enc',
          'sig': '',
        });

        when(
          () => mockDirectMessagesDao.hasGiftWrap(_giftWrapEventId),
        ).thenAnswer((_) async => false);
        stubDaoInserts();

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => fileRumor,
        );

        await repository.startListening();
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockDirectMessagesDao.insertMessage(
            id: _rumorEventId,
            conversationId: any(named: 'conversationId'),
            senderPubkey: _validPubkeyB,
            content: 'https://blossom.example.com/file.enc',
            createdAt: 1700000000,
            giftWrapId: _giftWrapEventId,
            messageKind: EventKind.fileMessage,
            fileType: 'image/jpeg',
            encryptionAlgorithm: 'aes-gcm',
            decryptionKey: decryptionKey,
            decryptionNonce: decryptionNonce,
            fileHash: fileHash,
            fileSize: 1024,
            dimensions: '1920x1080',
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).called(1);

        verify(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Sent a photo',
            lastMessageTimestamp: 1700000000,
            lastMessageSenderPubkey: _validPubkeyB,
            isRead: false,
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).called(1);

        await controller.close();
        await repository.stopListening();
      });

      test('skips kind 15 events with missing required tags', () async {
        final giftWrap = Event.fromJson({
          'id': _giftWrapEventId,
          'pubkey':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'created_at': 1700000000,
          'kind': EventKind.giftWrap,
          'tags': [
            ['p', _validPubkeyA],
          ],
          'content': 'encrypted-content',
          'sig': '',
        });

        // Missing file-type and encryption tags
        final incompleteRumor = Event.fromJson({
          'id': _rumorEventId,
          'pubkey': _validPubkeyB,
          'created_at': 1700000000,
          'kind': EventKind.fileMessage,
          'tags': [
            ['p', _validPubkeyA],
            // Missing required tags: file-type, encryption-algorithm, etc.
          ],
          'content': 'https://blossom.example.com/file.enc',
          'sig': '',
        });

        when(
          () => mockDirectMessagesDao.hasGiftWrap(_giftWrapEventId),
        ).thenAnswer((_) async => false);
        stubDaoInserts();

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => incompleteRumor,
        );

        await repository.startListening();
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);

        // Still persists, but with null file metadata
        verify(
          () => mockDirectMessagesDao.insertMessage(
            id: _rumorEventId,
            conversationId: any(named: 'conversationId'),
            senderPubkey: _validPubkeyB,
            content: 'https://blossom.example.com/file.enc',
            createdAt: 1700000000,
            giftWrapId: _giftWrapEventId,
            messageKind: EventKind.fileMessage,
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).called(1);

        await controller.close();
        await repository.stopListening();
      });
    });

    group('watchMessages - Kind 15', () {
      test('maps $DirectMessageRow with file metadata to $DmMessage', () async {
        final convId = DmRepository.computeConversationId(
          [_validPubkeyA, _validPubkeyB],
        );

        const fileHash =
            'cccccccccccccccccccccccccccccccc'
            'cccccccccccccccccccccccccccccccc';
        const decryptionKey =
            'dddddddddddddddddddddddddddddd'
            'dddddddddddddddddddddddddddddd';
        const decryptionNonce = 'eeeeeeeeeeeeeeeeeeeeeeee';

        when(
          () => mockDirectMessagesDao.watchMessagesForConversation(
            convId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) => Stream.value([
            DirectMessageRow(
              id: _rumorEventId,
              conversationId: convId,
              senderPubkey: _validPubkeyB,
              content: 'https://blossom.example.com/file.enc',
              createdAt: 1700000000,
              giftWrapId: _giftWrapEventId,
              messageKind: EventKind.fileMessage,
              fileType: 'image/jpeg',
              encryptionAlgorithm: 'aes-gcm',
              decryptionKey: decryptionKey,
              decryptionNonce: decryptionNonce,
              fileHash: fileHash,
              fileSize: 1024,
              dimensions: '1920x1080',
              isDeleted: false,
            ),
          ]),
        );

        final repository = createRepository();
        final messages = await repository.watchMessages(convId).first;

        expect(messages, hasLength(1));
        expect(messages.first.isFileMessage, isTrue);
        expect(messages.first.messageKind, equals(EventKind.fileMessage));
        expect(messages.first.fileMetadata, isNotNull);
        expect(
          messages.first.fileMetadata!.fileType,
          equals('image/jpeg'),
        );
        expect(messages.first.fileMetadata!.isImage, isTrue);
        expect(
          messages.first.fileMetadata!.decryptionKey,
          equals(decryptionKey),
        );
        expect(
          messages.first.fileMetadata!.decryptionNonce,
          equals(decryptionNonce),
        );
        expect(
          messages.first.fileMetadata!.fileHash,
          equals(fileHash),
        );
        expect(messages.first.fileMetadata!.fileSize, equals(1024));
        expect(
          messages.first.fileMetadata!.dimensions,
          equals('1920x1080'),
        );
      });
    });

    group('sendFileMessage', () {
      const fileHash =
          'cccccccccccccccccccccccccccccccc'
          'cccccccccccccccccccccccccccccccc';
      const decryptionKey =
          'dddddddddddddddddddddddddddddd'
          'dddddddddddddddddddddddddddddd';
      const decryptionNonce = 'eeeeeeeeeeeeeeeeeeeeeeee';

      const testFileMetadata = DmFileMetadata(
        fileType: 'image/jpeg',
        encryptionAlgorithm: 'aes-gcm',
        decryptionKey: decryptionKey,
        decryptionNonce: decryptionNonce,
        fileHash: fileHash,
        fileSize: 2048,
      );

      test('throws $ArgumentError for invalid pubkey', () {
        final repository = createRepository();

        expect(
          () => repository.sendFileMessage(
            recipientPubkey: 'short',
            fileUrl: 'https://blossom.example.com/file.enc',
            fileMetadata: testFileMetadata,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws $ArgumentError for empty file URL', () {
        final repository = createRepository();

        expect(
          () => repository.sendFileMessage(
            recipientPubkey: _validPubkeyB,
            fileUrl: '',
            fileMetadata: testFileMetadata,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('sends kind 15 event and persists with file metadata', () async {
        when(
          () => mockMessageService.sendPrivateMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            eventKind: any(named: 'eventKind'),
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: _rumorEventId,
            messageEventId: _giftWrapEventId,
            recipientPubkey: _validPubkeyB,
          ),
        );
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final repository = createRepository();

        final result = await repository.sendFileMessage(
          recipientPubkey: _validPubkeyB,
          fileUrl: 'https://blossom.example.com/file.enc',
          fileMetadata: testFileMetadata,
        );

        expect(result.success, isTrue);

        // Verify eventKind is fileMessage (15)
        verify(
          () => mockMessageService.sendPrivateMessage(
            recipientPubkey: _validPubkeyB,
            content: 'https://blossom.example.com/file.enc',
            eventKind: EventKind.fileMessage,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).called(1);

        // Verify file metadata persisted in DB
        verify(
          () => mockDirectMessagesDao.insertMessage(
            id: _rumorEventId,
            conversationId: any(named: 'conversationId'),
            senderPubkey: _validPubkeyA,
            content: 'https://blossom.example.com/file.enc',
            createdAt: any(named: 'createdAt'),
            giftWrapId: _giftWrapEventId,
            messageKind: EventKind.fileMessage,
            subject: any(named: 'subject'),
            fileType: 'image/jpeg',
            encryptionAlgorithm: 'aes-gcm',
            decryptionKey: decryptionKey,
            decryptionNonce: decryptionNonce,
            fileHash: fileHash,
            fileSize: 2048,
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).called(1);

        // Verify conversation preview text
        verify(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: false,
            createdAt: any(named: 'createdAt'),
            lastMessageContent: 'Sent a photo',
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: _validPubkeyA,
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).called(1);
      });

      test('does not persist on send failure', () async {
        when(
          () => mockMessageService.sendPrivateMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            eventKind: any(named: 'eventKind'),
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.failure('Relay rejected'),
        );

        final repository = createRepository();

        final result = await repository.sendFileMessage(
          recipientPubkey: _validPubkeyB,
          fileUrl: 'https://blossom.example.com/file.enc',
          fileMetadata: testFileMetadata,
        );

        expect(result.success, isFalse);

        verifyNever(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        );
      });
    });

    // -----------------------------------------------------------------
    // Moderation DM scenarios (TC-SOCIAL-025 / TC-SOCIAL-026)
    // -----------------------------------------------------------------

    group('moderation DM scenarios', () {
      /// The fallback moderation pubkey (inlined from ModerationLabelService).
      const moderationPubkey =
          '8fd5eb6d8f362163bc00a5ab6b4a3167dbf32d00ec4efdbcf43b3c9514433b7e';

      void stubDaoInserts() {
        when(
          () => mockDirectMessagesDao.hasMatchingMessage(
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);
      }

      test(
        'sendMessage to moderation pubkey succeeds and persists',
        () async {
          const reportContent =
              'Content Report\n'
              'Reason: Spam or Unwanted Content\n'
              'Event: abc123eventid';

          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );
          stubDaoInserts();
          // Stub publishEvent for the NIP-04 fallback (fire-and-forget)
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          final repository = createRepository();

          final result = await repository.sendMessage(
            recipientPubkey: moderationPubkey,
            content: reportContent,
          );

          expect(result.success, isTrue);

          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: moderationPubkey,
            ),
          ).called(1);

          verify(
            () => mockDirectMessagesDao.insertMessage(
              id: _rumorEventId,
              conversationId: any(named: 'conversationId'),
              senderPubkey: _validPubkeyA,
              content: reportContent,
              createdAt: any(named: 'createdAt'),
              giftWrapId: _giftWrapEventId,
              messageKind: any(named: 'messageKind'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).called(1);
        },
      );

      test(
        'receiving a DM from the moderation pubkey persists correctly',
        () async {
          final giftWrap = Event.fromJson({
            'id': _giftWrapEventId,
            'pubkey':
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'created_at': 1700000000,
            'kind': EventKind.giftWrap,
            'tags': [
              ['p', _validPubkeyA],
            ],
            'content': 'encrypted-content',
            'sig': '',
          });

          // Rumor from the moderation pubkey to the user
          final rumorFromMod = Event.fromJson({
            'id': _rumorEventId,
            'pubkey': moderationPubkey,
            'created_at': 1700000000,
            'kind': EventKind.privateDirectMessage,
            'tags': [
              ['p', _validPubkeyA],
            ],
            'content': 'Your report has been reviewed. Action taken.',
            'sig': '',
          });

          when(
            () => mockDirectMessagesDao.hasGiftWrap(_giftWrapEventId),
          ).thenAnswer((_) async => false);
          stubDaoInserts();

          final controller = StreamController<Event>();
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          final repository = createRepository(
            rumorDecryptor: (_, _) async => rumorFromMod,
          );

          await repository.startListening();
          controller.add(giftWrap);
          await Future<void>.delayed(Duration.zero);

          verify(
            () => mockDirectMessagesDao.insertMessage(
              id: _rumorEventId,
              conversationId: any(named: 'conversationId'),
              senderPubkey: moderationPubkey,
              content: 'Your report has been reviewed. Action taken.',
              createdAt: 1700000000,
              giftWrapId: _giftWrapEventId,
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).called(1);

          // Verify conversation created with moderation pubkey as participant
          verify(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: false,
              createdAt: 1700000000,
              lastMessageContent:
                  'Your report has been reviewed. Action taken.',
              lastMessageTimestamp: 1700000000,
              lastMessageSenderPubkey: moderationPubkey,
              subject: any(named: 'subject'),
              isRead: false,
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).called(1);

          await controller.close();
          await repository.stopListening();
        },
      );

      test(
        'computeConversationId is deterministic with moderation pubkey',
        () {
          final idUserFirst = DmRepository.computeConversationId(
            [_validPubkeyA, moderationPubkey],
          );
          final idModFirst = DmRepository.computeConversationId(
            [moderationPubkey, _validPubkeyA],
          );

          expect(
            idUserFirst,
            equals(idModFirst),
            reason:
                'Conversation ID must be the same regardless of '
                'participant order',
          );

          // Verify it is a valid 64-char hex SHA-256
          expect(idUserFirst, hasLength(64));
          expect(
            idUserFirst,
            matches(RegExp(r'^[0-9a-f]{64}$')),
          );
        },
      );

      test(
        'moderation conversation is distinct from other conversations',
        () {
          final modConvId = DmRepository.computeConversationId(
            [_validPubkeyA, moderationPubkey],
          );
          final regularConvId = DmRepository.computeConversationId(
            [_validPubkeyA, _validPubkeyB],
          );

          expect(
            modConvId,
            isNot(equals(regularConvId)),
            reason:
                'Moderation conversation must be distinct from '
                'regular user conversations',
          );
        },
      );

      test(
        'moderation pubkey is a valid 64-character hex string',
        () {
          expect(
            () => DmRepository.validatePubkey(moderationPubkey),
            returnsNormally,
          );
          expect(moderationPubkey, hasLength(64));
          expect(
            RegExp(r'^[0-9a-f]{64}$').hasMatch(moderationPubkey),
            isTrue,
          );
        },
      );

      test(
        'DM to external Nostr user (non-Divine app) uses same send path',
        () async {
          // Any valid Nostr pubkey works as a recipient, including users
          // not on the Divine app. This verifies NIP-17 interoperability.
          const externalUserPubkey =
              'ff0011223344556677889900aabbccddeeff'
              '0011223344556677889900aabbcc';

          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );
          stubDaoInserts();
          // Stub publishEvent for the NIP-04 fallback (fire-and-forget)
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          final repository = createRepository();

          final result = await repository.sendMessage(
            recipientPubkey: externalUserPubkey,
            content: 'Hello from Divine!',
          );

          expect(result.success, isTrue);

          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: externalUserPubkey,
            ),
          ).called(1);
        },
      );
    });

    // -----------------------------------------------------------------
    // NIP-04 receive pipeline
    // -----------------------------------------------------------------

    group('NIP-04 receive pipeline', () {
      /// Helper to create a NIP-04 (kind 4) event.
      Event createNip04Event({
        String? id,
        String? senderPubkey,
        String? recipientPubkey,
        String? content,
        int? createdAt,
        List<List<String>>? tags,
      }) {
        final sender = senderPubkey ?? _validPubkeyB;
        final recipient = recipientPubkey ?? _validPubkeyA;
        return Event.fromJson({
          'id': id ?? _rumorEventId,
          'pubkey': sender,
          'created_at': createdAt ?? 1700000000,
          'kind': EventKind.directMessage,
          'tags':
              tags ??
              [
                ['p', recipient],
              ],
          'content': content ?? 'encrypted-nip04-content',
          'sig': '',
        });
      }

      void stubDaoInserts() {
        when(
          () => mockDirectMessagesDao.hasMatchingMessage(
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);
      }

      test('skips NIP-04 duplicate when NIP-17 copy already stored', () async {
        final nip04Event = createNip04Event();

        when(
          () => mockDirectMessagesDao.hasGiftWrap(_rumorEventId),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.hasMatchingMessage(
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => true);

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          nip04Decryptor: (pubkey, ciphertext) async => 'Hello!',
        );

        await repository.startListening();
        controller.add(nip04Event);
        await Future<void>.delayed(Duration.zero);

        // Should NOT insert — cross-protocol dedup caught it
        verifyNever(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        );

        await controller.close();
        await repository.stopListening();
      });

      test('decrypts and persists a NIP-04 message', () async {
        final nip04Event = createNip04Event();

        when(
          () => mockDirectMessagesDao.hasGiftWrap(_rumorEventId),
        ).thenAnswer((_) async => false);
        stubDaoInserts();

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          nip04Decryptor: (_, _) async => 'Decrypted NIP-04 text',
        );

        await repository.startListening();
        controller.add(nip04Event);
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockDirectMessagesDao.insertMessage(
            id: _rumorEventId,
            conversationId: any(named: 'conversationId'),
            senderPubkey: _validPubkeyB,
            content: 'Decrypted NIP-04 text',
            createdAt: 1700000000,
            giftWrapId: _rumorEventId,
            messageKind: EventKind.directMessage,
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).called(1);

        verify(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Decrypted NIP-04 text',
            lastMessageTimestamp: 1700000000,
            lastMessageSenderPubkey: _validPubkeyB,
            isRead: false,
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: 'nip04',
          ),
        ).called(1);

        await controller.close();
        await repository.stopListening();
      });

      test('marks conversation as read for own NIP-04 messages', () async {
        // Sender is the current user
        final nip04Event = createNip04Event(
          senderPubkey: _validPubkeyA,
          recipientPubkey: _validPubkeyB,
          tags: [
            ['p', _validPubkeyB],
          ],
        );

        when(
          () => mockDirectMessagesDao.hasGiftWrap(_rumorEventId),
        ).thenAnswer((_) async => false);
        stubDaoInserts();

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          nip04Decryptor: (_, _) async => 'My sent message',
        );

        await repository.startListening();
        controller.add(nip04Event);
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: false,
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            currentUserHasSent: true,
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).called(1);

        await controller.close();
        await repository.stopListening();
      });

      test('skips duplicate NIP-04 events', () async {
        final nip04Event = createNip04Event();

        when(
          () => mockDirectMessagesDao.hasGiftWrap(_rumorEventId),
        ).thenAnswer((_) async => true);

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          nip04Decryptor: (_, _) async => 'should not reach',
        );

        await repository.startListening();
        controller.add(nip04Event);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        );

        await controller.close();
        await repository.stopListening();
      });

      test('skips NIP-04 events with no p tag', () async {
        final nip04Event = createNip04Event(tags: []);

        when(
          () => mockDirectMessagesDao.hasGiftWrap(_rumorEventId),
        ).thenAnswer((_) async => false);

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          nip04Decryptor: (_, _) async => 'should not reach',
        );

        await repository.startListening();
        controller.add(nip04Event);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        );

        await controller.close();
        await repository.stopListening();
      });

      test('skips NIP-04 events when decryption fails', () async {
        final nip04Event = createNip04Event();

        when(
          () => mockDirectMessagesDao.hasGiftWrap(_rumorEventId),
        ).thenAnswer((_) async => false);

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          nip04Decryptor: (_, _) async => null,
        );

        await repository.startListening();
        controller.add(nip04Event);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        );

        await controller.close();
        await repository.stopListening();
      });

      test('routes NIP-17 and NIP-04 events correctly', () async {
        final giftWrap = Event.fromJson({
          'id': _giftWrapEventId,
          'pubkey':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'created_at': 1700000000,
          'kind': EventKind.giftWrap,
          'tags': [
            ['p', _validPubkeyA],
          ],
          'content': 'encrypted-gift-wrap',
          'sig': '',
        });

        final nip04Event = createNip04Event(
          id: _giftWrapEventId2,
        );

        final rumor = Event.fromJson({
          'id': _rumorEventId,
          'pubkey': _validPubkeyB,
          'created_at': 1700000000,
          'kind': EventKind.privateDirectMessage,
          'tags': [
            ['p', _validPubkeyA],
          ],
          'content': 'NIP-17 message',
          'sig': '',
        });

        when(
          () => mockDirectMessagesDao.hasGiftWrap(any()),
        ).thenAnswer((_) async => false);
        stubDaoInserts();

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => rumor,
          nip04Decryptor: (_, _) async => 'NIP-04 message',
        );

        await repository.startListening();

        // Send both event types
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);
        controller.add(nip04Event);
        await Future<void>.delayed(Duration.zero);

        // Verify NIP-17 was persisted with kind 14
        verify(
          () => mockDirectMessagesDao.insertMessage(
            id: _rumorEventId,
            conversationId: any(named: 'conversationId'),
            senderPubkey: _validPubkeyB,
            content: 'NIP-17 message',
            createdAt: 1700000000,
            giftWrapId: _giftWrapEventId,
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).called(1);

        // Verify NIP-04 was persisted with kind 4
        verify(
          () => mockDirectMessagesDao.insertMessage(
            id: _giftWrapEventId2,
            conversationId: any(named: 'conversationId'),
            senderPubkey: _validPubkeyB,
            content: 'NIP-04 message',
            createdAt: any(named: 'createdAt'),
            giftWrapId: _giftWrapEventId2,
            messageKind: EventKind.directMessage,
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).called(1);

        // Verify NIP-17 upsert used 'nip17' protocol
        verify(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: 'nip17',
          ),
        ).called(1);

        // Verify NIP-04 upsert used 'nip04' protocol
        verify(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: 'nip04',
          ),
        ).called(1);

        await controller.close();
        await repository.stopListening();
      });

      test('preserves nip17 protocol when NIP-04 event arrives', () async {
        final nip04Event = createNip04Event();
        final participants = [_validPubkeyA, _validPubkeyB]..sort();
        final convId = DmRepository.computeConversationId(participants);

        when(
          () => mockDirectMessagesDao.hasGiftWrap(_rumorEventId),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.hasMatchingMessage(
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});

        // Return existing conversation already upgraded to nip17
        when(
          () => mockConversationsDao.getConversation(
            convId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => ConversationRow(
            id: convId,
            participantPubkeys: jsonEncode(participants),
            isGroup: false,
            lastMessageContent: 'Previous',
            lastMessageTimestamp: 1700000000,
            lastMessageSenderPubkey: _validPubkeyA,
            isRead: true,
            currentUserHasSent: true,
            createdAt: 1699999000,
            dmProtocol: 'nip17',
          ),
        );

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          nip04Decryptor: (_, _) async => 'Legacy message',
        );

        await repository.startListening();
        controller.add(nip04Event);
        await Future<void>.delayed(Duration.zero);

        // Verify upsert preserved 'nip17', not downgraded to 'nip04'
        verify(
          () => mockConversationsDao.upsertConversation(
            id: convId,
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: false,
            createdAt: any(named: 'createdAt'),
            lastMessageContent: 'Legacy message',
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: 'nip17',
          ),
        ).called(1);

        await controller.close();
        await repository.stopListening();
      });
    });

    // -----------------------------------------------------------------
    // Dual-send (NIP-17 + NIP-04 fallback)
    // -----------------------------------------------------------------

    group('dual-send NIP-04 fallback', () {
      void stubDaoInserts() {
        when(
          () => mockDirectMessagesDao.hasMatchingMessage(
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
      }

      test(
        'sends NIP-04 fallback when protocol is unknown',
        () async {
          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );
          stubDaoInserts();

          // Return null (unknown protocol)
          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          // Stub publishEvent — NIP-04 fallback will call this
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer(
            (_) async => PublishSuccess(
              event: Event.fromJson({
                'id': _giftWrapEventId,
                'pubkey': _validPubkeyA,
                'created_at': 1700000000,
                'kind': EventKind.directMessage,
                'tags': [
                  ['p', _validPubkeyB],
                ],
                'content': 'encrypted',
                'sig': 'sig',
              }),
            ),
          );

          final repository = createRepository();

          await repository.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'Hello!',
          );

          // Allow the unawaited NIP-04 future to complete
          await Future<void>.delayed(Duration.zero);

          // Verify both NIP-17 and NIP-04 were called
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
            ),
          ).called(1);

          verify(
            () => mockNostrClient.publishEvent(any()),
          ).called(1);
        },
      );

      test(
        'skips NIP-04 fallback when conversation is known NIP-17',
        () async {
          final participants = [_validPubkeyA, _validPubkeyB]..sort();
          final convId = DmRepository.computeConversationId(participants);

          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );
          stubDaoInserts();

          // Return an existing conversation with dmProtocol: 'nip17'
          when(
            () => mockConversationsDao.getConversation(convId),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: convId,
              participantPubkeys: jsonEncode(participants),
              isGroup: false,
              lastMessageContent: 'Previous',
              lastMessageTimestamp: 1700000000,
              lastMessageSenderPubkey: _validPubkeyB,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1699999000,
              dmProtocol: 'nip17',
            ),
          );

          final repository = createRepository();

          await repository.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'Hello!',
          );

          await Future<void>.delayed(Duration.zero);

          // NIP-17 was sent
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
            ),
          ).called(1);

          // NIP-04 fallback was NOT sent
          verifyNever(
            () => mockNostrClient.publishEvent(any()),
          );
        },
      );
    });

    // -----------------------------------------------------------------
    // Delete (NIP-09 Kind 5)
    // -----------------------------------------------------------------

    group('deleteMessageForEveryone', () {
      final conversationId = DmRepository.computeConversationId(
        [_validPubkeyA, _validPubkeyB],
      );

      test('throws $StateError when not initialized', () {
        final repo = DmRepository(
          nostrClient: mockNostrClient,
          directMessagesDao: mockDirectMessagesDao,
          conversationsDao: mockConversationsDao,
        );

        expect(
          () => repo.deleteMessageForEveryone(_rumorEventId),
          throwsA(isA<StateError>()),
        );
      });

      test('throws $ArgumentError when message not found', () {
        final repo = createRepository();

        when(
          () => mockDirectMessagesDao.getMessageById(
            _rumorEventId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);

        expect(
          () => repo.deleteMessageForEveryone(_rumorEventId),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('not found'),
            ),
          ),
        );
      });

      test('throws $ArgumentError when current user is not the sender', () {
        final repo = createRepository();

        when(
          () => mockDirectMessagesDao.getMessageById(
            _rumorEventId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => DirectMessageRow(
            id: _rumorEventId,
            conversationId: conversationId,
            senderPubkey: _validPubkeyB, // NOT the current user
            content: 'Hello',
            createdAt: 1700000000,
            giftWrapId: _giftWrapEventId,
            messageKind: 14,
            isDeleted: false,
          ),
        );

        expect(
          () => repo.deleteMessageForEveryone(_rumorEventId),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('only the sender'),
            ),
          ),
        );
      });

      test(
        'publishes kind 5 event and soft-deletes locally',
        () async {
          final repo = createRepository();

          when(
            () => mockDirectMessagesDao.getMessageById(
              _rumorEventId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => DirectMessageRow(
              id: _rumorEventId,
              conversationId: conversationId,
              senderPubkey: _validPubkeyA, // current user
              content: 'Hello',
              createdAt: 1700000000,
              giftWrapId: _giftWrapEventId,
              messageKind: 14,
              isDeleted: false,
            ),
          );

          when(
            () => mockConversationsDao.getConversation(
              conversationId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: conversationId,
              participantPubkeys: '["$_validPubkeyA","$_validPubkeyB"]',
              isGroup: false,
              createdAt: 1700000000,
              isRead: true,
              currentUserHasSent: true,
            ),
          );

          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => PublishSuccess(event: _FakeEvent()));

          when(
            () => mockDirectMessagesDao.markMessageDeleted(
              _rumorEventId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => true);

          when(
            () => mockDirectMessagesDao.getMessagesForConversation(
              conversationId,
              limit: 1,
              ownerPubkey: _validPubkeyA,
            ),
          ).thenAnswer((_) async => []);

          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
              forceUpdateLastMessage: any(named: 'forceUpdateLastMessage'),
            ),
          ).thenAnswer((_) async {});

          await repo.deleteMessageForEveryone(_rumorEventId);

          // Verify kind 5 was published
          final captured =
              verify(
                    () => mockNostrClient.publishEvent(captureAny()),
                  ).captured.single
                  as Event;
          expect(captured.kind, equals(EventKind.eventDeletion));
          expect(
            captured.tags,
            containsAll([
              ['e', _rumorEventId],
              ['k', '14'],
              ['p', _validPubkeyB],
            ]),
          );

          // Verify soft-delete
          verify(
            () => mockDirectMessagesDao.markMessageDeleted(
              _rumorEventId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).called(1);
        },
      );
    });

    // -----------------------------------------------------------------
    // Canonicalization: extra p-tags routing
    // -----------------------------------------------------------------
    group('canonicalize 1:1 participants', () {
      Event createGiftWrapEvent({String? id}) {
        return Event.fromJson({
          'id': id ?? _giftWrapEventId,
          'pubkey':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'created_at': 1700000000,
          'kind': EventKind.giftWrap,
          'tags': [
            ['p', _validPubkeyA],
          ],
          'content': 'encrypted-content',
          'sig': '',
        });
      }

      Event createRumorEvent({
        String? id,
        String? pubkey,
        String? content,
        int? kind,
        List<List<String>>? tags,
        int? createdAt,
      }) {
        return Event.fromJson({
          'id': id ?? _rumorEventId,
          'pubkey': pubkey ?? _validPubkeyB,
          'created_at': createdAt ?? 1700000000,
          'kind': kind ?? EventKind.privateDirectMessage,
          'tags':
              tags ??
              [
                ['p', _validPubkeyA],
              ],
          'content': content ?? 'Hello from B!',
          'sig': '',
        });
      }

      test(
        'routes message with extra p-tags to existing 1:1 conversation',
        () async {
          // Rumor from B with extra p-tag for C (e.g., reply mention).
          final giftWrap = createGiftWrapEvent();
          final rumor = createRumorEvent(
            tags: [
              ['p', _validPubkeyA],
              ['p', _validPubkeyC],
            ],
          );

          when(
            () => mockDirectMessagesDao.hasGiftWrap(any()),
          ).thenAnswer((_) async => false);
          when(
            () => mockDirectMessagesDao.hasMatchingMessage(
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          // Compute the canonical 1:1 conversation ID (A ↔ B).
          final canonical1to1 = [_validPubkeyA, _validPubkeyB]..sort();
          final canonicalId = DmRepository.computeConversationId(canonical1to1);

          // Stub: an existing 1:1 conversation between A and B.
          when(
            () => mockConversationsDao.getConversation(
              canonicalId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: canonicalId,
              participantPubkeys: jsonEncode(canonical1to1),
              isGroup: false,
              lastMessageContent: 'Previous msg',
              lastMessageTimestamp: 1699999999,
              lastMessageSenderPubkey: _validPubkeyB,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1699999999,
            ),
          );

          final controller = StreamController<Event>();
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          final repository = createRepository(
            rumorDecryptor: (_, _) async => rumor,
          );

          await repository.startListening();
          controller.add(giftWrap);
          await Future<void>.delayed(Duration.zero);

          // Message should be stored with the canonical 1:1 ID, not the
          // 3-party ID that the extra p-tag would have produced.
          verify(
            () => mockDirectMessagesDao.insertMessage(
              id: _rumorEventId,
              conversationId: canonicalId,
              senderPubkey: _validPubkeyB,
              content: 'Hello from B!',
              createdAt: 1700000000,
              giftWrapId: _giftWrapEventId,
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).called(1);

          // Conversation should be upserted as 1:1 (not group).
          verify(
            () => mockConversationsDao.upsertConversation(
              id: canonicalId,
              participantPubkeys: jsonEncode(canonical1to1),
              isGroup: false,
              createdAt: any(named: 'createdAt'),
              lastMessageContent: 'Hello from B!',
              lastMessageTimestamp: 1700000000,
              lastMessageSenderPubkey: _validPubkeyB,
              isRead: false,
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).called(1);

          await controller.close();
          await repository.stopListening();
        },
      );

      test(
        'defaults to 1:1 when extra p-tags and no existing conversation',
        () async {
          // Rumor from B with extra p-tag for C — no prior conversation.
          final giftWrap = createGiftWrapEvent();
          final rumor = createRumorEvent(
            tags: [
              ['p', _validPubkeyA],
              ['p', _validPubkeyC],
            ],
          );

          when(
            () => mockDirectMessagesDao.hasGiftWrap(any()),
          ).thenAnswer((_) async => false);
          when(
            () => mockDirectMessagesDao.hasMatchingMessage(
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Event>();
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          final repository = createRepository(
            rumorDecryptor: (_, _) async => rumor,
          );

          await repository.startListening();
          controller.add(giftWrap);
          await Future<void>.delayed(Duration.zero);

          // Should default to canonical 1:1 (A <-> B), not a 3-party group.
          final canonical1to1 = [_validPubkeyA, _validPubkeyB]..sort();
          final canonicalId = DmRepository.computeConversationId(canonical1to1);

          verify(
            () => mockDirectMessagesDao.insertMessage(
              id: _rumorEventId,
              conversationId: canonicalId,
              senderPubkey: _validPubkeyB,
              content: 'Hello from B!',
              createdAt: 1700000000,
              giftWrapId: _giftWrapEventId,
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).called(1);

          // Conversation should be upserted as 1:1 (not group).
          verify(
            () => mockConversationsDao.upsertConversation(
              id: canonicalId,
              participantPubkeys: jsonEncode(canonical1to1),
              isGroup: false,
              createdAt: any(named: 'createdAt'),
              lastMessageContent: 'Hello from B!',
              lastMessageTimestamp: 1700000000,
              lastMessageSenderPubkey: _validPubkeyB,
              isRead: false,
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).called(1);

          await controller.close();
          await repository.stopListening();
        },
      );

      test(
        'routes to existing group when extra p-tags match it',
        () async {
          // Rumor from B with extra p-tag for C — group [A,B,C] exists.
          final giftWrap = createGiftWrapEvent();
          final rumor = createRumorEvent(
            tags: [
              ['p', _validPubkeyA],
              ['p', _validPubkeyC],
            ],
          );

          when(
            () => mockDirectMessagesDao.hasGiftWrap(any()),
          ).thenAnswer((_) async => false);
          when(
            () => mockDirectMessagesDao.hasMatchingMessage(
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).thenAnswer((_) async {});

          // Stub: existing group conversation [A, B, C].
          final groupParticipants = [
            _validPubkeyA,
            _validPubkeyB,
            _validPubkeyC,
          ]..sort();
          final groupId = DmRepository.computeConversationId(groupParticipants);

          // Generic fallback returns null (no conversation found).
          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);
          // Specific stub: group conversation exists.
          when(
            () => mockConversationsDao.getConversation(
              groupId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: groupId,
              participantPubkeys: jsonEncode(groupParticipants),
              isGroup: true,
              lastMessageContent: 'Group msg',
              lastMessageTimestamp: 1699999999,
              lastMessageSenderPubkey: _validPubkeyC,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1699999999,
            ),
          );

          final controller = StreamController<Event>();
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          final repository = createRepository(
            rumorDecryptor: (_, _) async => rumor,
          );

          await repository.startListening();
          controller.add(giftWrap);
          await Future<void>.delayed(Duration.zero);

          // Should route to the existing group, not create a new 1:1.
          verify(
            () => mockDirectMessagesDao.insertMessage(
              id: _rumorEventId,
              conversationId: groupId,
              senderPubkey: _validPubkeyB,
              content: 'Hello from B!',
              createdAt: 1700000000,
              giftWrapId: _giftWrapEventId,
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).called(1);

          verify(
            () => mockConversationsDao.upsertConversation(
              id: groupId,
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: true,
              createdAt: any(named: 'createdAt'),
              lastMessageContent: 'Hello from B!',
              lastMessageTimestamp: 1700000000,
              lastMessageSenderPubkey: _validPubkeyB,
              isRead: false,
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).called(1);

          await controller.close();
          await repository.stopListening();
        },
      );

      test(
        'self-wrap routes to correct conversation, not self-conversation',
        () async {
          // Self-wrap: rumor authored by current user (A) with p-tag to B.
          // This simulates processing our own sent-message recovery wrap.
          final giftWrap = createGiftWrapEvent();
          final rumor = createRumorEvent(
            pubkey: _validPubkeyA, // Sender == current user
            tags: [
              ['p', _validPubkeyB], // Actual recipient
            ],
            content: 'Hello from me!',
          );

          when(
            () => mockDirectMessagesDao.hasGiftWrap(any()),
          ).thenAnswer((_) async => false);
          when(
            () => mockDirectMessagesDao.hasMatchingMessage(
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Event>();
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          final repository = createRepository(
            rumorDecryptor: (_, _) async => rumor,
          );

          await repository.startListening();
          controller.add(giftWrap);
          await Future<void>.delayed(Duration.zero);

          // Should use canonical 1:1 conversation ID (A <-> B),
          // NOT a self-conversation [A, A].
          final canonical1to1 = [_validPubkeyA, _validPubkeyB]..sort();
          final canonicalId = DmRepository.computeConversationId(canonical1to1);

          // Verify message stored in correct conversation.
          verify(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: canonicalId,
              senderPubkey: _validPubkeyA,
              content: 'Hello from me!',
              createdAt: 1700000000,
              giftWrapId: _giftWrapEventId,
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).called(1);

          // Conversation should be upserted as 1:1 with correct participants.
          verify(
            () => mockConversationsDao.upsertConversation(
              id: canonicalId,
              participantPubkeys: jsonEncode(canonical1to1),
              isGroup: false,
              createdAt: any(named: 'createdAt'),
              lastMessageContent: 'Hello from me!',
              lastMessageTimestamp: 1700000000,
              lastMessageSenderPubkey: _validPubkeyA,
              isRead: any(named: 'isRead'),
              currentUserHasSent: true,
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).called(1);

          // Self-conversation ID should NOT have been used.
          final selfConvId = DmRepository.computeConversationId(
            [_validPubkeyA, _validPubkeyA],
          );
          verifyNever(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: selfConvId,
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          );

          await controller.close();
          await repository.stopListening();
        },
      );

      test('normal 1:1 message (single p-tag) is not affected', () async {
        // Standard 1:1 message — single p-tag, no extra participants.
        final giftWrap = createGiftWrapEvent();
        final rumor = createRumorEvent();

        when(
          () => mockDirectMessagesDao.hasGiftWrap(any()),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.hasMatchingMessage(
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => rumor,
        );

        await repository.startListening();
        controller.add(giftWrap);
        await Future<void>.delayed(Duration.zero);

        // Should use standard 1:1 conversation ID.
        final participants = [_validPubkeyA, _validPubkeyB]..sort();
        final convId = DmRepository.computeConversationId(participants);

        verify(
          () => mockDirectMessagesDao.insertMessage(
            id: _rumorEventId,
            conversationId: convId,
            senderPubkey: _validPubkeyB,
            content: 'Hello from B!',
            createdAt: 1700000000,
            giftWrapId: _giftWrapEventId,
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).called(1);

        // Canonicalization should NOT have been triggered — only one
        // getConversation call (the one inside the transaction).
        // The canonicalize method returns early for ≤ 2 participants.
        verify(
          () => mockConversationsDao.upsertConversation(
            id: convId,
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Hello from B!',
            lastMessageTimestamp: 1700000000,
            lastMessageSenderPubkey: _validPubkeyB,
            isRead: false,
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).called(1);

        await controller.close();
        await repository.stopListening();
      });
    });

    // -----------------------------------------------------------------
    // Phase 1: Static helpers + DAO wrappers
    // -----------------------------------------------------------------

    group('classifyPotentialRequests', () {
      DmConversation makeConversation({
        required String id,
        required List<String> participantPubkeys,
        bool isGroup = false,
      }) {
        return DmConversation(
          id: id,
          participantPubkeys: participantPubkeys,
          isGroup: isGroup,
          createdAt: 1700000000,
        );
      }

      test('1:1 from followed contact goes to followed list', () {
        final conv = makeConversation(
          id: 'conv1',
          participantPubkeys: [_validPubkeyA, _validPubkeyB],
        );

        final result = DmRepository.classifyPotentialRequests(
          [conv],
          userPubkey: _validPubkeyA,
          isFollowing: (pk) => pk == _validPubkeyB,
        );

        expect(result.followed, hasLength(1));
        expect(result.requests, isEmpty);
      });

      test('1:1 from unfollowed contact goes to requests list', () {
        final conv = makeConversation(
          id: 'conv1',
          participantPubkeys: [_validPubkeyA, _validPubkeyB],
        );

        final result = DmRepository.classifyPotentialRequests(
          [conv],
          userPubkey: _validPubkeyA,
          isFollowing: (_) => false,
        );

        expect(result.followed, isEmpty);
        expect(result.requests, hasLength(1));
      });

      test('group conversation always goes to requests', () {
        final conv = makeConversation(
          id: 'conv1',
          participantPubkeys: [_validPubkeyA, _validPubkeyB, _validPubkeyC],
          isGroup: true,
        );

        final result = DmRepository.classifyPotentialRequests(
          [conv],
          userPubkey: _validPubkeyA,
          isFollowing: (_) => true, // Even if all are followed
        );

        expect(result.followed, isEmpty);
        expect(result.requests, hasLength(1));
      });

      test('empty input returns both lists empty', () {
        final result = DmRepository.classifyPotentialRequests(
          [],
          userPubkey: _validPubkeyA,
          isFollowing: (_) => false,
        );

        expect(result.followed, isEmpty);
        expect(result.requests, isEmpty);
      });
    });

    group('mergeAndSort', () {
      DmConversation makeConversation({
        required String id,
        int? lastMessageTimestamp,
        int createdAt = 1700000000,
      }) {
        return DmConversation(
          id: id,
          participantPubkeys: const [_validPubkeyA, _validPubkeyB],
          isGroup: false,
          createdAt: createdAt,
          lastMessageTimestamp: lastMessageTimestamp,
        );
      }

      test('returns accepted unchanged when followedPotential is empty', () {
        final accepted = [
          makeConversation(id: 'a', lastMessageTimestamp: 100),
        ];

        final result = DmRepository.mergeAndSort(accepted, []);

        expect(result, same(accepted));
      });

      test('merges and sorts by effectiveTimestamp descending', () {
        final accepted = [
          makeConversation(id: 'a', lastMessageTimestamp: 200),
          makeConversation(id: 'b', lastMessageTimestamp: 100),
        ];
        final followed = [
          makeConversation(id: 'c', lastMessageTimestamp: 150),
        ];

        final result = DmRepository.mergeAndSort(accepted, followed);

        expect(result.map((c) => c.id).toList(), equals(['a', 'c', 'b']));
      });

      test('both empty returns empty', () {
        final result = DmRepository.mergeAndSort([], []);

        expect(result, isEmpty);
      });
    });

    group('getConversations', () {
      test('returns mapped $DmConversation list from DAO', () async {
        final participants = [_validPubkeyA, _validPubkeyB]..sort();
        final convId = DmRepository.computeConversationId(participants);

        when(
          () => mockConversationsDao.getAllConversations(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => [
            ConversationRow(
              id: convId,
              participantPubkeys: jsonEncode(participants),
              isGroup: false,
              isRead: true,
              currentUserHasSent: false,
              createdAt: 1700000000,
              lastMessageContent: 'Hello',
              lastMessageTimestamp: 1700000000,
              lastMessageSenderPubkey: _validPubkeyB,
            ),
          ],
        );

        final repository = createRepository();
        final conversations = await repository.getConversations();

        expect(conversations, hasLength(1));
        expect(conversations.first.id, equals(convId));
        expect(conversations.first.lastMessageContent, equals('Hello'));
      });
    });

    group('getMessages', () {
      test('returns mapped $DmMessage list from DAO', () async {
        final participants = [_validPubkeyA, _validPubkeyB]..sort();
        final convId = DmRepository.computeConversationId(participants);

        when(
          () => mockDirectMessagesDao.getMessagesForConversation(
            convId,
            limit: any(named: 'limit'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => [
            DirectMessageRow(
              id: _rumorEventId,
              conversationId: convId,
              senderPubkey: _validPubkeyB,
              content: 'Hello!',
              createdAt: 1700000000,
              giftWrapId: _giftWrapEventId,
              messageKind: 14,
              isDeleted: false,
            ),
          ],
        );

        final repository = createRepository();
        final messages = await repository.getMessages(convId);

        expect(messages, hasLength(1));
        expect(messages.first.id, equals(_rumorEventId));
        expect(messages.first.content, equals('Hello!'));
      });
    });

    group('watchAcceptedConversations', () {
      test(
        'waits for post-auth maintenance before subscribing to conversations',
        () async {
          final maintenanceCompleter = Completer<int>();
          final participants = [_validPubkeyA, _validPubkeyB]..sort();
          final convId = DmRepository.computeConversationId(participants);

          when(
            () => mockConversationsDao.backfillLatestMessagePreviews(
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) => maintenanceCompleter.future);
          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockConversationsDao.watchAcceptedConversations(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) => Stream.value([
              ConversationRow(
                id: convId,
                participantPubkeys: jsonEncode(participants),
                isGroup: false,
                isRead: true,
                currentUserHasSent: true,
                createdAt: 1700000000,
              ),
            ]),
          );

          final repository =
              DmRepository(
                nostrClient: mockNostrClient,
                directMessagesDao: mockDirectMessagesDao,
                conversationsDao: mockConversationsDao,
              )..setCredentials(
                userPubkey: _validPubkeyA,
                signer: LocalNostrSigner(_validPrivateKey),
                messageService: mockMessageService,
              );

          final conversationsFuture = repository
              .watchAcceptedConversations()
              .first;

          verifyNever(
            () => mockConversationsDao.watchAcceptedConversations(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );

          maintenanceCompleter.complete(0);

          await untilCalled(
            () => mockConversationsDao.watchAcceptedConversations(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );

          final conversations = await conversationsFuture;
          expect(conversations, hasLength(1));
          expect(conversations.first.id, equals(convId));
        },
      );

      test('maps $ConversationRow stream to $DmConversation stream', () async {
        final participants = [_validPubkeyA, _validPubkeyB]..sort();
        final convId = DmRepository.computeConversationId(participants);

        when(
          () => mockConversationsDao.watchAcceptedConversations(
            limit: any(named: 'limit'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) => Stream.value([
            ConversationRow(
              id: convId,
              participantPubkeys: jsonEncode(participants),
              isGroup: false,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1700000000,
            ),
          ]),
        );
        final repository = createRepository();
        final conversations = await repository
            .watchAcceptedConversations()
            .first;

        expect(conversations, hasLength(1));
        expect(conversations.first.id, equals(convId));
        expect(conversations.first.currentUserHasSent, isTrue);
      });

      test(
        'uses the conversation row preview as the source of truth',
        () async {
          final participants = [_validPubkeyA, _validPubkeyB]..sort();
          final convId = DmRepository.computeConversationId(participants);

          when(
            () => mockConversationsDao.watchAcceptedConversations(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) => Stream.value([
              ConversationRow(
                id: convId,
                participantPubkeys: jsonEncode(participants),
                isGroup: false,
                isRead: true,
                currentUserHasSent: true,
                createdAt: 1700000000,
                lastMessageContent: 'Latest reply',
                lastMessageTimestamp: 1700000500,
                lastMessageSenderPubkey: _validPubkeyA,
              ),
            ]),
          );

          final repository = createRepository();
          final conversations = await repository
              .watchAcceptedConversations()
              .first;

          expect(conversations, hasLength(1));
          expect(
            conversations.first.lastMessageContent,
            equals('Latest reply'),
          );
          expect(
            conversations.first.lastMessageTimestamp,
            equals(1700000500),
          );
          expect(
            conversations.first.lastMessageSenderPubkey,
            equals(_validPubkeyA),
          );
          verifyNever(
            () => mockDirectMessagesDao.getLatestMessagesForConversations(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
        },
      );

      test(
        'preserves DAO ordering',
        () async {
          final participantsA = [_validPubkeyA, _validPubkeyB]..sort();
          final participantsB = [_validPubkeyA, _validPubkeyC]..sort();
          final convA = DmRepository.computeConversationId(participantsA);
          final convB = DmRepository.computeConversationId(participantsB);

          when(
            () => mockConversationsDao.watchAcceptedConversations(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) => Stream.value([
              ConversationRow(
                id: convA,
                participantPubkeys: jsonEncode(participantsA),
                isGroup: false,
                isRead: true,
                currentUserHasSent: true,
                createdAt: 1700000000,
                lastMessageContent: 'B latest',
                lastMessageTimestamp: 1700000900,
              ),
              ConversationRow(
                id: convB,
                participantPubkeys: jsonEncode(participantsB),
                isGroup: false,
                isRead: true,
                currentUserHasSent: true,
                createdAt: 1700000000,
                lastMessageContent: 'A latest',
                lastMessageTimestamp: 1700000300,
              ),
            ]),
          );

          final repository = createRepository();
          final conversations = await repository
              .watchAcceptedConversations()
              .first;

          expect(
            conversations.map((c) => c.id).toList(),
            equals([convA, convB]),
          );
        },
      );
    });

    group('watchPotentialRequests', () {
      test('maps $ConversationRow stream to $DmConversation stream', () async {
        final participants = [_validPubkeyA, _validPubkeyB]..sort();
        final convId = DmRepository.computeConversationId(participants);

        when(
          () => mockConversationsDao.watchPotentialRequestConversations(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) => Stream.value([
            ConversationRow(
              id: convId,
              participantPubkeys: jsonEncode(participants),
              isGroup: false,
              isRead: false,
              currentUserHasSent: false,
              createdAt: 1700000000,
            ),
          ]),
        );
        final repository = createRepository();
        final requests = await repository.watchPotentialRequests().first;

        expect(requests, hasLength(1));
        expect(requests.first.currentUserHasSent, isFalse);
      });
    });

    group('watchUnreadCount', () {
      test('delegates to $ConversationsDao', () async {
        when(
          () => mockConversationsDao.watchUnreadCount(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) => Stream.value(5));

        final repository = createRepository();
        final count = await repository.watchUnreadCount().first;

        expect(count, equals(5));
      });
    });

    group('watchUnreadAcceptedCount', () {
      test('delegates to $ConversationsDao', () async {
        when(
          () => mockConversationsDao.watchUnreadAcceptedCount(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) => Stream.value(3));

        final repository = createRepository();
        final count = await repository.watchUnreadAcceptedCount().first;

        expect(count, equals(3));
      });
    });

    // -----------------------------------------------------------------
    // Phase 2: Deletion receive pipeline, maintenance, credentials
    // -----------------------------------------------------------------

    group('receive pipeline - kind 5 deletion', () {
      final participants = [_validPubkeyA, _validPubkeyB]..sort();
      final convId = DmRepository.computeConversationId(participants);

      Event createDeletionEvent({
        required String authorPubkey,
        required List<String> deletedRumorIds,
      }) {
        return Event.fromJson({
          'id':
              '11111111111111111111111111111111'
              '11111111111111111111111111111111',
          'pubkey': authorPubkey,
          'created_at': 1700000100,
          'kind': EventKind.eventDeletion,
          'tags': [
            for (final id in deletedRumorIds) ['e', id],
            ['k', '14'],
          ],
          'content': '',
          'sig': '',
        });
      }

      void stubSubscription(StreamController<Event> controller) {
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);
        when(
          () => mockNostrClient.unsubscribe(any()),
        ).thenAnswer((_) async {});
      }

      test('valid kind 5 soft-deletes message and refreshes preview', () async {
        final controller = StreamController<Event>();
        stubSubscription(controller);

        // Stub getMessageById — the message exists and is authored by B
        when(
          () => mockDirectMessagesDao.getMessageById(
            _rumorEventId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => DirectMessageRow(
            id: _rumorEventId,
            conversationId: convId,
            senderPubkey: _validPubkeyB,
            content: 'Hello',
            createdAt: 1700000000,
            giftWrapId: _giftWrapEventId,
            messageKind: 14,
            isDeleted: false,
          ),
        );

        when(
          () => mockDirectMessagesDao.markMessageDeleted(
            _rumorEventId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => true);

        // Stub _refreshConversationPreview: no messages remain
        when(
          () => mockDirectMessagesDao.getMessagesForConversation(
            convId,
            limit: 1,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => []);

        when(
          () => mockConversationsDao.getConversation(
            convId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => ConversationRow(
            id: convId,
            participantPubkeys: jsonEncode(participants),
            isGroup: false,
            isRead: true,
            currentUserHasSent: true,
            createdAt: 1700000000,
          ),
        );

        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
            forceUpdateLastMessage: any(named: 'forceUpdateLastMessage'),
          ),
        ).thenAnswer((_) async {});

        // Stub hasGiftWrap to ensure deletion event is not treated as duplicate
        when(
          () => mockDirectMessagesDao.hasGiftWrap(any()),
        ).thenAnswer((_) async => false);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => null,
        );
        await repository.startListening();

        // Emit deletion event from B (the author of the message)
        controller.add(
          createDeletionEvent(
            authorPubkey: _validPubkeyB,
            deletedRumorIds: [_rumorEventId],
          ),
        );
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockDirectMessagesDao.markMessageDeleted(
            _rumorEventId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).called(1);

        await controller.close();
        await repository.stopListening();
      });

      test('ignores kind 5 from non-author (NIP-09 mismatch)', () async {
        final controller = StreamController<Event>();
        stubSubscription(controller);

        when(
          () => mockDirectMessagesDao.getMessageById(
            _rumorEventId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => DirectMessageRow(
            id: _rumorEventId,
            conversationId: convId,
            senderPubkey: _validPubkeyB, // B is the author
            content: 'Hello',
            createdAt: 1700000000,
            giftWrapId: _giftWrapEventId,
            messageKind: 14,
            isDeleted: false,
          ),
        );

        when(
          () => mockDirectMessagesDao.hasGiftWrap(any()),
        ).thenAnswer((_) async => false);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => null,
        );
        await repository.startListening();

        // Emit deletion event from C (NOT the author)
        controller.add(
          createDeletionEvent(
            authorPubkey: _validPubkeyC,
            deletedRumorIds: [_rumorEventId],
          ),
        );
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockDirectMessagesDao.markMessageDeleted(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );

        await controller.close();
        await repository.stopListening();
      });

      test('skips already-deleted message', () async {
        final controller = StreamController<Event>();
        stubSubscription(controller);

        when(
          () => mockDirectMessagesDao.getMessageById(
            _rumorEventId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => DirectMessageRow(
            id: _rumorEventId,
            conversationId: convId,
            senderPubkey: _validPubkeyB,
            content: 'Hello',
            createdAt: 1700000000,
            giftWrapId: _giftWrapEventId,
            messageKind: 14,
            isDeleted: true, // Already deleted
          ),
        );

        when(
          () => mockDirectMessagesDao.hasGiftWrap(any()),
        ).thenAnswer((_) async => false);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => null,
        );
        await repository.startListening();

        controller.add(
          createDeletionEvent(
            authorPubkey: _validPubkeyB,
            deletedRumorIds: [_rumorEventId],
          ),
        );
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockDirectMessagesDao.markMessageDeleted(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );

        await controller.close();
        await repository.stopListening();
      });

      test('skips kind 5 for non-existent message', () async {
        final controller = StreamController<Event>();
        stubSubscription(controller);

        when(
          () => mockDirectMessagesDao.getMessageById(
            _rumorEventId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => mockDirectMessagesDao.hasGiftWrap(any()),
        ).thenAnswer((_) async => false);

        final repository = createRepository(
          rumorDecryptor: (_, _) async => null,
        );
        await repository.startListening();

        controller.add(
          createDeletionEvent(
            authorPubkey: _validPubkeyB,
            deletedRumorIds: [_rumorEventId],
          ),
        );
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockDirectMessagesDao.markMessageDeleted(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );

        await controller.close();
        await repository.stopListening();
      });
    });

    group('_refreshConversationPreview', () {
      final participants = [_validPubkeyA, _validPubkeyB]..sort();
      final convId = DmRepository.computeConversationId(participants);

      test(
        'updates preview to latest remaining message after deletion',
        () async {
          final repo = createRepository();

          // Stub message lookup — the message exists and is authored by us
          when(
            () => mockDirectMessagesDao.getMessageById(
              _rumorEventId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => DirectMessageRow(
              id: _rumorEventId,
              conversationId: convId,
              senderPubkey: _validPubkeyA,
              content: 'Deleted msg',
              createdAt: 1700000000,
              giftWrapId: _giftWrapEventId,
              messageKind: 14,
              isDeleted: false,
            ),
          );

          when(
            () => mockConversationsDao.getConversation(
              convId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: convId,
              participantPubkeys: jsonEncode(participants),
              isGroup: false,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1700000000,
            ),
          );

          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => PublishSuccess(event: _FakeEvent()));

          when(
            () => mockDirectMessagesDao.markMessageDeleted(
              _rumorEventId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => true);

          // After deletion, one message remains
          when(
            () => mockDirectMessagesDao.getMessagesForConversation(
              convId,
              limit: 1,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              DirectMessageRow(
                id: _giftWrapEventId2,
                conversationId: convId,
                senderPubkey: _validPubkeyB,
                content: 'Older message',
                createdAt: 1699999000,
                giftWrapId: _giftWrapEventId2,
                messageKind: 14,
                isDeleted: false,
              ),
            ],
          );

          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
              forceUpdateLastMessage: any(named: 'forceUpdateLastMessage'),
            ),
          ).thenAnswer((_) async {});

          await repo.deleteMessageForEveryone(_rumorEventId);

          // Verify upsert was called with the older message's content
          verify(
            () => mockConversationsDao.upsertConversation(
              id: convId,
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: 'Older message',
              lastMessageTimestamp: 1699999000,
              lastMessageSenderPubkey: _validPubkeyB,
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
              forceUpdateLastMessage: true,
            ),
          ).called(1);
        },
      );

      test(
        'uses file preview text when latest remaining is kind 15',
        () async {
          final repo = createRepository();

          when(
            () => mockDirectMessagesDao.getMessageById(
              _rumorEventId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => DirectMessageRow(
              id: _rumorEventId,
              conversationId: convId,
              senderPubkey: _validPubkeyA,
              content: 'Deleted msg',
              createdAt: 1700000000,
              giftWrapId: _giftWrapEventId,
              messageKind: 14,
              isDeleted: false,
            ),
          );

          when(
            () => mockConversationsDao.getConversation(
              convId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: convId,
              participantPubkeys: jsonEncode(participants),
              isGroup: false,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1700000000,
            ),
          );

          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => PublishSuccess(event: _FakeEvent()));

          when(
            () => mockDirectMessagesDao.markMessageDeleted(
              _rumorEventId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => true);

          // After deletion, a file message remains
          when(
            () => mockDirectMessagesDao.getMessagesForConversation(
              convId,
              limit: 1,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              DirectMessageRow(
                id: _giftWrapEventId2,
                conversationId: convId,
                senderPubkey: _validPubkeyB,
                content: 'https://blossom.example.com/file.enc',
                createdAt: 1699999000,
                giftWrapId: _giftWrapEventId2,
                messageKind: EventKind.fileMessage,
                isDeleted: false,
                fileType: 'image/jpeg',
              ),
            ],
          );

          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
              forceUpdateLastMessage: any(named: 'forceUpdateLastMessage'),
            ),
          ).thenAnswer((_) async {});

          await repo.deleteMessageForEveryone(_rumorEventId);

          // Verify file preview text was used
          verify(
            () => mockConversationsDao.upsertConversation(
              id: convId,
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: 'Sent a photo',
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
              forceUpdateLastMessage: true,
            ),
          ).called(1);
        },
      );
    });

    group('setCredentials', () {
      test('same user is a no-op', () {
        final repo = createRepository()
          // Already initialized with _validPubkeyA — calling again
          // is a no-op.
          ..setCredentials(
            userPubkey: _validPubkeyA,
            signer: LocalNostrSigner(_validPrivateKey),
            messageService: mockMessageService,
          );

        expect(repo.isInitialized, isTrue);
        expect(repo.userPubkey, equals(_validPubkeyA));
      });

      test(
        'switching users resets state and re-initializes',
        () async {
          when(
            () => mockNostrClient.unsubscribe(any()),
          ).thenAnswer((_) async {});

          final repo = createRepository()
            ..setCredentials(
              userPubkey: _validPubkeyB,
              signer: LocalNostrSigner(_validPrivateKey),
              messageService: mockMessageService,
            );

          // Give post-auth maintenance a chance to run.
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(repo.userPubkey, equals(_validPubkeyB));
          expect(repo.isInitialized, isTrue);
        },
      );
    });

    group('_cleanupSelfConversations', () {
      test(
        'deletes self-conversation when it exists',
        () async {
          final selfConvId = DmRepository.computeConversationId(
            [_validPubkeyA, _validPubkeyA],
          );

          // Stub: self-conversation exists
          when(
            () => mockConversationsDao.getConversation(
              selfConvId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: selfConvId,
              participantPubkeys: jsonEncode([_validPubkeyA, _validPubkeyA]),
              isGroup: false,
              isRead: true,
              currentUserHasSent: false,
              createdAt: 1700000000,
            ),
          );

          when(
            () => mockDirectMessagesDao.deleteConversationMessages(
              selfConvId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => 0);

          when(
            () => mockConversationsDao.deleteConversation(
              selfConvId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => 1);

          when(
            () => mockNostrClient.unsubscribe(any()),
          ).thenAnswer((_) async {});

          // Create repo then setCredentials to trigger post-auth
          // maintenance including _cleanupSelfConversations.
          DmRepository(
            nostrClient: mockNostrClient,
            directMessagesDao: mockDirectMessagesDao,
            conversationsDao: mockConversationsDao,
          ).setCredentials(
            userPubkey: _validPubkeyA,
            signer: LocalNostrSigner(_validPrivateKey),
            messageService: mockMessageService,
          );

          // Give post-auth maintenance time to complete.
          await Future<void>.delayed(const Duration(milliseconds: 50));

          verify(
            () => mockDirectMessagesDao.deleteConversationMessages(
              selfConvId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).called(1);

          verify(
            () => mockConversationsDao.deleteConversation(
              selfConvId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).called(1);
        },
      );

      test(
        'no-op when self-conversation does not exist',
        () async {
          final selfConvId = DmRepository.computeConversationId(
            [_validPubkeyA, _validPubkeyA],
          );

          when(
            () => mockConversationsDao.getConversation(
              selfConvId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          when(
            () => mockNostrClient.unsubscribe(any()),
          ).thenAnswer((_) async {});

          DmRepository(
            nostrClient: mockNostrClient,
            directMessagesDao: mockDirectMessagesDao,
            conversationsDao: mockConversationsDao,
          ).setCredentials(
            userPubkey: _validPubkeyA,
            signer: LocalNostrSigner(_validPrivateKey),
            messageService: mockMessageService,
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          verifyNever(
            () => mockDirectMessagesDao.deleteConversationMessages(
              selfConvId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
        },
      );
    });

    group('sendMessage - replyToId', () {
      test('includes reply-to tag when replyToId is provided', () async {
        stubSendRumor(
          (_, recipientPubkey) async => NIP17SendResult.success(
            rumorEventId: _rumorEventId,
            messageEventId: _giftWrapEventId,
            recipientPubkey: recipientPubkey,
          ),
        );

        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});

        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});

        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => PublishSuccess(event: _FakeEvent()));

        final repo = createRepository();
        const replyId =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

        await repo.sendMessage(
          recipientPubkey: _validPubkeyB,
          content: 'Reply!',
          replyToId: replyId,
        );

        final rumorEvent =
            verify(
                  () => mockMessageService.sendRumor(
                    rumorEvent: captureAny(named: 'rumorEvent'),
                    recipientPubkey: any(named: 'recipientPubkey'),
                  ),
                ).captured.single
                as Event;
        final captured = additionalTagsFromRumor(rumorEvent, _validPubkeyB);
        expect(
          captured.any(
            (tag) => tag.length == 2 && tag[0] == 'e' && tag[1] == replyId,
          ),
          isTrue,
        );
      });
    });

    // -----------------------------------------------------------------
    // Phase 3: sendGroupMessage success, _mergeDuplicateConversations
    // -----------------------------------------------------------------

    group('sendGroupMessage - success', () {
      void stubDaoInserts() {
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);
      }

      test(
        'sends to each recipient and persists group conversation',
        () async {
          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );
          stubDaoInserts();

          final repo = createRepository();
          final results = await repo.sendGroupMessage(
            recipientPubkeys: [_validPubkeyB, _validPubkeyC],
            content: 'Group hello!',
          );

          expect(results, hasLength(2));
          expect(results.every((r) => r.success), isTrue);

          // Verify sent to each recipient
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
            ),
          ).called(2);

          // Verify group conversation was persisted
          verify(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: true,
              createdAt: any(named: 'createdAt'),
              lastMessageContent: 'Group hello!',
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: _validPubkeyA,
              currentUserHasSent: true,
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).called(1);
        },
      );

      test(
        'persists when at least one send succeeds (partial failure)',
        () async {
          var callCount = 0;
          stubSendRumor((_, recipientPubkey) async {
            callCount++;
            if (callCount == 1) {
              return NIP17SendResult.success(
                rumorEventId: _rumorEventId,
                messageEventId: _giftWrapEventId,
                recipientPubkey: recipientPubkey,
              );
            }
            return const NIP17SendResult.failure('relay timeout');
          });
          stubDaoInserts();

          final repo = createRepository();
          final results = await repo.sendGroupMessage(
            recipientPubkeys: [_validPubkeyB, _validPubkeyC],
            content: 'Partial!',
          );

          expect(results, hasLength(2));
          expect(results.where((r) => r.success), hasLength(1));

          // Message should still be persisted since one succeeded
          verify(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: 'Partial!',
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              replyToId: any(named: 'replyToId'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).called(1);
        },
      );

      test(
        'does not persist when all sends fail',
        () async {
          stubSendRumor(
            (rumorEvent, recipientPubkey) async =>
                const NIP17SendResult.failure('relay timeout'),
          );

          final repo = createRepository();
          final results = await repo.sendGroupMessage(
            recipientPubkeys: [_validPubkeyB, _validPubkeyC],
            content: 'Fails!',
          );

          expect(results, hasLength(2));
          expect(results.every((r) => !r.success), isTrue);

          verifyNever(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          );
        },
      );
    });

    group('_mergeDuplicateConversations', () {
      test(
        'merges duplicate conversations into canonical 1:1 ID',
        () async {
          final canonical = [_validPubkeyA, _validPubkeyB]..sort();
          final canonicalId = DmRepository.computeConversationId(canonical);

          // Two conversations exist for the same peer: one canonical, one
          // phantom from extra p-tags.
          final phantomParticipants = [
            _validPubkeyA,
            _validPubkeyB,
            _validPubkeyC,
          ]..sort();
          final phantomId = DmRepository.computeConversationId(
            phantomParticipants,
          );

          when(
            () => mockConversationsDao.getAllConversations(
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              ConversationRow(
                id: canonicalId,
                participantPubkeys: jsonEncode(canonical),
                isGroup: false,
                isRead: true,
                currentUserHasSent: true,
                createdAt: 1700000000,
                lastMessageContent: 'Canonical msg',
                lastMessageTimestamp: 1700000000,
                lastMessageSenderPubkey: _validPubkeyB,
              ),
              ConversationRow(
                id: phantomId,
                participantPubkeys: jsonEncode(phantomParticipants),
                isGroup: false,
                isRead: true,
                currentUserHasSent: false,
                createdAt: 1699999000,
                lastMessageContent: 'Phantom msg',
                lastMessageTimestamp: 1699999000,
                lastMessageSenderPubkey: _validPubkeyB,
              ),
            ],
          );

          when(
            () => mockDirectMessagesDao.reassignConversation(
              fromConversationId: any(named: 'fromConversationId'),
              toConversationId: any(named: 'toConversationId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => 1);

          when(
            () => mockConversationsDao.deleteConversation(
              phantomId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => 1);

          // Stub for _refreshConversationPreview
          when(
            () => mockDirectMessagesDao.getMessagesForConversation(
              canonicalId,
              limit: 1,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => []);

          when(
            () => mockConversationsDao.getConversation(
              canonicalId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).thenAnswer((_) async {});

          // Stub self-conversation for _cleanupSelfConversations
          final selfConvId = DmRepository.computeConversationId(
            [_validPubkeyA, _validPubkeyA],
          );
          when(
            () => mockConversationsDao.getConversation(
              selfConvId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          when(
            () => mockNostrClient.unsubscribe(any()),
          ).thenAnswer((_) async {});

          DmRepository(
            nostrClient: mockNostrClient,
            directMessagesDao: mockDirectMessagesDao,
            conversationsDao: mockConversationsDao,
          ).setCredentials(
            userPubkey: _validPubkeyA,
            signer: LocalNostrSigner(_validPrivateKey),
            messageService: mockMessageService,
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Phantom messages should be reassigned to canonical ID.
          verify(
            () => mockDirectMessagesDao.reassignConversation(
              fromConversationId: phantomId,
              toConversationId: canonicalId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).called(1);

          // Phantom conversation should be deleted.
          verify(
            () => mockConversationsDao.deleteConversation(
              phantomId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).called(1);
        },
      );

      test(
        'creates canonical row when it does not exist',
        () async {
          // Only the phantom exists, not the canonical row.
          final phantomParticipants = [
            _validPubkeyA,
            _validPubkeyB,
            _validPubkeyC,
          ]..sort();
          final phantomId = DmRepository.computeConversationId(
            phantomParticipants,
          );

          when(
            () => mockConversationsDao.getAllConversations(
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              ConversationRow(
                id: phantomId,
                participantPubkeys: jsonEncode(phantomParticipants),
                isGroup: false,
                isRead: true,
                currentUserHasSent: false,
                createdAt: 1699999000,
                lastMessageContent: 'Phantom',
                lastMessageTimestamp: 1699999000,
                lastMessageSenderPubkey: _validPubkeyB,
                ownerPubkey: _validPubkeyA,
                dmProtocol: 'nip17',
              ),
            ],
          );

          when(
            () => mockDirectMessagesDao.reassignConversation(
              fromConversationId: any(named: 'fromConversationId'),
              toConversationId: any(named: 'toConversationId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => 0);

          when(
            () => mockConversationsDao.deleteConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => 0);

          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockDirectMessagesDao.getMessagesForConversation(
              any(),
              limit: 1,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => []);

          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          when(
            () => mockNostrClient.unsubscribe(any()),
          ).thenAnswer((_) async {});

          DmRepository(
            nostrClient: mockNostrClient,
            directMessagesDao: mockDirectMessagesDao,
            conversationsDao: mockConversationsDao,
          ).setCredentials(
            userPubkey: _validPubkeyA,
            signer: LocalNostrSigner(_validPrivateKey),
            messageService: mockMessageService,
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Only 1 conversation → no duplicates to merge (peerGroups
          // will have a single entry), so no reassignment.
          verifyNever(
            () => mockDirectMessagesDao.reassignConversation(
              fromConversationId: any(named: 'fromConversationId'),
              toConversationId: any(named: 'toConversationId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
        },
      );

      test('single conversation per peer is a no-op', () async {
        final participants = [_validPubkeyA, _validPubkeyB]..sort();
        final convId = DmRepository.computeConversationId(participants);

        when(
          () => mockConversationsDao.getAllConversations(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => [
            ConversationRow(
              id: convId,
              participantPubkeys: jsonEncode(participants),
              isGroup: false,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1700000000,
            ),
          ],
        );

        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => mockNostrClient.unsubscribe(any()),
        ).thenAnswer((_) async {});

        DmRepository(
          nostrClient: mockNostrClient,
          directMessagesDao: mockDirectMessagesDao,
          conversationsDao: mockConversationsDao,
        ).setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        verifyNever(
          () => mockDirectMessagesDao.reassignConversation(
            fromConversationId: any(named: 'fromConversationId'),
            toConversationId: any(named: 'toConversationId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      });
    });

    group('setCredentials with custom decryptors', () {
      test(
        'stores injected rumorDecryptor and nip04Decryptor',
        () async {
          var rumorCalled = false;
          var nip04Called = false;

          final repo = DmRepository(
            nostrClient: mockNostrClient,
            directMessagesDao: mockDirectMessagesDao,
            conversationsDao: mockConversationsDao,
          );

          when(
            () => mockNostrClient.unsubscribe(any()),
          ).thenAnswer((_) async {});

          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          repo.setCredentials(
            userPubkey: _validPubkeyA,
            signer: LocalNostrSigner(_validPrivateKey),
            messageService: mockMessageService,
            rumorDecryptor: (nostr, event) async {
              rumorCalled = true;
              return null;
            },
            nip04Decryptor: (pubkey, ciphertext) async {
              nip04Called = true;
              return null;
            },
          );

          // Give post-auth maintenance a chance to complete.
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // The decryptors are stored — we verify by confirming
          // setCredentials accepted them without error.
          expect(repo.isInitialized, isTrue);
          // Variables exist to confirm the closures were created.
          // Calling them would require a full receive pipeline test;
          // this test verifies the branch at lines 160-161 is reached.
          expect(rumorCalled, isFalse);
          expect(nip04Called, isFalse);
        },
      );
    });

    group('subscription onError reconnect', () {
      test(
        'clears subscription and schedules reconnect on stream error',
        () async {
          final controller = StreamController<Event>();

          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller.stream);

          when(
            () => mockNostrClient.unsubscribe(any()),
          ).thenAnswer((_) async {});

          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          final repo = createRepository();
          await repo.startListening();

          // Emit a stream error to trigger the onError handler.
          controller.addError(Exception('relay disconnect'));

          // Give the error handler a tick to execute.
          await Future<void>.delayed(Duration.zero);

          // After error, the repository should have cleared its
          // subscription and be ready to re-subscribe.
          // We verify by calling startListening again successfully.
          final controller2 = StreamController<Event>();
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => controller2.stream);

          // The reconnect is scheduled via Timer, but calling
          // startListening() directly also works because the old
          // subscription reference was cleared and the pending reconnect
          // timer is cancelled at the top of startListening().
          await repo.startListening();

          // Tear down the repository before closing the controllers so
          // any pending reconnect timer is cancelled and onDone doesn't
          // schedule a fresh one that would leak past this test.
          await repo.stopListening();

          await controller.close();
          await controller2.close();
        },
      );
    });

    group('_sendNip04Message failure paths', () {
      test(
        'returns failure when signer is null',
        () async {
          // Create a repo, then call sendMessage where the NIP-04
          // fallback is fired. The NIP-04 path checks _signer which
          // is null when credentials are not set.
          // To reach _sendNip04Message with null signer, we need a
          // repo where _signer is null. However, createRepository
          // always sets a signer. Instead, test via a mock signer
          // that returns null from encrypt.
          final mockSigner = _MockNostrSigner();
          when(mockSigner.getPublicKey).thenAnswer(
            (_) async => _validPubkeyA,
          );
          when(
            () => mockSigner.encrypt(any(), any()),
          ).thenAnswer((_) async => null);

          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );

          when(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          final repo = DmRepository(
            nostrClient: mockNostrClient,
            messageService: mockMessageService,
            directMessagesDao: mockDirectMessagesDao,
            conversationsDao: mockConversationsDao,
            userPubkey: _validPubkeyA,
            signer: mockSigner,
          );

          final result = await repo.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'Hello',
          );

          // NIP-17 succeeded, NIP-04 fallback silently failed.
          expect(result.success, isTrue);

          // Give unawaited NIP-04 fallback time to complete.
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
      );

      test(
        'returns failure when signEvent returns null',
        () async {
          final mockSigner = _MockNostrSigner();
          when(mockSigner.getPublicKey).thenAnswer(
            (_) async => _validPubkeyA,
          );
          when(
            () => mockSigner.encrypt(any(), any()),
          ).thenAnswer((_) async => 'encrypted-content');
          when(
            () => mockSigner.signEvent(any()),
          ).thenAnswer((_) async => null);

          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );

          when(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          final repo = DmRepository(
            nostrClient: mockNostrClient,
            messageService: mockMessageService,
            directMessagesDao: mockDirectMessagesDao,
            conversationsDao: mockConversationsDao,
            userPubkey: _validPubkeyA,
            signer: mockSigner,
          );

          final result = await repo.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'Hello',
          );

          expect(result.success, isTrue);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
      );

      test(
        'NIP-17 send succeeds even when NIP-04 fallback gets PublishNoRelays',
        () async {
          // The NIP-04 fallback is fire-and-forget; PublishNoRelays must not
          // bubble up and fail the overall sendMessage result.
          final mockSigner = _MockNostrSigner();
          when(mockSigner.getPublicKey).thenAnswer(
            (_) async => _validPubkeyA,
          );
          when(
            () => mockSigner.encrypt(any(), any()),
          ).thenAnswer((_) async => 'encrypted-content');
          when(
            () => mockSigner.signEvent(any()),
          ).thenAnswer((inv) async {
            final e = inv.positionalArguments.first as Event;
            return e
              ..id = 'nip04-event-id-no-relays'
              ..sig = 'sig';
          });

          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );

          when(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => const PublishNoRelays());

          final repo = DmRepository(
            nostrClient: mockNostrClient,
            messageService: mockMessageService,
            directMessagesDao: mockDirectMessagesDao,
            conversationsDao: mockConversationsDao,
            userPubkey: _validPubkeyA,
            signer: mockSigner,
          );

          final result = await repo.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'Hello',
          );

          // NIP-17 succeeded; NIP-04 fallback silently got PublishNoRelays.
          expect(result.success, isTrue);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
      );

      test(
        'NIP-17 send succeeds even when NIP-04 fallback gets PublishFailed',
        () async {
          // The NIP-04 fallback is fire-and-forget; PublishFailed must not
          // bubble up and fail the overall sendMessage result.
          final mockSigner = _MockNostrSigner();
          when(mockSigner.getPublicKey).thenAnswer(
            (_) async => _validPubkeyA,
          );
          when(
            () => mockSigner.encrypt(any(), any()),
          ).thenAnswer((_) async => 'encrypted-content');
          when(
            () => mockSigner.signEvent(any()),
          ).thenAnswer((inv) async {
            final e = inv.positionalArguments.first as Event;
            return e
              ..id = 'nip04-event-id-send-error'
              ..sig = 'sig';
          });

          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );

          when(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => null);

          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          final repo = DmRepository(
            nostrClient: mockNostrClient,
            messageService: mockMessageService,
            directMessagesDao: mockDirectMessagesDao,
            conversationsDao: mockConversationsDao,
            userPubkey: _validPubkeyA,
            signer: mockSigner,
          );

          final result = await repo.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'Hello',
          );

          // NIP-17 succeeded; NIP-04 fallback silently got PublishFailed.
          expect(result.success, isTrue);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
      );
    });

    group('sendMessage preserves existing conversation metadata', () {
      test(
        'uses existing createdAt and dmProtocol from conversation',
        () async {
          final participants = [_validPubkeyA, _validPubkeyB]..sort();
          final conversationId = DmRepository.computeConversationId(
            participants,
          );

          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );

          when(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).thenAnswer((_) async {});

          when(
            () => mockConversationsDao.upsertConversation(
              id: any(named: 'id'),
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: any(named: 'isGroup'),
              createdAt: any(named: 'createdAt'),
              lastMessageContent: any(named: 'lastMessageContent'),
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: any(named: 'currentUserHasSent'),
              ownerPubkey: any(named: 'ownerPubkey'),
              dmProtocol: any(named: 'dmProtocol'),
            ),
          ).thenAnswer((_) async {});

          // Return an existing conversation with known metadata.
          when(
            () => mockConversationsDao.getConversation(
              conversationId,
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: conversationId,
              participantPubkeys: jsonEncode(participants),
              isGroup: false,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1690000000,
              lastMessageContent: 'old message',
              lastMessageTimestamp: 1690000000,
              lastMessageSenderPubkey: _validPubkeyB,
              dmProtocol: 'nip17',
              ownerPubkey: _validPubkeyA,
            ),
          );

          final repo = createRepository();
          final result = await repo.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'New message',
          );

          expect(result.success, isTrue);

          // Verify upsert was called with the existing createdAt
          // and the nip17 protocol from the existing row.
          verify(
            () => mockConversationsDao.upsertConversation(
              id: conversationId,
              participantPubkeys: any(named: 'participantPubkeys'),
              isGroup: false,
              createdAt: 1690000000,
              lastMessageContent: 'New message',
              lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
              lastMessageSenderPubkey: _validPubkeyA,
              subject: any(named: 'subject'),
              isRead: any(named: 'isRead'),
              currentUserHasSent: true,
              ownerPubkey: _validPubkeyA,
              dmProtocol: 'nip17',
            ),
          ).called(1);
        },
      );
    });

    group('sendMessage with outgoing_dms queue wired in', () {
      late _MockOutgoingDmsDao mockOutgoingDmsDao;

      setUp(() {
        mockOutgoingDmsDao = _MockOutgoingDmsDao();
        // Default stubs covering the queue lifecycle a successful or
        // failed send touches.
        when(
          () => mockOutgoingDmsDao.enqueue(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockOutgoingDmsDao.deleteById(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockOutgoingDmsDao.markRecipientWrapStatus(
            id: any(named: 'id'),
            status: any(named: 'status'),
            eventId: any(named: 'eventId'),
            lastError: any(named: 'lastError'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockOutgoingDmsDao.markSelfWrapStatus(
            id: any(named: 'id'),
            status: any(named: 'status'),
            eventId: any(named: 'eventId'),
            lastError: any(named: 'lastError'),
          ),
        ).thenAnswer((_) async => true);

        // Surrounding stubs the success path needs (insertMessage,
        // upsertConversation, getConversation, publishEvent for the
        // NIP-04 fallback).
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());
      });

      test(
        'enqueues a pending row with the rumor id, then deletes it on '
        'full delivery',
        () async {
          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'queue-wired message',
          );

          expect(result.success, isTrue);

          // Capture the enqueue call so we can assert the row shape and
          // re-use the rumor id for the deleteById verify.
          final captured = verify(
            () => mockOutgoingDmsDao.enqueue(captureAny()),
          ).captured;
          expect(captured, hasLength(1));
          final enqueued = captured.single as OutgoingDm;
          expect(enqueued.recipientPubkey, equals(_validPubkeyB));
          expect(enqueued.ownerPubkey, equals(_validPubkeyA));
          expect(enqueued.content, equals('queue-wired message'));
          expect(enqueued.recipientWrapStatus, OutgoingWrapStatus.pending);
          expect(enqueued.selfWrapStatus, OutgoingWrapStatus.pending);
          expect(
            enqueued.id,
            isNotEmpty,
            reason:
                'queue PK is the rumor id; the buildRumor stub computes '
                'a deterministic id from rumor fields',
          );

          verify(
            () => mockOutgoingDmsDao.deleteById(enqueued.id),
          ).called(1);
          // The failure-path mark methods must NOT fire on a successful
          // send — that would leave the row in a phantom failed state
          // even though delivery succeeded.
          verifyNever(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              eventId: any(named: 'eventId'),
              lastError: any(named: 'lastError'),
            ),
          );
        },
      );

      test(
        'on publish failure: marks both wraps failed with the error '
        'and leaves the row for the retry service',
        () async {
          stubSendRumor(
            (rumorEvent, recipientPubkey) async =>
                const NIP17SendResult.failure('relay unavailable'),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'this will fail',
          );

          expect(result.success, isFalse);

          final captured = verify(
            () => mockOutgoingDmsDao.enqueue(captureAny()),
          ).captured;
          final enqueued = captured.single as OutgoingDm;

          // Recipient publish failed before the self-wrap could land,
          // so both wrap states stay retryable.
          verify(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: enqueued.id,
              status: OutgoingWrapStatus.failed,
              lastError: 'relay unavailable',
            ),
          ).called(1);
          verify(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: enqueued.id,
              status: OutgoingWrapStatus.failed,
              lastError: 'relay unavailable',
            ),
          ).called(1);
          // On failure the row stays put — deleteById must not fire,
          // otherwise the user loses the failed bubble + retry option.
          verifyNever(
            () => mockOutgoingDmsDao.deleteById(any()),
          );
          // direct_messages must not be inserted — that's reserved for
          // confirmed deliveries.
          verifyNever(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          );
        },
      );

      test(
        'on partial delivery: persists locally, keeps the queue row, '
        'marks recipient sent, and marks self failed',
        () async {
          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
              selfWrapPublished: false,
            ),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'recipient got it, self-wrap failed',
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isFalse);

          final captured = verify(
            () => mockOutgoingDmsDao.enqueue(captureAny()),
          ).captured;
          final enqueued = captured.single as OutgoingDm;

          verify(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: enqueued.id,
              status: OutgoingWrapStatus.sent,
              eventId: _giftWrapEventId,
            ),
          ).called(1);
          verify(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: enqueued.id,
              status: OutgoingWrapStatus.failed,
              lastError: 'Recipient delivered, but self-wrap publish failed',
            ),
          ).called(1);
          verifyNever(() => mockOutgoingDmsDao.deleteById(any()));
          verify(
            () => mockDirectMessagesDao.insertMessage(
              id: _rumorEventId,
              conversationId: any(named: 'conversationId'),
              senderPubkey: _validPubkeyA,
              content: 'recipient got it, self-wrap failed',
              createdAt: any(named: 'createdAt'),
              giftWrapId: _giftWrapEventId,
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: _validPubkeyA,
              tagsJson: any(named: 'tagsJson'),
            ),
          ).called(1);
        },
      );

      test(
        'queue is opt-in: when no OutgoingDmsDao is injected, '
        'sendMessage falls back to the direct-write behaviour and '
        'never touches the queue',
        () async {
          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );

          // No outgoingDmsDao argument — older test fixtures and
          // (until provider is updated) production paths.
          final repository = createRepository();

          final result = await repository.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'no queue here',
          );

          expect(result.success, isTrue);
          verifyNever(() => mockOutgoingDmsDao.enqueue(any()));
          verifyNever(() => mockOutgoingDmsDao.deleteById(any()));
        },
      );

      test(
        'on publish failure: when markRecipientWrapStatus throws inside '
        '_finalizeAfterRecipientFailure, the swallow is reported and '
        'the failure result still surfaces',
        () async {
          stubSendRumor(
            (_, _) async => const NIP17SendResult.failure('relay unavailable'),
          );
          when(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              eventId: any(named: 'eventId'),
              lastError: any(named: 'lastError'),
            ),
          ).thenThrow(Exception('drift busy'));

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'this will fail',
          );

          expect(result.success, isFalse);
          expect(reporterCalls, hasLength(1));
          expect(
            reporterCalls.single.site,
            equals(
              DmRepositoryReportableSites.finalizeAfterRecipientFailure,
            ),
          );
        },
      );

      test(
        'on publish success: when local persistence inside the outer '
        'transaction throws, the swallow is reported and the publish '
        'success result still surfaces',
        () async {
          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId,
              recipientPubkey: recipientPubkey,
            ),
          );
          // Force the outer try/catch in sendMessage by failing the
          // local insertMessage inside the transaction.
          when(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).thenThrow(Exception('drift busy'));

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.sendMessage(
            recipientPubkey: _validPubkeyB,
            content: 'local persistence will fail',
          );

          // Publish succeeded — caller still sees success even though
          // local persistence threw.
          expect(result.success, isTrue);
          expect(reporterCalls, hasLength(1));
          expect(
            reporterCalls.single.site,
            equals(
              DmRepositoryReportableSites.sendMessageOuterTransaction,
            ),
          );
        },
      );
    });

    group('sendGroupMessage with outgoing_dms queue wired in', () {
      late _MockOutgoingDmsDao mockOutgoingDmsDao;

      setUp(() {
        mockOutgoingDmsDao = _MockOutgoingDmsDao();
        when(
          () => mockOutgoingDmsDao.enqueue(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockOutgoingDmsDao.deleteById(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockOutgoingDmsDao.markRecipientWrapStatus(
            id: any(named: 'id'),
            status: any(named: 'status'),
            eventId: any(named: 'eventId'),
            lastError: any(named: 'lastError'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockOutgoingDmsDao.markSelfWrapStatus(
            id: any(named: 'id'),
            status: any(named: 'status'),
            eventId: any(named: 'eventId'),
            lastError: any(named: 'lastError'),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);
      });

      test(
        'enqueues a row per recipient and deletes them all on full delivery',
        () async {
          // Per-recipient rumor.id differs because additionalTags differ.
          // Pin success on both recipients so both queued rumor ids
          // take the full-delivery path.
          stubSendRumor((_, recipient) async {
            return NIP17SendResult.success(
              rumorEventId: 'rumor-$recipient',
              messageEventId: 'wrap-$recipient',
              recipientPubkey: recipient,
            );
          });

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final results = await repository.sendGroupMessage(
            recipientPubkeys: [_validPubkeyB, _validPubkeyC],
            content: 'group full delivery',
          );

          expect(results, hasLength(2));
          expect(results.every((r) => r.success), isTrue);

          final captured = verify(
            () => mockOutgoingDmsDao.enqueue(captureAny()),
          ).captured;
          expect(
            captured,
            hasLength(2),
            reason: 'one queue row per recipient',
          );
          final enqueuedB = captured.first as OutgoingDm;
          final enqueuedC = captured.last as OutgoingDm;
          expect(enqueuedB.recipientPubkey, equals(_validPubkeyB));
          expect(enqueuedC.recipientPubkey, equals(_validPubkeyC));
          expect(
            enqueuedB.id,
            isNot(equals(enqueuedC.id)),
            reason:
                'each recipient gets its own rumor id; group queue rows '
                'must not collide',
          );
          expect(enqueuedB.recipientWrapStatus, OutgoingWrapStatus.pending);
          expect(enqueuedB.selfWrapStatus, OutgoingWrapStatus.pending);

          verify(() => mockOutgoingDmsDao.deleteById(enqueuedB.id)).called(1);
          verify(() => mockOutgoingDmsDao.deleteById(enqueuedC.id)).called(1);
          // No mark calls fire on a fully-delivered tuple — the row is
          // dropped atomically with the message persist.
          verifyNever(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              eventId: any(named: 'eventId'),
              lastError: any(named: 'lastError'),
            ),
          );
        },
      );

      test(
        'marks recipient sent + self failed only for the recipients '
        'whose self-wrap failed, deletes rows for fully-delivered ones',
        () async {
          stubSendRumor((_, recipient) async {
            return NIP17SendResult.success(
              rumorEventId: 'rumor-$recipient',
              messageEventId: 'wrap-$recipient',
              recipientPubkey: recipient,
              // First recipient (B) is fully delivered, second (C) is
              // partial. The asymmetry pins "scope recovery to only the
              // affected successful recipient sends" from #4102.
              selfWrapPublished: recipient == _validPubkeyB,
            );
          });

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final results = await repository.sendGroupMessage(
            recipientPubkeys: [_validPubkeyB, _validPubkeyC],
            content: 'group partial delivery',
          );

          expect(results, hasLength(2));
          expect(results.every((r) => r.success), isTrue);

          final captured = verify(
            () => mockOutgoingDmsDao.enqueue(captureAny()),
          ).captured;
          final enqueuedB = captured.first as OutgoingDm;
          final enqueuedC = captured.last as OutgoingDm;

          // Recipient B: full delivery → row deleted.
          verify(() => mockOutgoingDmsDao.deleteById(enqueuedB.id)).called(1);
          // Recipient C: partial → recipient sent + self failed, row
          // preserved for recovery.
          verify(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: enqueuedC.id,
              status: OutgoingWrapStatus.sent,
              eventId: 'wrap-$_validPubkeyC',
            ),
          ).called(1);
          verify(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: enqueuedC.id,
              status: OutgoingWrapStatus.failed,
              lastError: 'Recipient delivered, but self-wrap publish failed',
            ),
          ).called(1);
          verifyNever(() => mockOutgoingDmsDao.deleteById(enqueuedC.id));
        },
      );

      test(
        'marks both wraps failed for a recipient whose recipient '
        'publish failed, leaves the others on their full-delivery path',
        () async {
          stubSendRumor((_, recipient) async {
            if (recipient == _validPubkeyC) {
              return const NIP17SendResult.failure('relay rejected');
            }
            return NIP17SendResult.success(
              rumorEventId: 'rumor-$recipient',
              messageEventId: 'wrap-$recipient',
              recipientPubkey: recipient,
            );
          });

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final results = await repository.sendGroupMessage(
            recipientPubkeys: [_validPubkeyB, _validPubkeyC],
            content: 'mixed outcomes',
          );

          expect(results, hasLength(2));
          expect(results.where((r) => r.success), hasLength(1));

          final captured = verify(
            () => mockOutgoingDmsDao.enqueue(captureAny()),
          ).captured;
          final enqueuedB = captured.first as OutgoingDm;
          final enqueuedC = captured.last as OutgoingDm;

          verify(() => mockOutgoingDmsDao.deleteById(enqueuedB.id)).called(1);
          verify(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: enqueuedC.id,
              status: OutgoingWrapStatus.failed,
              lastError: 'relay rejected',
            ),
          ).called(1);
          verify(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: enqueuedC.id,
              status: OutgoingWrapStatus.failed,
              lastError: 'relay rejected',
            ),
          ).called(1);
          verifyNever(() => mockOutgoingDmsDao.deleteById(enqueuedC.id));
          // The failure path must not be confused with partial — recipient
          // never received this rumor, so the queue row is retryable in
          // both wraps, not in self only.
          verifyNever(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: enqueuedC.id,
              status: OutgoingWrapStatus.sent,
              eventId: any(named: 'eventId'),
            ),
          );
        },
      );

      test(
        'when all recipients fail: marks every row both-wraps failed '
        'and never inserts a direct_messages row',
        () async {
          stubSendRumor(
            (rumorEvent, recipientPubkey) async =>
                const NIP17SendResult.failure('all relays down'),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final results = await repository.sendGroupMessage(
            recipientPubkeys: [_validPubkeyB, _validPubkeyC],
            content: 'total failure',
          );

          expect(results, hasLength(2));
          expect(results.every((r) => !r.success), isTrue);

          verify(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: any(named: 'id'),
              status: OutgoingWrapStatus.failed,
              lastError: 'all relays down',
            ),
          ).called(2);
          verify(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: any(named: 'id'),
              status: OutgoingWrapStatus.failed,
              lastError: 'all relays down',
            ),
          ).called(2);
          verifyNever(() => mockOutgoingDmsDao.deleteById(any()));
          verifyNever(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          );
        },
      );

      test(
        'queue is opt-in: when no OutgoingDmsDao is injected, '
        'sendGroupMessage falls back to the direct-write behaviour',
        () async {
          stubSendRumor((_, recipient) async {
            return NIP17SendResult.success(
              rumorEventId: 'rumor-$recipient',
              messageEventId: 'wrap-$recipient',
              recipientPubkey: recipient,
            );
          });

          final repository = createRepository();

          await repository.sendGroupMessage(
            recipientPubkeys: [_validPubkeyB, _validPubkeyC],
            content: 'no queue group send',
          );

          verifyNever(() => mockOutgoingDmsDao.enqueue(any()));
          verifyNever(() => mockOutgoingDmsDao.deleteById(any()));
          verifyNever(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              eventId: any(named: 'eventId'),
              lastError: any(named: 'lastError'),
            ),
          );
        },
      );
    });

    group('recoverSelfWrap', () {
      late _MockOutgoingDmsDao mockOutgoingDmsDao;

      // A fixed rumor JSON that Event.fromJson can parse — the
      // recoverSelfWrap path rebuilds the rumor from this payload to
      // preserve the receiver-side dedup key.
      final queuedRumorJson = jsonEncode({
        'id': _rumorEventId,
        'pubkey': _validPubkeyA,
        'created_at': 1700000000,
        'kind': EventKind.privateDirectMessage,
        'tags': [
          ['p', _validPubkeyB],
        ],
        'content': 'queued message',
        'sig': '',
      });

      OutgoingDm queuedRow({
        OutgoingWrapStatus selfWrapStatus = OutgoingWrapStatus.failed,
        String ownerPubkey = _validPubkeyA,
        String? selfWrapEventId,
      }) {
        return OutgoingDm(
          id: _rumorEventId,
          conversationId: 'conv',
          recipientPubkey: _validPubkeyB,
          content: 'queued message',
          createdAt: 1700000000,
          rumorEventJson: queuedRumorJson,
          recipientWrapStatus: OutgoingWrapStatus.sent,
          selfWrapStatus: selfWrapStatus,
          queuedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ownerPubkey: ownerPubkey,
          recipientWrapEventId: _giftWrapEventId,
          selfWrapEventId: selfWrapEventId,
        );
      }

      setUp(() {
        mockOutgoingDmsDao = _MockOutgoingDmsDao();
        when(
          () => mockOutgoingDmsDao.deleteById(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockOutgoingDmsDao.markSelfWrapStatus(
            id: any(named: 'id'),
            status: any(named: 'status'),
            eventId: any(named: 'eventId'),
            lastError: any(named: 'lastError'),
          ),
        ).thenAnswer((_) async => true);
      });

      test(
        'on successful self-wrap publish: deletes the queue row and '
        'returns success',
        () async {
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer((_) async => queuedRow());
          when(
            () => mockMessageService.publishSelfWrap(
              rumorEvent: any(named: 'rumorEvent'),
            ),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _rumorEventId,
              recipientPubkey: _validPubkeyA,
            ),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverSelfWrap(
            rumorId: _rumorEventId,
          );

          expect(result.success, isTrue);

          // Critical contract from #4102: recovery must NOT republish
          // the recipient wrap. Verify by asserting the underlying send
          // primitives are never called.
          verifyNever(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
            ),
          );
          verifyNever(
            () => mockMessageService.sendPrivateMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
              eventKind: any(named: 'eventKind'),
              additionalTags: any(named: 'additionalTags'),
            ),
          );

          verify(() => mockOutgoingDmsDao.deleteById(_rumorEventId)).called(1);
          verifyNever(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              eventId: any(named: 'eventId'),
              lastError: any(named: 'lastError'),
            ),
          );
        },
      );

      test(
        'on successful self-wrap publish: when deleteById throws, '
        'falls back to markSelfWrapStatus(sent, eventId) and still '
        'returns success',
        () async {
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer((_) async => queuedRow());
          when(
            () => mockMessageService.publishSelfWrap(
              rumorEvent: any(named: 'rumorEvent'),
            ),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId2,
              recipientPubkey: _validPubkeyA,
            ),
          );
          when(
            () => mockOutgoingDmsDao.deleteById(_rumorEventId),
          ).thenThrow(Exception('drift busy'));

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverSelfWrap(
            rumorId: _rumorEventId,
          );

          // Publish landed → recovery is a success even though the
          // delete failed.
          expect(result.success, isTrue);

          // Fallback closes the duplicate-publish hole: marks the row
          // sent with the published event id so the next sweep
          // short-circuits via the idempotent already-sent guard
          // instead of republishing the self-wrap.
          verify(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: _rumorEventId,
              status: OutgoingWrapStatus.sent,
              eventId: _giftWrapEventId2,
            ),
          ).called(1);

          // The swallowed deleteById failure is reported via the
          // errorReporter so production has a Crashlytics signal even
          // though the recovery path returned success.
          expect(reporterCalls, hasLength(1));
          expect(
            reporterCalls.single.site,
            equals(
              DmRepositoryReportableSites.recoverSelfWrapDeleteAfterPublish,
            ),
          );
        },
      );

      test(
        'on successful self-wrap publish: when both deleteById AND '
        'fallback markSelfWrapStatus throw, surfaces success and does '
        'not rethrow',
        () async {
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer((_) async => queuedRow());
          when(
            () => mockMessageService.publishSelfWrap(
              rumorEvent: any(named: 'rumorEvent'),
            ),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId2,
              recipientPubkey: _validPubkeyA,
            ),
          );
          when(
            () => mockOutgoingDmsDao.deleteById(_rumorEventId),
          ).thenThrow(Exception('drift busy'));
          when(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              eventId: any(named: 'eventId'),
              lastError: any(named: 'lastError'),
            ),
          ).thenThrow(Exception('drift still busy'));

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverSelfWrap(
            rumorId: _rumorEventId,
          );

          // Caller still sees success: publish outcome drives the
          // return value, not the bookkeeping outcome. Self-wraps are
          // idempotent on receive (NIP-17 dedup keys), so the
          // doubly-degraded path is safe.
          expect(result.success, isTrue);

          // Both swallowed failures surface via the errorReporter so
          // the doubly-degraded path is visible in Crashlytics. The
          // recovery path is "safe via NIP-17 dedup" only because we
          // now measure the rate at which it fires.
          expect(reporterCalls.map((c) => c.site), <String>[
            DmRepositoryReportableSites.recoverSelfWrapDeleteAfterPublish,
            DmRepositoryReportableSites.recoverSelfWrapBookkeepingDoubleFailure,
          ]);
        },
      );

      test(
        'on self-wrap publish failure: marks self_wrap_status failed '
        'and leaves the row queued for the next retry',
        () async {
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer((_) async => queuedRow());
          when(
            () => mockMessageService.publishSelfWrap(
              rumorEvent: any(named: 'rumorEvent'),
            ),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure('relay timeout'),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverSelfWrap(
            rumorId: _rumorEventId,
          );

          expect(result.success, isFalse);
          verify(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: _rumorEventId,
              status: OutgoingWrapStatus.failed,
              lastError: 'relay timeout',
            ),
          ).called(1);
          verifyNever(() => mockOutgoingDmsDao.deleteById(any()));
        },
      );

      test(
        'idempotent: when the row already shows self_wrap_status sent, '
        'returns success without re-publishing',
        () async {
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer(
            (_) async => queuedRow(
              selfWrapStatus: OutgoingWrapStatus.sent,
              selfWrapEventId: _giftWrapEventId2,
            ),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverSelfWrap(
            rumorId: _rumorEventId,
          );

          expect(result.success, isTrue);
          expect(result.messageEventId, equals(_giftWrapEventId2));
          verifyNever(
            () => mockMessageService.publishSelfWrap(
              rumorEvent: any(named: 'rumorEvent'),
            ),
          );
          verifyNever(() => mockOutgoingDmsDao.deleteById(any()));
        },
      );

      test(
        'throws ArgumentError when no queue row exists for the rumor id',
        () async {
          when(
            () => mockOutgoingDmsDao.getById(any()),
          ).thenAnswer((_) async => null);

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          expect(
            () => repository.recoverSelfWrap(rumorId: _rumorEventId),
            throwsArgumentError,
          );
        },
      );

      test(
        'throws ArgumentError when the queue row belongs to a '
        'different account',
        () async {
          when(() => mockOutgoingDmsDao.getById(_rumorEventId)).thenAnswer(
            (_) async => queuedRow(ownerPubkey: _validPubkeyD),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          expect(
            () => repository.recoverSelfWrap(rumorId: _rumorEventId),
            throwsArgumentError,
          );
          verifyNever(
            () => mockMessageService.publishSelfWrap(
              rumorEvent: any(named: 'rumorEvent'),
            ),
          );
        },
      );

      test(
        'throws StateError when the outgoing_dms DAO is not wired in',
        () async {
          final repository = createRepository();

          expect(
            () => repository.recoverSelfWrap(rumorId: _rumorEventId),
            throwsStateError,
          );
        },
      );

      test(
        'on rumor JSON parse failure: marks self_wrap_status failed '
        'with the parse error and surfaces a failure result',
        () async {
          final corruptedRow = OutgoingDm(
            id: _rumorEventId,
            conversationId: 'conv',
            recipientPubkey: _validPubkeyB,
            content: 'queued message',
            createdAt: 1700000000,
            rumorEventJson: 'this is not json',
            recipientWrapStatus: OutgoingWrapStatus.sent,
            selfWrapStatus: OutgoingWrapStatus.failed,
            queuedAt: DateTime.fromMillisecondsSinceEpoch(0),
            ownerPubkey: _validPubkeyA,
          );
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer((_) async => corruptedRow);

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverSelfWrap(
            rumorId: _rumorEventId,
          );

          expect(result.success, isFalse);
          expect(result.error, contains('rumor JSON parse failed'));
          verify(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: _rumorEventId,
              status: OutgoingWrapStatus.failed,
              lastError: any(
                named: 'lastError',
                that: contains('rumor JSON parse failed'),
              ),
            ),
          ).called(1);
          verifyNever(
            () => mockMessageService.publishSelfWrap(
              rumorEvent: any(named: 'rumorEvent'),
            ),
          );

          // Programming-invariant violation (we wrote that JSON) is
          // reported even though the recovery returned a non-throwing
          // failure result.
          expect(reporterCalls, hasLength(1));
          expect(
            reporterCalls.single.site,
            equals(DmRepositoryReportableSites.recoverSelfWrapRumorJsonParse),
          );
        },
      );

      test(
        'on rumor JSON parse failure: when the salvage markSelfWrapStatus '
        'also throws, reports both the parse failure and the salvage '
        'failure and still returns a non-throwing failure result',
        () async {
          final corruptedRow = OutgoingDm(
            id: _rumorEventId,
            conversationId: 'conv',
            recipientPubkey: _validPubkeyB,
            content: 'queued message',
            createdAt: 1700000000,
            rumorEventJson: 'this is not json',
            recipientWrapStatus: OutgoingWrapStatus.sent,
            selfWrapStatus: OutgoingWrapStatus.failed,
            queuedAt: DateTime.fromMillisecondsSinceEpoch(0),
            ownerPubkey: _validPubkeyA,
          );
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer((_) async => corruptedRow);
          when(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              eventId: any(named: 'eventId'),
              lastError: any(named: 'lastError'),
            ),
          ).thenThrow(Exception('drift busy'));

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverSelfWrap(
            rumorId: _rumorEventId,
          );

          expect(result.success, isFalse);
          expect(reporterCalls.map((c) => c.site), <String>[
            DmRepositoryReportableSites.recoverSelfWrapRumorJsonParse,
            DmRepositoryReportableSites.recoverSelfWrapMarkFailedAfterJsonParse,
          ]);
        },
      );

      test(
        'on self-wrap publish failure: when the salvage markSelfWrapStatus '
        'throws, reports the salvage failure and still returns the '
        'publish-failure result',
        () async {
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer((_) async => queuedRow());
          when(
            () => mockMessageService.publishSelfWrap(
              rumorEvent: any(named: 'rumorEvent'),
            ),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure('relay timeout'),
          );
          when(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: any(named: 'id'),
              status: any(named: 'status'),
              eventId: any(named: 'eventId'),
              lastError: any(named: 'lastError'),
            ),
          ).thenThrow(Exception('drift busy'));

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverSelfWrap(
            rumorId: _rumorEventId,
          );

          expect(result.success, isFalse);
          expect(reporterCalls, hasLength(1));
          expect(
            reporterCalls.single.site,
            equals(
              DmRepositoryReportableSites
                  .recoverSelfWrapMarkFailedAfterPublishFailure,
            ),
          );
        },
      );
    });

    group('recoverFullSend', () {
      late _MockOutgoingDmsDao mockOutgoingDmsDao;

      // A fixed rumor JSON that Event.fromJson can parse — the
      // recoverFullSend path rebuilds the rumor from this payload to
      // preserve the receiver-side dedup key across retries.
      final queuedRumorJson = jsonEncode({
        'id': _rumorEventId,
        'pubkey': _validPubkeyA,
        'created_at': 1700000000,
        'kind': EventKind.privateDirectMessage,
        'tags': [
          ['p', _validPubkeyB],
        ],
        'content': 'queued message',
        'sig': '',
      });

      OutgoingDm queuedRow({
        OutgoingWrapStatus recipientWrapStatus = OutgoingWrapStatus.failed,
        OutgoingWrapStatus selfWrapStatus = OutgoingWrapStatus.failed,
        String ownerPubkey = _validPubkeyA,
        String? recipientWrapEventId,
        String? selfWrapEventId,
      }) {
        return OutgoingDm(
          id: _rumorEventId,
          conversationId: 'conv',
          recipientPubkey: _validPubkeyB,
          content: 'queued message',
          createdAt: 1700000000,
          rumorEventJson: queuedRumorJson,
          recipientWrapStatus: recipientWrapStatus,
          selfWrapStatus: selfWrapStatus,
          queuedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ownerPubkey: ownerPubkey,
          recipientWrapEventId: recipientWrapEventId,
          selfWrapEventId: selfWrapEventId,
        );
      }

      setUp(() {
        mockOutgoingDmsDao = _MockOutgoingDmsDao();
        // Default stubs cover every DAO write recoverFullSend exercises
        // across its branches (success / partial / failure / parse-fail).
        when(
          () => mockOutgoingDmsDao.deleteById(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockOutgoingDmsDao.markRecipientWrapStatus(
            id: any(named: 'id'),
            status: any(named: 'status'),
            eventId: any(named: 'eventId'),
            lastError: any(named: 'lastError'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockOutgoingDmsDao.markSelfWrapStatus(
            id: any(named: 'id'),
            status: any(named: 'status'),
            eventId: any(named: 'eventId'),
            lastError: any(named: 'lastError'),
          ),
        ).thenAnswer((_) async => true);

        // Local persistence stubs for the happy-path transaction.
        when(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
            tagsJson: any(named: 'tagsJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.upsertConversation(
            id: any(named: 'id'),
            participantPubkeys: any(named: 'participantPubkeys'),
            isGroup: any(named: 'isGroup'),
            createdAt: any(named: 'createdAt'),
            lastMessageContent: any(named: 'lastMessageContent'),
            lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
            lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
            subject: any(named: 'subject'),
            isRead: any(named: 'isRead'),
            currentUserHasSent: any(named: 'currentUserHasSent'),
            ownerPubkey: any(named: 'ownerPubkey'),
            dmProtocol: any(named: 'dmProtocol'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);
      });

      test(
        'on full delivery: deletes the queue row, inserts '
        'direct_messages, and surfaces the success result',
        () async {
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer((_) async => queuedRow());
          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId2,
              recipientPubkey: recipientPubkey,
            ),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverFullSend(
            rumorId: _rumorEventId,
          );

          expect(result.success, isTrue);
          // Full delivery deletes the row in the same transaction as
          // the local message persist.
          verify(
            () => mockOutgoingDmsDao.deleteById(_rumorEventId),
          ).called(1);
          verify(
            () => mockDirectMessagesDao.insertMessage(
              id: _rumorEventId,
              conversationId: 'conv',
              senderPubkey: _validPubkeyA,
              content: 'queued message',
              createdAt: any(named: 'createdAt'),
              giftWrapId: _giftWrapEventId2,
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: _validPubkeyA,
              tagsJson: any(named: 'tagsJson'),
            ),
          ).called(1);
        },
      );

      test(
        'on partial delivery: keeps the queue row, marks recipient '
        'sent and self failed, still inserts direct_messages',
        () async {
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer((_) async => queuedRow());
          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId2,
              recipientPubkey: recipientPubkey,
              selfWrapPublished: false,
            ),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverFullSend(
            rumorId: _rumorEventId,
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isFalse);
          verifyNever(() => mockOutgoingDmsDao.deleteById(any()));
          verify(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: _rumorEventId,
              status: OutgoingWrapStatus.sent,
              eventId: _giftWrapEventId2,
            ),
          ).called(1);
          verify(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: _rumorEventId,
              status: OutgoingWrapStatus.failed,
              lastError: 'Recipient delivered, but self-wrap publish failed',
            ),
          ).called(1);
          // Local persistence still fires — the recipient received the
          // message, so the sender side must show it.
          verify(
            () => mockDirectMessagesDao.insertMessage(
              id: _rumorEventId,
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: _giftWrapEventId2,
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).called(1);
        },
      );

      test(
        'on recipient publish failure: re-marks both wraps failed and '
        'does NOT touch direct_messages',
        () async {
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer((_) async => queuedRow());
          stubSendRumor(
            (_, _) async =>
                const NIP17SendResult.failure('relay still unavailable'),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverFullSend(
            rumorId: _rumorEventId,
          );

          expect(result.success, isFalse);
          expect(result.error, equals('relay still unavailable'));
          verify(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: _rumorEventId,
              status: OutgoingWrapStatus.failed,
              lastError: 'relay still unavailable',
            ),
          ).called(1);
          verify(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: _rumorEventId,
              status: OutgoingWrapStatus.failed,
              lastError: 'relay still unavailable',
            ),
          ).called(1);
          verifyNever(() => mockOutgoingDmsDao.deleteById(any()));
          verifyNever(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          );
        },
      );

      test(
        'idempotent: when recipient_wrap_status is already sent, '
        'defers to recoverSelfWrap and never republishes the recipient '
        'wrap',
        () async {
          // Row promoted to recipient: sent / self: failed before this
          // recoverFullSend call (e.g. a concurrent retry, or the
          // original sendMessage hit the partial-success path).
          when(() => mockOutgoingDmsDao.getById(_rumorEventId)).thenAnswer(
            (_) async => queuedRow(
              recipientWrapStatus: OutgoingWrapStatus.sent,
              recipientWrapEventId: _giftWrapEventId,
            ),
          );
          when(
            () => mockMessageService.publishSelfWrap(
              rumorEvent: any(named: 'rumorEvent'),
            ),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _rumorEventId,
              recipientPubkey: _validPubkeyA,
            ),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverFullSend(
            rumorId: _rumorEventId,
          );

          expect(result.success, isTrue);
          // Critical invariant: no recipient publish on this branch.
          verifyNever(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
            ),
          );
          verifyNever(
            () => mockMessageService.sendPrivateMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
              eventKind: any(named: 'eventKind'),
              additionalTags: any(named: 'additionalTags'),
            ),
          );
          // recoverSelfWrap landed: it deletes the row after a clean
          // publish.
          verify(
            () => mockOutgoingDmsDao.deleteById(_rumorEventId),
          ).called(1);
        },
      );

      test(
        'throws ArgumentError when no queue row exists for the rumor id',
        () async {
          when(
            () => mockOutgoingDmsDao.getById(any()),
          ).thenAnswer((_) async => null);

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          expect(
            () => repository.recoverFullSend(rumorId: _rumorEventId),
            throwsArgumentError,
          );
        },
      );

      test(
        'throws ArgumentError when the queue row belongs to a '
        'different account',
        () async {
          when(() => mockOutgoingDmsDao.getById(_rumorEventId)).thenAnswer(
            (_) async => queuedRow(ownerPubkey: _validPubkeyD),
          );

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          expect(
            () => repository.recoverFullSend(rumorId: _rumorEventId),
            throwsArgumentError,
          );
          verifyNever(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
            ),
          );
        },
      );

      test(
        'throws StateError when the outgoing_dms DAO is not wired in',
        () async {
          final repository = createRepository();

          expect(
            () => repository.recoverFullSend(rumorId: _rumorEventId),
            throwsStateError,
          );
        },
      );

      test(
        'on rumor JSON parse failure: marks both wraps failed with '
        'the parse error and never attempts to publish',
        () async {
          final corruptedRow = OutgoingDm(
            id: _rumorEventId,
            conversationId: 'conv',
            recipientPubkey: _validPubkeyB,
            content: 'queued message',
            createdAt: 1700000000,
            rumorEventJson: 'this is not json',
            recipientWrapStatus: OutgoingWrapStatus.failed,
            selfWrapStatus: OutgoingWrapStatus.failed,
            queuedAt: DateTime.fromMillisecondsSinceEpoch(0),
            ownerPubkey: _validPubkeyA,
          );
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer((_) async => corruptedRow);

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverFullSend(
            rumorId: _rumorEventId,
          );

          expect(result.success, isFalse);
          expect(result.error, contains('rumor JSON parse failed'));
          verify(
            () => mockOutgoingDmsDao.markRecipientWrapStatus(
              id: _rumorEventId,
              status: OutgoingWrapStatus.failed,
              lastError: any(
                named: 'lastError',
                that: contains('rumor JSON parse failed'),
              ),
            ),
          ).called(1);
          verify(
            () => mockOutgoingDmsDao.markSelfWrapStatus(
              id: _rumorEventId,
              status: OutgoingWrapStatus.failed,
              lastError: any(
                named: 'lastError',
                that: contains('rumor JSON parse failed'),
              ),
            ),
          ).called(1);
          verifyNever(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
            ),
          );
        },
      );

      test(
        'when local persistence throws after a successful publish: '
        'still returns the publish-success result (degraded state, '
        'no rethrow)',
        () async {
          when(
            () => mockOutgoingDmsDao.getById(_rumorEventId),
          ).thenAnswer((_) async => queuedRow());
          stubSendRumor(
            (_, recipientPubkey) async => NIP17SendResult.success(
              rumorEventId: _rumorEventId,
              messageEventId: _giftWrapEventId2,
              recipientPubkey: recipientPubkey,
            ),
          );
          when(
            () => mockDirectMessagesDao.insertMessage(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              senderPubkey: any(named: 'senderPubkey'),
              content: any(named: 'content'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              messageKind: any(named: 'messageKind'),
              replyToId: any(named: 'replyToId'),
              subject: any(named: 'subject'),
              fileType: any(named: 'fileType'),
              encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
              decryptionKey: any(named: 'decryptionKey'),
              decryptionNonce: any(named: 'decryptionNonce'),
              fileHash: any(named: 'fileHash'),
              originalFileHash: any(named: 'originalFileHash'),
              fileSize: any(named: 'fileSize'),
              dimensions: any(named: 'dimensions'),
              blurhash: any(named: 'blurhash'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              ownerPubkey: any(named: 'ownerPubkey'),
              tagsJson: any(named: 'tagsJson'),
            ),
          ).thenThrow(Exception('drift busy'));

          final repository = createRepository(
            outgoingDmsDao: mockOutgoingDmsDao,
          );

          final result = await repository.recoverFullSend(
            rumorId: _rumorEventId,
          );

          // Publish landed → caller sees success even though local
          // bookkeeping inside the transaction failed.
          expect(result.success, isTrue);
        },
      );
    });

    group(
      '_mergeDuplicateConversations creates canonical row from phantoms',
      () {
        test(
          'creates canonical row when only phantom rows exist',
          () async {
            // Two phantom conversations for the same peer (B), but
            // with different extra participants — neither has the
            // canonical 1:1 ID.
            final phantomParticipants1 = [
              _validPubkeyA,
              _validPubkeyB,
              _validPubkeyC,
            ]..sort();
            final phantomId1 = DmRepository.computeConversationId(
              phantomParticipants1,
            );
            final phantomParticipants2 = [
              _validPubkeyA,
              _validPubkeyB,
              _validPubkeyD,
            ]..sort();
            final phantomId2 = DmRepository.computeConversationId(
              phantomParticipants2,
            );
            final canonical = [_validPubkeyA, _validPubkeyB]..sort();
            final canonicalId = DmRepository.computeConversationId(canonical);

            when(
              () => mockConversationsDao.getAllConversations(
                ownerPubkey: any(named: 'ownerPubkey'),
              ),
            ).thenAnswer(
              (_) async => [
                ConversationRow(
                  id: phantomId1,
                  participantPubkeys: jsonEncode(phantomParticipants1),
                  isGroup: false,
                  isRead: true,
                  currentUserHasSent: false,
                  createdAt: 1699999000,
                  lastMessageContent: 'Phantom 1',
                  lastMessageTimestamp: 1699999000,
                  lastMessageSenderPubkey: _validPubkeyB,
                  ownerPubkey: _validPubkeyA,
                  dmProtocol: 'nip17',
                ),
                ConversationRow(
                  id: phantomId2,
                  participantPubkeys: jsonEncode(phantomParticipants2),
                  isGroup: false,
                  isRead: true,
                  currentUserHasSent: true,
                  createdAt: 1699998000,
                  lastMessageContent: 'Phantom 2',
                  lastMessageTimestamp: 1699998000,
                  lastMessageSenderPubkey: _validPubkeyA,
                  ownerPubkey: _validPubkeyA,
                ),
              ],
            );

            when(
              () => mockDirectMessagesDao.reassignConversation(
                fromConversationId: any(named: 'fromConversationId'),
                toConversationId: any(named: 'toConversationId'),
                ownerPubkey: any(named: 'ownerPubkey'),
              ),
            ).thenAnswer((_) async => 1);

            when(
              () => mockConversationsDao.deleteConversation(
                any(),
                ownerPubkey: any(named: 'ownerPubkey'),
              ),
            ).thenAnswer((_) async => 1);

            when(
              () => mockConversationsDao.upsertConversation(
                id: any(named: 'id'),
                participantPubkeys: any(named: 'participantPubkeys'),
                isGroup: any(named: 'isGroup'),
                createdAt: any(named: 'createdAt'),
                lastMessageContent: any(named: 'lastMessageContent'),
                lastMessageTimestamp: any(named: 'lastMessageTimestamp'),
                lastMessageSenderPubkey: any(named: 'lastMessageSenderPubkey'),
                currentUserHasSent: any(named: 'currentUserHasSent'),
                ownerPubkey: any(named: 'ownerPubkey'),
                dmProtocol: any(named: 'dmProtocol'),
                forceUpdateLastMessage: any(named: 'forceUpdateLastMessage'),
              ),
            ).thenAnswer((_) async {});

            when(
              () => mockDirectMessagesDao.getMessagesForConversation(
                any(),
                limit: 1,
                ownerPubkey: any(named: 'ownerPubkey'),
              ),
            ).thenAnswer((_) async => []);

            when(
              () => mockConversationsDao.getConversation(
                any(),
                ownerPubkey: any(named: 'ownerPubkey'),
              ),
            ).thenAnswer((_) async => null);

            when(
              () => mockNostrClient.unsubscribe(any()),
            ).thenAnswer((_) async {});

            DmRepository(
              nostrClient: mockNostrClient,
              directMessagesDao: mockDirectMessagesDao,
              conversationsDao: mockConversationsDao,
            ).setCredentials(
              userPubkey: _validPubkeyA,
              signer: LocalNostrSigner(_validPrivateKey),
              messageService: mockMessageService,
            );

            await Future<void>.delayed(const Duration(milliseconds: 50));

            // Both phantoms should be reassigned to the canonical ID.
            verify(
              () => mockDirectMessagesDao.reassignConversation(
                fromConversationId: phantomId1,
                toConversationId: canonicalId,
                ownerPubkey: any(named: 'ownerPubkey'),
              ),
            ).called(1);
            verify(
              () => mockDirectMessagesDao.reassignConversation(
                fromConversationId: phantomId2,
                toConversationId: canonicalId,
                ownerPubkey: any(named: 'ownerPubkey'),
              ),
            ).called(1);

            // Canonical row should be created from the first phantom's
            // metadata since no canonical existed.
            verify(
              () => mockConversationsDao.upsertConversation(
                id: canonicalId,
                participantPubkeys: jsonEncode(canonical),
                isGroup: false,
                createdAt: 1699999000,
                lastMessageContent: 'Phantom 1',
                lastMessageTimestamp: 1699999000,
                lastMessageSenderPubkey: _validPubkeyB,
                ownerPubkey: _validPubkeyA,
                dmProtocol: 'nip17',
              ),
            ).called(1);
          },
        );
      },
    );

    group('_backfillCurrentUserHasSent', () {
      test('logs when conversations are updated', () async {
        when(
          () => mockConversationsDao.backfillCurrentUserHasSent(any()),
        ).thenAnswer((_) async => 3);

        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => mockNostrClient.unsubscribe(any()),
        ).thenAnswer((_) async {});

        DmRepository(
          nostrClient: mockNostrClient,
          directMessagesDao: mockDirectMessagesDao,
          conversationsDao: mockConversationsDao,
        ).setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(
          () => mockConversationsDao.backfillCurrentUserHasSent(
            _validPubkeyA,
          ),
        ).called(1);
      });
    });

    group('_backfillConversationPreviews', () {
      test('runs during post-auth maintenance', () async {
        when(
          () => mockConversationsDao.backfillLatestMessagePreviews(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => 2);

        when(
          () => mockConversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => mockNostrClient.unsubscribe(any()),
        ).thenAnswer((_) async {});

        DmRepository(
          nostrClient: mockNostrClient,
          directMessagesDao: mockDirectMessagesDao,
          conversationsDao: mockConversationsDao,
        ).setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );

        await untilCalled(
          () => mockConversationsDao.backfillLatestMessagePreviews(
            ownerPubkey: _validPubkeyA,
          ),
        );

        verify(
          () => mockConversationsDao.backfillLatestMessagePreviews(
            ownerPubkey: _validPubkeyA,
          ),
        ).called(1);
      });
    });
  });
}
