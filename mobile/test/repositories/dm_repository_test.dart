// ABOUTME: Unit tests for DmRepository.
// ABOUTME: Tests static helpers, send validation, receive pipeline
// ABOUTME: (decryption, persistence, deduplication), query methods,
// ABOUTME: and subscription lifecycle.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/repositories/dm_sync_state.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/nip17_message_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNIP17MessageService extends Mock implements NIP17MessageService {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

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

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
    });

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockMessageService = _MockNIP17MessageService();
      mockDirectMessagesDao = _MockDirectMessagesDao();
      mockConversationsDao = _MockConversationsDao();

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
    });

    DmRepository createRepository({
      String? userPubkey,
      RumorDecryptor? rumorDecryptor,
      Nip04Decryptor? nip04Decryptor,
      DmSyncState? syncState,
    }) {
      return DmRepository(
        nostrClient: mockNostrClient,
        messageService: mockMessageService,
        directMessagesDao: mockDirectMessagesDao,
        conversationsDao: mockConversationsDao,
        userPubkey: userPubkey ?? _validPubkeyA,
        signer: LocalNostrSigner(_validPrivateKey),
        rumorDecryptor: rumorDecryptor,
        nip04Decryptor: nip04Decryptor,
        syncState: syncState,
      );
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

      test('persists message and conversation on success', () async {
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
        ).thenAnswer((_) async => null);

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
        when(
          () => mockMessageService.sendPrivateMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            eventKind: any(named: 'eventKind'),
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.failure('Relay rejected'),
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
          ),
        );
      });
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

        repository.startListening();
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

        repository.startListening();
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

        final repository = createRepository();
        await repository.startListening();

        verify(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).called(1);

        controller.close();
      });

      test('startListening is idempotent', () async {
        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        final repository = createRepository();
        await repository.startListening();
        await repository.startListening(); // Second call is no-op

        verify(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).called(1);

        controller.close();
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

        repository.startListening();
        await repository.stopListening();
        repository.startListening();

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
        final repository = DmRepository(
          nostrClient: mockNostrClient,
          messageService: mockMessageService,
          directMessagesDao: mockDirectMessagesDao,
          conversationsDao: mockConversationsDao,
          // Intentionally no userPubkey/signer — initialize() provides them.
        );

        repository.setCredentials(
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
        final repository = DmRepository(
          nostrClient: mockNostrClient,
          directMessagesDao: mockDirectMessagesDao,
          conversationsDao: mockConversationsDao,
        );

        repository.setCredentials(
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
        repository.startListening();

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
          repository.startListening();

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
          repository.startListening();

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
          (_) async => NIP17SendResult.failure('Relay rejected'),
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
          ),
        );
      });
    });

    // -----------------------------------------------------------------
    // Moderation DM scenarios (TC-SOCIAL-025 / TC-SOCIAL-026)
    // -----------------------------------------------------------------

    group('moderation DM scenarios', () {
      /// The fallback moderation pubkey from [ModerationLabelService].
      const moderationPubkey =
          ModerationLabelService.fallbackModerationPubkeyHex;

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
              recipientPubkey: moderationPubkey,
            ),
          );
          stubDaoInserts();
          // Stub publishEvent for the NIP-04 fallback (fire-and-forget)
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => null);

          final repository = createRepository();

          final result = await repository.sendMessage(
            recipientPubkey: moderationPubkey,
            content: reportContent,
          );

          expect(result.success, isTrue);

          verify(
            () => mockMessageService.sendPrivateMessage(
              recipientPubkey: moderationPubkey,
              content: reportContent,
              eventKind: any(named: 'eventKind'),
              additionalTags: any(named: 'additionalTags'),
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
              'ff0011223344556677889900aabbccddeeff0011223344556677889900aabbcc';

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
              recipientPubkey: externalUserPubkey,
            ),
          );
          stubDaoInserts();
          // Stub publishEvent for the NIP-04 fallback (fire-and-forget)
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => null);

          final repository = createRepository();

          final result = await repository.sendMessage(
            recipientPubkey: externalUserPubkey,
            content: 'Hello from Divine!',
          );

          expect(result.success, isTrue);

          verify(
            () => mockMessageService.sendPrivateMessage(
              recipientPubkey: externalUserPubkey,
              content: 'Hello from Divine!',
              eventKind: any(named: 'eventKind'),
              additionalTags: any(named: 'additionalTags'),
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
            (_) async => Event.fromJson({
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
            () => mockMessageService.sendPrivateMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
              eventKind: any(named: 'eventKind'),
              additionalTags: any(named: 'additionalTags'),
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
            () => mockMessageService.sendPrivateMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
              eventKind: any(named: 'eventKind'),
              additionalTags: any(named: 'additionalTags'),
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
          ).thenAnswer((_) async => _FakeEvent());

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

          repository.startListening();
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
  });
}
