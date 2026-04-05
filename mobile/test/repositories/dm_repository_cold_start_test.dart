// ABOUTME: Regression tests for DM cold-start performance (#2766).
// ABOUTME: Asserts that setCredentials() triggers zero relay subscription,
// ABOUTME: polling, or event-processing activity. The subscription is
// ABOUTME: only started when startListening() is called explicitly.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/services/nip17_message_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNIP17MessageService extends Mock implements NIP17MessageService {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

class _FakeEvent extends Fake implements Event {}

// Valid 64-character hex keys for testing.
const _validPubkeyA =
    'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
const _validPubkeyB =
    'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
const _validPrivateKey =
    'd4e5f6789012345678901234567890abcdef1234567890123456789012ab12c3';

void main() {
  group('DmRepository cold-start (#2766)', () {
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

      when(() => mockNostrClient.connectedRelayCount).thenReturn(3);
      when(() => mockNostrClient.configuredRelayCount).thenReturn(3);
    });

    DmRepository createBareRepository() {
      return DmRepository(
        nostrClient: mockNostrClient,
        directMessagesDao: mockDirectMessagesDao,
        conversationsDao: mockConversationsDao,
      );
    }

    // -----------------------------------------------------------------
    // setCredentials — zero side effects
    // -----------------------------------------------------------------

    group('setCredentials', () {
      test('triggers zero subscribe calls', () {
        final repository = createBareRepository();

        repository.setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );

        verifyNever(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        );
      });

      test('triggers zero queryEvents calls', () {
        final repository = createBareRepository();

        repository.setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );

        verifyNever(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            useCache: any(named: 'useCache'),
          ),
        );
      });

      test('triggers zero hasGiftWrap calls', () {
        final repository = createBareRepository();

        repository.setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );

        verifyNever(() => mockDirectMessagesDao.hasGiftWrap(any()));
      });

      test('triggers zero insertMessage calls', () {
        final repository = createBareRepository();

        repository.setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );

        verifyNever(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      });

      test('triggers zero getAllConversations calls (no merge)', () {
        final repository = createBareRepository();

        repository.setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );

        verifyNever(
          () => mockConversationsDao.getAllConversations(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      });

      test('sets isInitialized to true', () {
        final repository = createBareRepository();

        expect(repository.isInitialized, isFalse);

        repository.setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );

        expect(repository.isInitialized, isTrue);
      });

      test('is idempotent for the same user', () {
        final repository = createBareRepository();

        repository.setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );
        repository.setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );

        expect(repository.isInitialized, isTrue);
        verifyNever(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        );
      });
    });

    // -----------------------------------------------------------------
    // Read operations work without startListening
    // -----------------------------------------------------------------

    group('read operations without subscription', () {
      test('watchConversations works after setCredentials', () {
        final participants = [_validPubkeyA, _validPubkeyB]..sort();
        final convId = DmRepository.computeConversationId(participants);
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        when(
          () => mockConversationsDao.watchAllConversations(
            limit: any(named: 'limit'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) => Stream.value([
            ConversationRow(
              id: convId,
              participantPubkeys: '["$_validPubkeyA","$_validPubkeyB"]',
              isGroup: false,
              createdAt: now,
              lastMessageTimestamp: now,
              isRead: true,
              currentUserHasSent: true,
              dmProtocol: 'nip17',
            ),
          ]),
        );

        final repository = createBareRepository();
        repository.setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );

        expect(
          repository.watchConversations(),
          emits(isA<List<DmConversation>>()),
        );

        // Still no subscription activity.
        verifyNever(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        );
      });
    });

    // -----------------------------------------------------------------
    // Poller is gone
    // -----------------------------------------------------------------

    group('no poller after startListening', () {
      test('queryEvents is never called after startListening', () async {
        final controller = StreamController<Event>();
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => controller.stream);

        when(
          () => mockConversationsDao.getNewestMessageTimestamp(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => mockConversationsDao.getAllConversations(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => []);

        final repository = createBareRepository();
        repository.setCredentials(
          userPubkey: _validPubkeyA,
          signer: LocalNostrSigner(_validPrivateKey),
          messageService: mockMessageService,
        );
        await repository.startListening();

        // Advance past where the old 10s poll would have fired.
        await Future<void>.delayed(const Duration(seconds: 12));

        verifyNever(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            useCache: any(named: 'useCache'),
          ),
        );

        await controller.close();
        await repository.stopListening();
      });
    });
  });
}
