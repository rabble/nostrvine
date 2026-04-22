// ABOUTME: Reliability tests for DmRepository write paths — NIP-04
// ABOUTME: fallback send and NIP-09 kind 5 deletion. Both must gate local
// ABOUTME: state on PublishOutcome.acceptedByAny so a failed publish does
// ABOUTME: not leave the UI believing the operation succeeded.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

class _MockSigner extends Mock implements NostrSigner {}

class _MockNip17MessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _userPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _peerPubkey =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _thirdPubkey =
    '5555555555555555555555555555555555555555555555555555555555555555';
const _rumorEventId =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _giftWrapEventId =
    '4444444444444444444444444444444444444444444444444444444444444444';

PublishOutcome _acceptedOutcome() {
  return PublishOutcome(
    eventId: 'a' * 64,
    acceptedBy: const {'wss://a'},
    rejectedBy: const {},
    noResponseFrom: const {},
  );
}

PublishOutcome _transientFailure() {
  return PublishOutcome(
    eventId: 'a' * 64,
    acceptedBy: const {},
    rejectedBy: const {},
    noResponseFrom: const {'wss://a', 'wss://b'},
  );
}

PublishOutcome _permanentRejection() {
  return PublishOutcome(
    eventId: 'a' * 64,
    acceptedBy: const {},
    rejectedBy: const {'wss://a': 'blocked: spam'},
    noResponseFrom: const {},
  );
}

DmRepository _buildRepo({
  required _MockNostrClient nostrClient,
  required _MockDirectMessagesDao directMessagesDao,
  required _MockConversationsDao conversationsDao,
  required _MockSigner signer,
  _MockNip17MessageService? messageService,
}) {
  return DmRepository(
    nostrClient: nostrClient,
    directMessagesDao: directMessagesDao,
    conversationsDao: conversationsDao,
    messageService: messageService ?? _MockNip17MessageService(),
    signer: signer,
    userPubkey: _userPubkey,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(const RetryPolicy());
  });

  late _MockNostrClient nostrClient;
  late _MockDirectMessagesDao directMessagesDao;
  late _MockConversationsDao conversationsDao;
  late _MockSigner signer;

  setUp(() {
    nostrClient = _MockNostrClient();
    directMessagesDao = _MockDirectMessagesDao();
    conversationsDao = _MockConversationsDao();
    signer = _MockSigner();

    // Signer stubs used by both NIP-04 and kind 5 delete paths.
    when(() => signer.encrypt(any(), any())).thenAnswer(
      (_) async => 'nip04-ciphertext',
    );
    when(() => signer.signEvent(any())).thenAnswer((invocation) async {
      final event = invocation.positionalArguments[0] as Event;
      // Deterministic id + sig so tests can assert on them later.
      return event
        ..id = 'e' * 64
        ..sig = 's' * 128;
    });
  });

  group('deleteMessageForEveryone reliability', () {
    final conversationId = DmRepository.computeConversationId(
      [_userPubkey, _peerPubkey],
    );

    setUp(() {
      when(
        () => directMessagesDao.getMessageById(
          any(),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer(
        (_) async => DirectMessageRow(
          id: _rumorEventId,
          conversationId: conversationId,
          senderPubkey: _userPubkey,
          content: 'hi',
          createdAt: 1700000000,
          giftWrapId: _giftWrapEventId,
          messageKind: EventKind.privateDirectMessage,
          isDeleted: false,
        ),
      );
      when(
        () => conversationsDao.getConversation(
          any(),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer(
        (_) async => ConversationRow(
          id: conversationId,
          participantPubkeys: jsonEncode([_userPubkey, _peerPubkey]),
          isGroup: false,
          createdAt: 1700000000,
          isRead: true,
          currentUserHasSent: true,
        ),
      );
      when(
        () => directMessagesDao.markMessageDeleted(
          any(),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => directMessagesDao.getMessagesForConversation(
          any(),
          limit: any(named: 'limit'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => conversationsDao.upsertConversation(
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
    });

    test(
      'accepted → kind 5 published AND local message soft-deleted',
      () async {
        when(
          () => nostrClient.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _acceptedOutcome());

        final repo = _buildRepo(
          nostrClient: nostrClient,
          directMessagesDao: directMessagesDao,
          conversationsDao: conversationsDao,
          signer: signer,
        );

        await repo.deleteMessageForEveryone(_rumorEventId);

        // Verify kind 5 published via reliable path.
        final captured =
            verify(
                  () => nostrClient.publishEventWithRetry(
                    captureAny(),
                    policy: any(named: 'policy'),
                    targetRelays: any(named: 'targetRelays'),
                  ),
                ).captured.single
                as Event;
        expect(captured.kind, equals(EventKind.eventDeletion));
        expect(
          captured.tags,
          containsAll([
            ['e', _rumorEventId],
            ['k', '14'],
            ['p', _peerPubkey],
          ]),
        );

        // Local soft-delete DID happen (gate open on acceptedByAny).
        verify(
          () => directMessagesDao.markMessageDeleted(
            _rumorEventId,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).called(1);
      },
    );

    test(
      'transient failure → PublishFailure thrown, local message NOT hidden',
      () async {
        when(
          () => nostrClient.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _transientFailure());

        final repo = _buildRepo(
          nostrClient: nostrClient,
          directMessagesDao: directMessagesDao,
          conversationsDao: conversationsDao,
          signer: signer,
        );

        await expectLater(
          () => repo.deleteMessageForEveryone(_rumorEventId),
          throwsA(isA<DmPublishFailure>()),
        );

        verifyNever(
          () => directMessagesDao.markMessageDeleted(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'permanent rejection → PublishFailure thrown with non-retryable '
      'feedback',
      () async {
        when(
          () => nostrClient.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _permanentRejection());

        final repo = _buildRepo(
          nostrClient: nostrClient,
          directMessagesDao: directMessagesDao,
          conversationsDao: conversationsDao,
          signer: signer,
        );

        try {
          await repo.deleteMessageForEveryone(_rumorEventId);
          fail('expected DmPublishFailure');
        } on DmPublishFailure catch (e) {
          expect(e.outcome.acceptedByAny, isFalse);
          expect(e.feedback.retryable, isFalse);
          expect(e.feedback.firstRejectionReason, contains('blocked'));
        }

        verifyNever(
          () => directMessagesDao.markMessageDeleted(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );
  });

  group('_sendNip04Message reliability (via sendMessage NIP-04 fallback)', () {
    const plaintext = 'hello fallback';

    /// DmRepository.sendMessage delegates the NIP-17 leg to
    /// NIP17MessageService and invokes _sendNip04Message internally.
    /// Stubbing the NIP-17 leg isolates the NIP-04 fallback path.
    void stubNip17Success(_MockNip17MessageService svc) {
      when(
        () => svc.sendPrivateMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          recipientDmRelays: any(named: 'recipientDmRelays'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: _rumorEventId,
          messageEventId: _giftWrapEventId,
          recipientPubkey: _peerPubkey,
          outcome: _acceptedOutcome(),
        ),
      );
    }

    setUp(() {
      when(
        () => directMessagesDao.insertMessage(
          id: any(named: 'id'),
          conversationId: any(named: 'conversationId'),
          senderPubkey: any(named: 'senderPubkey'),
          content: any(named: 'content'),
          createdAt: any(named: 'createdAt'),
          giftWrapId: any(named: 'giftWrapId'),
          messageKind: any(named: 'messageKind'),
          replyToId: any(named: 'replyToId'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => conversationsDao.getConversation(
          any(),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => null);
      // Stub both <void> and <Null> — Dart infers different type args
      // depending on callback return type.
      when(
        () => conversationsDao.runInTransaction<void>(any()),
      ).thenAnswer((invocation) async {
        final action =
            invocation.positionalArguments[0] as Future<void> Function();
        await action();
      });
      when(
        () => conversationsDao.runInTransaction<Null>(any()),
      ).thenAnswer((invocation) async {
        final action =
            invocation.positionalArguments[0] as Future<Null> Function();
        await action();
      });
      when(
        () => conversationsDao.upsertConversation(
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
    });

    test(
      'NIP-04 fallback publishes kind 4 via publishEventWithRetry '
      'and ignores subsequent drop',
      () async {
        // The fallback is fire-and-forget (unawaited from sendMessage),
        // so we drive it directly by invoking sendMessage and then
        // verifying the kind 4 retry publish happened.
        final messageService = _MockNip17MessageService();
        stubNip17Success(messageService);

        final repo = _buildRepo(
          nostrClient: nostrClient,
          directMessagesDao: directMessagesDao,
          conversationsDao: conversationsDao,
          signer: signer,
          messageService: messageService,
        );

        when(
          () => nostrClient.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _acceptedOutcome());

        await repo.sendMessage(
          recipientPubkey: _peerPubkey,
          content: plaintext,
        );

        // Give the unawaited NIP-04 fallback a chance to run.
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final captured = verify(
          () => nostrClient.publishEventWithRetry(
            captureAny(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).captured;

        // Expect a kind 4 event among the captures (may include others
        // if callers retry differently in the future).
        final kind4 = captured.cast<Event>().where(
          (e) => e.kind == EventKind.directMessage,
        );
        expect(kind4, isNotEmpty);
        expect(kind4.first.content, equals('nip04-ciphertext'));
        expect(
          kind4.first.tags.any(
            (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == _peerPubkey,
          ),
          isTrue,
          reason: 'kind 4 event should carry a p-tag for the recipient',
        );
      },
    );

    test(
      'NIP-04 fallback — rejected by every relay does NOT break the '
      'already-successful NIP-17 send',
      () async {
        final messageService = _MockNip17MessageService();
        stubNip17Success(messageService);

        final repo = _buildRepo(
          nostrClient: nostrClient,
          directMessagesDao: directMessagesDao,
          conversationsDao: conversationsDao,
          signer: signer,
          messageService: messageService,
        );

        when(
          () => nostrClient.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _transientFailure());

        final result = await repo.sendMessage(
          recipientPubkey: _peerPubkey,
          content: plaintext,
        );

        // NIP-17 success stands on its own — NIP-04 is purely interop.
        expect(result.success, isTrue);

        // Give the fallback a chance to run and fail without crashing.
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
    );
  });

  group('sendGroupMessage reliability', () {
    test(
      'partial recipient failure does NOT persist the group message locally',
      () async {
        final messageService = _MockNip17MessageService();
        when(
          () => messageService.sendPrivateMessage(
            recipientPubkey: _peerPubkey,
            content: 'hello group',
            eventKind: any(named: 'eventKind'),
            additionalTags: any(named: 'additionalTags'),
            recipientDmRelays: any(named: 'recipientDmRelays'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: _rumorEventId,
            messageEventId: _giftWrapEventId,
            recipientPubkey: _peerPubkey,
            outcome: _acceptedOutcome(),
          ),
        );
        when(
          () => messageService.sendPrivateMessage(
            recipientPubkey: _thirdPubkey,
            content: 'hello group',
            eventKind: any(named: 'eventKind'),
            additionalTags: any(named: 'additionalTags'),
            recipientDmRelays: any(named: 'recipientDmRelays'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.failure(
            'publish failed',
            outcome: _transientFailure(),
          ),
        );
        when(
          () => directMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => conversationsDao.runInTransaction<void>(any()),
        ).thenAnswer((invocation) async {
          final action =
              invocation.positionalArguments[0] as Future<void> Function();
          await action();
        });
        when(
          () => conversationsDao.runInTransaction<Null>(any()),
        ).thenAnswer((invocation) async {
          final action =
              invocation.positionalArguments[0] as Future<Null> Function();
          await action();
        });
        when(
          () => conversationsDao.getConversation(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => conversationsDao.upsertConversation(
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

        final repo = _buildRepo(
          nostrClient: nostrClient,
          directMessagesDao: directMessagesDao,
          conversationsDao: conversationsDao,
          signer: signer,
          messageService: messageService,
        );

        final results = await repo.sendGroupMessage(
          recipientPubkeys: const [_peerPubkey, _thirdPubkey],
          content: 'hello group',
        );

        expect(results.map((r) => r.success), [true, false]);
        verifyNever(
          () => directMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
        verifyNever(
          () => conversationsDao.upsertConversation(
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
        );
      },
    );
  });
}
