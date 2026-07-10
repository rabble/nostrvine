// ABOUTME: Unit tests for DmReactionsRepository.
// ABOUTME: Covers publish/retry/remove/receive flows plus wrapped kind-5
// ABOUTME: deletion handling and account-scoped watch behaviour.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';

class _MockDmReactionsDao extends Mock implements DmReactionsDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockNip17MessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _ownerPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _otherPubkey =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
const _conversationId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _targetMessageId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _reactionRumorId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _giftWrapId =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  group(DmReactionsRepository, () {
    late _MockDmReactionsDao mockDao;
    late _MockNip17MessageService mockMessageService;
    late List<String> reporterSites;

    DmReactionsRepository createRepository({
      bool initialized = true,
      ConversationsDao? conversationsDao,
      DirectMessagesDao? directMessagesDao,
    }) {
      final repository = DmReactionsRepository(
        reactionsDao: mockDao,
        conversationsDao: conversationsDao,
        directMessagesDao: directMessagesDao,
        errorReporter: (_, _, {required site}) {
          reporterSites.add(site);
        },
      );
      if (initialized) {
        repository.setCredentials(
          userPubkey: _ownerPubkey,
          messageService: mockMessageService,
        );
      }
      return repository;
    }

    Event reactionRumor({
      String id = _reactionRumorId,
      String reactorPubkey = _ownerPubkey,
      String content = '🔥',
      List<List<String>>? tags,
      int createdAt = 1_700_000_000,
      int kind = EventKind.reaction,
    }) {
      return Event.fromJson({
        'id': id,
        'pubkey': reactorPubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags':
            tags ??
            [
              ['e', _targetMessageId],
              ['p', _otherPubkey],
              ['k', EventKind.privateDirectMessage.toString()],
            ],
        'content': content,
        'sig': '',
      });
    }

    DmReactionRow makeRow({
      String id = _reactionRumorId,
      String reactorPubkey = _ownerPubkey,
      String emoji = '🔥',
      String? giftWrapId,
      bool isDeleted = false,
      String? rumorEventJson,
      String? publishStatus,
      String targetAuthor = _otherPubkey,
      String targetMessageId = _targetMessageId,
      int createdAt = 1_700_000_000,
    }) {
      return DmReactionRow(
        id: id,
        conversationId: _conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: targetAuthor,
        reactorPubkey: reactorPubkey,
        emoji: emoji,
        createdAt: createdAt,
        giftWrapId: giftWrapId,
        ownerPubkey: _ownerPubkey,
        isDeleted: isDeleted,
        rumorEventJson: rumorEventJson,
        publishStatus: publishStatus,
      );
    }

    setUp(() {
      mockDao = _MockDmReactionsDao();
      mockMessageService = _MockNip17MessageService();
      reporterSites = <String>[];

      // Default: no row for getById. removeOwn/retry look the reacted row up
      // to resolve the conversation's wrap-recipient set; with no
      // ConversationsDao wired (1:1 path), the resolver falls back to
      // [targetMessageAuthor]. Per-test stubs override this where needed.
      when(
        () => mockDao.getById(
          id: any(named: 'id'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => null);
    });

    test('watchForConversation returns empty when uninitialized', () async {
      final repository = createRepository(initialized: false);

      await expectLater(
        repository.watchForConversation(_conversationId),
        emits(const <DmReaction>[]),
      );
    });

    test('clearCredentials resets initialization state', () {
      final repository = createRepository();

      expect(repository.isInitialized, isTrue);
      repository.clearCredentials();
      expect(repository.isInitialized, isFalse);
    });

    test('watchForConversation maps dao rows to models', () async {
      when(
        () => mockDao.watchForConversation(
          conversationId: _conversationId,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer(
        (_) => Stream.value([
          makeRow(
            reactorPubkey: _otherPubkey,
            emoji: '😂',
            giftWrapId: _giftWrapId,
          ),
        ]),
      );

      final repository = createRepository();
      final reactions = await repository
          .watchForConversation(_conversationId)
          .first;

      expect(reactions, hasLength(1));
      expect(reactions.single.id, _reactionRumorId);
      expect(reactions.single.publishStatus, DmReactionPublishStatus.received);
    });

    test(
      'watchForConversation collapses duplicate live rows for one reactor, '
      'keeping the most recent',
      () async {
        // Cap-at-one violated in storage: the same reactor has three live
        // rows (a superseding kind-5 deletion never landed). The read layer
        // must collapse to the latest so the pill shows one avatar/emoji.
        when(
          () => mockDao.watchForConversation(
            conversationId: _conversationId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer(
          // All three are the owner (makeRow's default reactor).
          (_) => Stream.value([
            makeRow(id: 'a' * 64, createdAt: 1_700_000_001),
            makeRow(id: 'b' * 64, emoji: '😮', createdAt: 1_700_000_010),
            makeRow(id: 'c' * 64, emoji: '😂', createdAt: 1_700_000_020),
          ]),
        );

        final repository = createRepository();
        final reactions = await repository
            .watchForConversation(_conversationId)
            .first;

        expect(reactions, hasLength(1));
        expect(reactions.single.id, 'c' * 64);
        expect(reactions.single.emoji, '😂');
      },
    );

    test(
      'watchForConversation keeps distinct reactors and distinct messages '
      'separate',
      () async {
        const otherMessageId =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        when(
          () => mockDao.watchForConversation(
            conversationId: _conversationId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer(
          (_) => Stream.value([
            // Owner + the other participant on the same message → both kept.
            makeRow(id: 'a' * 64, createdAt: 1_700_000_001),
            makeRow(
              id: 'b' * 64,
              reactorPubkey: _otherPubkey,
              emoji: '😂',
              createdAt: 1_700_000_005,
            ),
            // Owner again, but a different message → kept (collapse is keyed
            // per message, not per reactor alone).
            makeRow(
              id: 'd' * 64,
              emoji: '😮',
              targetMessageId: otherMessageId,
              createdAt: 1_700_000_010,
            ),
          ]),
        );

        final repository = createRepository();
        final reactions = await repository
            .watchForConversation(_conversationId)
            .first;

        expect(reactions, hasLength(3));
        // Ascending createdAt order preserved for the pill's reversed render.
        expect(
          reactions.map((r) => r.id).toList(),
          ['a' * 64, 'b' * 64, 'd' * 64],
        );
      },
    );

    test('publish returns failure when repository is uninitialized', () async {
      final repository = createRepository(initialized: false);

      final result = await repository.publish(
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _otherPubkey,
        emoji: '🔥',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('not initialized'));
    });

    test(
      'publish inserts optimistic row and swaps to sent on success',
      () async {
        final rumor = reactionRumor();
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: rumor.id,
            conversationId: _conversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            reactorPubkey: _ownerPubkey,
            emoji: '🔥',
            createdAt: rumor.createdAt,
            ownerPubkey: _ownerPubkey,
            rumorEventJson: jsonEncode(rumor.toJson()),
          ),
        ).thenAnswer((_) async => <String>[]);
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: rumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );
        when(
          () => mockDao.swapPlaceholderId(
            placeholderId: rumor.id,
            realRumorId: rumor.id,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.publish(
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          emoji: '🔥',
        );

        expect(result.success, isTrue);
        verify(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: rumor.id,
            conversationId: _conversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            reactorPubkey: _ownerPubkey,
            emoji: '🔥',
            createdAt: rumor.createdAt,
            ownerPubkey: _ownerPubkey,
            rumorEventJson: jsonEncode(rumor.toJson()),
          ),
        ).called(1);
        verify(
          () => mockDao.swapPlaceholderId(
            placeholderId: rumor.id,
            realRumorId: rumor.id,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
        // The reaction send opts into NIP-20 OK-confirmation so a flaky
        // relay's frame-accept false positive can't mark it delivered.
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: true,
          ),
        ).called(1);
      },
    );

    test(
      'publish supersedes a prior reaction DURABLY: records a '
      'deletion_pending row for it and OK-confirms the kind-5, so a '
      'flaky/offline relay can no longer strand the old emoji',
      () async {
        const priorReactionId =
            '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
        final rumor = reactionRumor();
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', priorReactionId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: any(named: 'placeholderId'),
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            reactorPubkey: any(named: 'reactorPubkey'),
            emoji: any(named: 'emoji'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
            rumorEventJson: any(named: 'rumorEventJson'),
          ),
        ).thenAnswer((_) async => <String>[priorReactionId]);
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: '',
            eventKind: EventKind.eventDeletion,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(deletionRumor);
        when(
          () => mockDao.markOwnDeletionPending(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockDao.markDeletionSent(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: any(named: 'recipientPubkey'),
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: rumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );
        when(
          () => mockDao.swapPlaceholderId(
            placeholderId: any(named: 'placeholderId'),
            realRumorId: any(named: 'realRumorId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.publish(
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          emoji: '🔥',
        );
        // The kind-5 drive fires via unawaited; let it run.
        await Future<void>.delayed(Duration.zero);

        expect(result.success, isTrue);
        // The superseded emoji's removal is recorded as a durable
        // deletion_pending row (the retry sweep's recovery hook), storing the
        // exact kind-5 rumor keyed by the prior reaction id.
        verify(
          () => mockDao.markOwnDeletionPending(
            id: priorReactionId,
            ownerPubkey: _ownerPubkey,
            deletionRumorJson: jsonEncode(deletionRumor.toJson()),
          ),
        ).called(1);
        // The kind-5 now OK-confirms (durable path), not best-effort
        // frame-accept.
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: any(named: 'recipientPubkey'),
            awaitRecipientOk: true,
          ),
        ).called(1);
        // Confirmed delivery clears the pending marker to terminal.
        verify(
          () => mockDao.markDeletionSent(
            id: priorReactionId,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
      },
    );

    test('publish marks failed when send returns failure', () async {
      final rumor = reactionRumor();
      when(
        () => mockMessageService.buildRumor(
          recipientPubkey: _otherPubkey,
          content: '🔥',
          eventKind: EventKind.reaction,
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenReturn(rumor);
      when(
        () => mockDao.insertOwnReactionSuperseding(
          placeholderId: rumor.id,
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          reactorPubkey: _ownerPubkey,
          emoji: '🔥',
          createdAt: rumor.createdAt,
          ownerPubkey: _ownerPubkey,
          rumorEventJson: jsonEncode(rumor.toJson()),
        ),
      ).thenAnswer((_) async => <String>[]);
      when(
        () => mockMessageService.sendRumor(
          rumorEvent: rumor,
          recipientPubkey: _otherPubkey,
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
        ),
      ).thenAnswer((_) async => const NIP17SendResult.failure('relay down'));
      when(
        () => mockDao.markFailed(
          placeholderId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async {});

      final repository = createRepository();
      final result = await repository.publish(
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _otherPubkey,
        emoji: '🔥',
      );

      expect(result.success, isFalse);
      verify(
        () => mockDao.markFailed(
          placeholderId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).called(1);
    });

    test(
      'publish marks BLOCKED (terminal, non-retryable) when the send policy '
      'refuses the recipient — never failed/pending, so the retry sweep and '
      'a chip re-tap both leave it alone',
      () async {
        final rumor = reactionRumor();
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: rumor.id,
            conversationId: _conversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            reactorPubkey: _ownerPubkey,
            emoji: '🔥',
            createdAt: rumor.createdAt,
            ownerPubkey: _ownerPubkey,
            rumorEventJson: jsonEncode(rumor.toJson()),
          ),
        ).thenAnswer((_) async => <String>[]);
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.blocked('policy refused'),
        );
        when(
          () => mockDao.markBlocked(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.publish(
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          emoji: '🔥',
        );

        expect(result.success, isFalse);
        verify(
          () => mockDao.markBlocked(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).called(1);
        verifyNever(
          () => mockDao.markFailed(
            placeholderId: any(named: 'placeholderId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
        verifyNever(
          () => mockDao.markPending(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'publish contains a thrown send: marks failed and surfaces the error '
      'instead of leaking the exception',
      () async {
        final rumor = reactionRumor();
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: rumor.id,
            conversationId: _conversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            reactorPubkey: _ownerPubkey,
            emoji: '🔥',
            createdAt: rumor.createdAt,
            ownerPubkey: _ownerPubkey,
            rumorEventJson: jsonEncode(rumor.toJson()),
          ),
        ).thenAnswer((_) async => <String>[]);
        // A thrown send (not a returned NIP17SendFailure) must still flip the
        // chip to 'failed' and surface the error — the outer catch must never
        // let the exception escape to the caller.
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenThrow(StateError('socket boom'));
        when(
          () => mockDao.markFailed(
            placeholderId: rumor.id,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.publish(
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          emoji: '🔥',
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('socket boom'));
        verify(
          () => mockDao.markFailed(
            placeholderId: rumor.id,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
      },
    );

    test(
      'publish keeps the row pending (not failed) on an unconfirmed send',
      () async {
        final rumor = reactionRumor();
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: rumor.id,
            conversationId: _conversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            reactorPubkey: _ownerPubkey,
            emoji: '🔥',
            createdAt: rumor.createdAt,
            ownerPubkey: _ownerPubkey,
            rumorEventJson: jsonEncode(rumor.toJson()),
          ),
        ).thenAnswer((_) async => <String>[]);
        // Frame written, no relay OK within the window (no explicit rejection).
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.failure(
            'unconfirmed',
            retryablePending: true,
          ),
        );
        when(
          () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.publish(
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          emoji: '🔥',
        );

        expect(result.success, isFalse);
        // A durable row exists, so the cubit keeps the chip; and an unconfirmed
        // send is not proof of loss, so keep it pending+retryable — never the
        // red 'failed' state a re-tap could delete.
        expect(result.optimisticInsertSucceeded, isTrue);
        verify(
          () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).called(1);
        verifyNever(
          () => mockDao.markFailed(
            placeholderId: any(named: 'placeholderId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test('publish reports optimistic insert failures', () async {
      final rumor = reactionRumor();
      when(
        () => mockMessageService.buildRumor(
          recipientPubkey: _otherPubkey,
          content: '🔥',
          eventKind: EventKind.reaction,
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenReturn(rumor);
      when(
        () => mockDao.insertOwnReactionSuperseding(
          placeholderId: any(named: 'placeholderId'),
          conversationId: any(named: 'conversationId'),
          targetMessageId: any(named: 'targetMessageId'),
          targetMessageAuthor: any(named: 'targetMessageAuthor'),
          reactorPubkey: any(named: 'reactorPubkey'),
          emoji: any(named: 'emoji'),
          createdAt: any(named: 'createdAt'),
          ownerPubkey: any(named: 'ownerPubkey'),
          rumorEventJson: any(named: 'rumorEventJson'),
        ),
      ).thenThrow(StateError('insert failed'));

      final repository = createRepository();
      final result = await repository.publish(
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _otherPubkey,
        emoji: '🔥',
      );

      expect(result.success, isFalse);
      expect(
        reporterSites,
        contains(DmReactionsRepositoryReportableSites.publishOptimisticInsert),
      );
    });

    test('retry replays stored rumor and clears failure on success', () async {
      final rumor = reactionRumor();
      when(
        () => mockDao.getRumorJson(id: rumor.id, ownerPubkey: _ownerPubkey),
      ).thenAnswer((_) async => jsonEncode(rumor.toJson()));
      when(
        () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
      ).thenAnswer((_) async {});
      when(
        () => mockMessageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: _otherPubkey,
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: rumor.id,
          messageEventId: _giftWrapId,
          recipientPubkey: _otherPubkey,
        ),
      );
      when(
        () => mockDao.swapPlaceholderId(
          placeholderId: rumor.id,
          realRumorId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async {});

      final repository = createRepository();
      final result = await repository.retry(
        rumorId: rumor.id,
        targetMessageAuthor: _otherPubkey,
      );

      expect(result.success, isTrue);
      verify(
        () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
      ).called(1);
      verify(
        () => mockDao.swapPlaceholderId(
          placeholderId: rumor.id,
          realRumorId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).called(1);
    });

    test('retry marks failed when no stored rumor exists', () async {
      when(
        () => mockDao.getRumorJson(
          id: _reactionRumorId,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async => null);

      final repository = createRepository();
      final result = await repository.retry(
        rumorId: _reactionRumorId,
        targetMessageAuthor: _otherPubkey,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('No stored rumor'));
    });

    test('retry marks failed when send returns failure', () async {
      final rumor = reactionRumor();
      when(
        () => mockDao.getRumorJson(id: rumor.id, ownerPubkey: _ownerPubkey),
      ).thenAnswer((_) async => jsonEncode(rumor.toJson()));
      when(
        () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
      ).thenAnswer((_) async {});
      when(
        () => mockMessageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: _otherPubkey,
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
        ),
      ).thenAnswer((_) async => const NIP17SendResult.failure('relay down'));
      when(
        () => mockDao.markFailed(
          placeholderId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async {});

      final repository = createRepository();
      final result = await repository.retry(
        rumorId: rumor.id,
        targetMessageAuthor: _otherPubkey,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'relay down');
      verify(
        () => mockDao.markFailed(
          placeholderId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).called(1);
    });

    test(
      'retry leaves the row pending (does not mark failed) on an unconfirmed '
      'send',
      () async {
        final rumor = reactionRumor();
        when(
          () => mockDao.getRumorJson(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async => jsonEncode(rumor.toJson()));
        when(
          () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async {});
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.failure(
            'unconfirmed',
            retryablePending: true,
          ),
        );

        final repository = createRepository();
        final result = await repository.retry(
          rumorId: rumor.id,
          targetMessageAuthor: _otherPubkey,
        );

        // The pre-send markPending stands; an unconfirmed retry must not flip
        // the row to 'failed' (the sweep keeps re-driving it).
        expect(result.success, isFalse);
        verifyNever(
          () => mockDao.markFailed(
            placeholderId: any(named: 'placeholderId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'retryableReactions projects failed and pending own reactions from '
      'the dao',
      () async {
        when(
          () => mockDao.getRetryableOwnReactions(ownerPubkey: _ownerPubkey),
        ).thenAnswer(
          (_) async => [
            makeRow(
              publishStatus: 'failed',
              rumorEventJson: '{}',
              createdAt: 1_700_000_100,
            ),
            makeRow(
              id: _giftWrapId,
              publishStatus: 'pending',
              rumorEventJson: '{}',
              createdAt: 1_700_000_200,
            ),
          ],
        );

        final repository = createRepository();
        final targets = await repository.retryableReactions();

        expect(targets, hasLength(2));
        expect(targets.first.rumorId, _reactionRumorId);
        expect(targets.first.targetMessageAuthor, _otherPubkey);
        expect(targets.first.publishStatus, 'failed');
        expect(targets.first.createdAt, 1_700_000_100);
        expect(targets.last.publishStatus, 'pending');
      },
    );

    test('retryableReactions returns empty when uninitialized', () async {
      final repository = createRepository(initialized: false);

      final targets = await repository.retryableReactions();

      expect(targets, isEmpty);
      verifyNever(
        () => mockDao.getRetryableOwnReactions(
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      );
    });

    test(
      'removeOwn durably records the kind-5 deletion and publishes it',
      () async {
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        when(
          () => mockDao.markOwnDeletionPending(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '',
            eventKind: EventKind.eventDeletion,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(deletionRumor);
        // Publish fails (e.g. offline) — the durable row stays pending for the
        // sweep, so markDeletionSent must NOT be called.
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('offline'));

        final repository = createRepository();
        await repository.removeOwn(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );
        // _driveDeletion fires via unawaited; let it run.
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockDao.markOwnDeletionPending(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).called(1);
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).called(1);
        verifyNever(
          () => mockDao.markDeletionSent(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'retryableDeletions projects pending own deletions from the dao',
      () async {
        when(
          () => mockDao.getRetryableOwnDeletions(ownerPubkey: _ownerPubkey),
        ).thenAnswer(
          (_) async => [
            makeRow(
              isDeleted: true,
              publishStatus: 'deletion_pending',
              rumorEventJson: '{}',
            ),
          ],
        );

        final repository = createRepository();
        final targets = await repository.retryableDeletions();

        expect(targets, hasLength(1));
        expect(targets.first.rumorId, _reactionRumorId);
        expect(targets.first.targetMessageAuthor, _otherPubkey);
      },
    );

    test(
      'retryDeletion replays the stored kind-5 and marks it sent on success',
      () async {
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        when(
          () =>
              mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
        ).thenAnswer(
          (_) async => makeRow(
            isDeleted: true,
            publishStatus: 'deletion_pending',
            rumorEventJson: jsonEncode(deletionRumor.toJson()),
          ),
        );
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: deletionRumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );
        when(
          () => mockDao.markDeletionSent(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.retryDeletion(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );

        expect(result.success, isTrue);
        verify(
          () => mockDao.markDeletionSent(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
      },
    );

    test(
      'retryDeletion TERMINALIZES a policy-blocked removal instead of looping '
      "— a blocked recipient can't receive the kind-5 and never had the "
      'reaction, so the sweep must stop re-driving it',
      () async {
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        when(
          () =>
              mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
        ).thenAnswer(
          (_) async => makeRow(
            isDeleted: true,
            publishStatus: 'deletion_pending',
            rumorEventJson: jsonEncode(deletionRumor.toJson()),
          ),
        );
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.blocked('policy refused'),
        );
        when(
          () => mockDao.markDeletionSent(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.retryDeletion(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );

        // Terminal — the sweep drops it from tracking (success) and the row
        // leaves the retryable-deletion set.
        expect(result.success, isTrue);
        verify(
          () => mockDao.markDeletionSent(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
      },
    );

    test('retryDeletion fails when no stored deletion exists', () async {
      // getById default stub returns null → nothing to replay.
      final repository = createRepository();
      final result = await repository.retryDeletion(
        rumorId: _reactionRumorId,
        targetMessageAuthor: _otherPubkey,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('No stored deletion'));
    });

    test('persistIncoming validates event shape before upsert', () async {
      final repository = createRepository();

      // Malformed content / missing e-tag are permanent drops — terminal, so
      // the wrap is recorded (processed) and not re-decrypted. #5452.
      final emptyContentOutcome = await repository.persistIncoming(
        rumorEvent: reactionRumor(content: ''),
        giftWrapId: _giftWrapId,
      );
      final missingTagOutcome = await repository.persistIncoming(
        rumorEvent: reactionRumor(
          tags: [
            ['p', _otherPubkey],
          ],
        ),
        giftWrapId: _giftWrapId,
      );

      expect(emptyContentOutcome, DmReactionWrapOutcome.processed);
      expect(missingTagOutcome, DmReactionWrapOutcome.processed);

      verifyNever(
        () => mockDao.upsertIncoming(
          id: any(named: 'id'),
          conversationId: any(named: 'conversationId'),
          targetMessageId: any(named: 'targetMessageId'),
          targetMessageAuthor: any(named: 'targetMessageAuthor'),
          reactorPubkey: any(named: 'reactorPubkey'),
          emoji: any(named: 'emoji'),
          createdAt: any(named: 'createdAt'),
          giftWrapId: any(named: 'giftWrapId'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      );
    });

    test('persistIncoming upserts valid reaction rumors', () async {
      when(
        () => mockDao.upsertIncoming(
          id: _reactionRumorId,
          conversationId: any(named: 'conversationId'),
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          reactorPubkey: _ownerPubkey,
          emoji: '🔥',
          createdAt: 1_700_000_000,
          giftWrapId: _giftWrapId,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async {});

      final repository = createRepository();
      final outcome = await repository.persistIncoming(
        rumorEvent: reactionRumor(),
        giftWrapId: _giftWrapId,
      );

      expect(outcome, DmReactionWrapOutcome.processed);
      verify(
        () => mockDao.upsertIncoming(
          id: _reactionRumorId,
          conversationId: any(named: 'conversationId'),
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          reactorPubkey: _ownerPubkey,
          emoji: '🔥',
          createdAt: 1_700_000_000,
          giftWrapId: _giftWrapId,
          ownerPubkey: _ownerPubkey,
        ),
      ).called(1);
    });

    test('persistIncoming reports dao upsert failures', () async {
      when(
        () => mockDao.upsertIncoming(
          id: _reactionRumorId,
          conversationId: any(named: 'conversationId'),
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          reactorPubkey: _ownerPubkey,
          emoji: '🔥',
          createdAt: 1_700_000_000,
          giftWrapId: _giftWrapId,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenThrow(StateError('boom'));

      final repository = createRepository();
      final outcome = await repository.persistIncoming(
        rumorEvent: reactionRumor(),
        giftWrapId: _giftWrapId,
      );

      // A transient DAO failure must NOT cement a skip — leave it deferred so
      // the wrap retries on a later launch. #5452.
      expect(outcome, DmReactionWrapOutcome.deferred);
      expect(
        reporterSites,
        contains(
          DmReactionsRepositoryReportableSites.persistIncomingDaoUpsert,
        ),
      );
    });

    test(
      'persistIncoming returns deferred when the conversation cannot be '
      'resolved (target not synced)',
      () async {
        // A third-party reaction (neither reactor nor target author is us) with
        // no synced target message: the conversation cannot be inferred, so the
        // wrap is left undecided to re-decrypt and land later. #5452.
        const thirdPubkey =
            '1111111111111111111111111111111111111111111111111111111111111111';
        final repository = createRepository();

        final outcome = await repository.persistIncoming(
          rumorEvent: reactionRumor(
            reactorPubkey: _otherPubkey,
            tags: [
              ['e', _targetMessageId],
              ['p', thirdPubkey],
            ],
          ),
          giftWrapId: _giftWrapId,
        );

        expect(outcome, DmReactionWrapOutcome.deferred);
        verifyNever(
          () => mockDao.upsertIncoming(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            reactorPubkey: any(named: 'reactorPubkey'),
            emoji: any(named: 'emoji'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'handleIncomingDeletion soft-deletes matching reaction rows',
      () async {
        when(
          () =>
              mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async => makeRow());
        when(
          () => mockDao.softDelete(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async => 1);

        final repository = createRepository();
        final outcome = await repository.handleIncomingDeletion(
          rumorEvent: reactionRumor(
            kind: EventKind.eventDeletion,
            content: '',
            tags: [
              ['e', _reactionRumorId],
              ['k', EventKind.reaction.toString()],
            ],
          ),
          giftWrapId: _giftWrapId,
        );

        // Terminal: the deletion wrap is recorded so it is not re-decrypted on
        // every launch. #5452.
        expect(outcome, DmReactionWrapOutcome.processed);
        verify(
          () => mockDao.softDelete(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
      },
    );

    test('handleIncomingDeletion ignores author mismatches', () async {
      when(
        () => mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
      ).thenAnswer((_) async => makeRow(reactorPubkey: _otherPubkey));

      final repository = createRepository();
      final outcome = await repository.handleIncomingDeletion(
        rumorEvent: reactionRumor(
          kind: EventKind.eventDeletion,
          content: '',
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        ),
        giftWrapId: _giftWrapId,
      );

      // An invalid deletion (author mismatch) will never apply — it is
      // terminal, so the wrap is recorded and not re-decrypted. #5452.
      expect(outcome, DmReactionWrapOutcome.processed);
      verifyNever(
        () => mockDao.softDelete(
          id: any(named: 'id'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      );
    });

    test(
      'handleIncomingDeletion defers when the target reaction has not synced',
      () async {
        // NIP-59 randomizes gift-wrap created_at, so a deletion can drain
        // before the reaction it removes. With the target row absent, recording
        // the deletion as terminal would let the reaction insert live later and
        // never be soft-deleted. Defer instead so the wrap re-decrypts and
        // applies once the reaction lands. #5452.
        when(
          () =>
              mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async => null);

        final repository = createRepository();
        final outcome = await repository.handleIncomingDeletion(
          rumorEvent: reactionRumor(
            kind: EventKind.eventDeletion,
            content: '',
            tags: [
              ['e', _reactionRumorId],
              ['k', EventKind.reaction.toString()],
            ],
          ),
          giftWrapId: _giftWrapId,
        );

        expect(outcome, DmReactionWrapOutcome.deferred);
        verifyNever(
          () => mockDao.softDelete(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'handleIncomingDeletion defers and reports on a soft-delete failure',
      () async {
        when(
          () =>
              mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async => makeRow());
        when(
          () => mockDao.softDelete(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenThrow(StateError('boom'));

        final repository = createRepository();
        final outcome = await repository.handleIncomingDeletion(
          rumorEvent: reactionRumor(
            kind: EventKind.eventDeletion,
            content: '',
            tags: [
              ['e', _reactionRumorId],
              ['k', EventKind.reaction.toString()],
            ],
          ),
          giftWrapId: _giftWrapId,
        );

        // A transient DAO failure must NOT cement a skip — leave it deferred so
        // the wrap retries on a later launch. #5452.
        expect(outcome, DmReactionWrapOutcome.deferred);
        expect(
          reporterSites,
          contains(
            DmReactionsRepositoryReportableSites
                .handleIncomingDeletionSoftDelete,
          ),
        );
      },
    );

    test(
      'publish addresses the wrap to the counterparty (not self) when '
      'reacting to your OWN message in a 1:1',
      () async {
        const oneToOneConversationId =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        final mockConversationsDao = _MockConversationsDao();
        when(
          () => mockConversationsDao.getConversation(
            oneToOneConversationId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer(
          (_) async => ConversationRow(
            id: oneToOneConversationId,
            participantPubkeys: jsonEncode([_ownerPubkey, _otherPubkey]),
            isGroup: false,
            isRead: true,
            currentUserHasSent: true,
            createdAt: 1700000000,
            ownerPubkey: _ownerPubkey,
          ),
        );
        // Reacting to our OWN sent message: the target author is us.
        final rumor = reactionRumor();
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _ownerPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: any(named: 'placeholderId'),
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            reactorPubkey: any(named: 'reactorPubkey'),
            emoji: any(named: 'emoji'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
            rumorEventJson: any(named: 'rumorEventJson'),
          ),
        ).thenAnswer((_) async => <String>[]);
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: any(named: 'recipientPubkey'),
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: rumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );
        when(
          () => mockDao.swapPlaceholderId(
            placeholderId: any(named: 'placeholderId'),
            realRumorId: any(named: 'realRumorId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository(
          conversationsDao: mockConversationsDao,
        );
        final result = await repository.publish(
          conversationId: oneToOneConversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _ownerPubkey, // our own message
          emoji: '🔥',
        );

        expect(result.success, isTrue);
        // The reaction wrap must reach the OTHER participant, never only self
        // — otherwise a reaction on a message the reactor authored is never
        // delivered to the counterparty.
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).called(1);
        verifyNever(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _ownerPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        );
      },
    );

    group('group reactions', () {
      const thirdPubkey =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const groupConversationId = 'group-convo-id';

      test(
        'publish fans the reaction wrap out to every group member',
        () async {
          final mockConversationsDao = _MockConversationsDao();
          when(
            () => mockConversationsDao.getConversation(
              groupConversationId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: groupConversationId,
              participantPubkeys: jsonEncode([
                _ownerPubkey,
                _otherPubkey,
                thirdPubkey,
              ]),
              isGroup: true,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1700000000,
              ownerPubkey: _ownerPubkey,
            ),
          );
          final rumor = reactionRumor();
          when(
            () => mockMessageService.buildRumor(
              recipientPubkey: _otherPubkey,
              content: '🔥',
              eventKind: EventKind.reaction,
              additionalTags: any(named: 'additionalTags'),
            ),
          ).thenReturn(rumor);
          when(
            () => mockDao.insertOwnReactionSuperseding(
              placeholderId: any(named: 'placeholderId'),
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: any(named: 'reactorPubkey'),
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              ownerPubkey: any(named: 'ownerPubkey'),
              rumorEventJson: any(named: 'rumorEventJson'),
            ),
          ).thenAnswer((_) async => <String>[]);
          when(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: rumor.id,
              messageEventId: _giftWrapId,
              recipientPubkey: _otherPubkey,
            ),
          );
          when(
            () => mockDao.swapPlaceholderId(
              placeholderId: any(named: 'placeholderId'),
              realRumorId: any(named: 'realRumorId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async {});

          final repository = createRepository(
            conversationsDao: mockConversationsDao,
          );
          final result = await repository.publish(
            conversationId: groupConversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            emoji: '🔥',
          );

          expect(result.success, isTrue);
          // Wrapped to BOTH non-self members (fan-out), not just the author.
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: _otherPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).called(1);
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: thirdPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).called(1);
        },
      );

      test(
        'publish does NOT mark a group reaction sent on PARTIAL fan-out — one '
        'member confirming while another fails must stay retryable, never '
        'swapped to sent (which would clear the rumor and strand the miss)',
        () async {
          final mockConversationsDao = _MockConversationsDao();
          when(
            () => mockConversationsDao.getConversation(
              groupConversationId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: groupConversationId,
              participantPubkeys: jsonEncode([
                _ownerPubkey,
                _otherPubkey,
                thirdPubkey,
              ]),
              isGroup: true,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1700000000,
              ownerPubkey: _ownerPubkey,
            ),
          );
          final rumor = reactionRumor();
          when(
            () => mockMessageService.buildRumor(
              recipientPubkey: _otherPubkey,
              content: '🔥',
              eventKind: EventKind.reaction,
              additionalTags: any(named: 'additionalTags'),
            ),
          ).thenReturn(rumor);
          when(
            () => mockDao.insertOwnReactionSuperseding(
              placeholderId: any(named: 'placeholderId'),
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: any(named: 'reactorPubkey'),
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              ownerPubkey: any(named: 'ownerPubkey'),
              rumorEventJson: any(named: 'rumorEventJson'),
            ),
          ).thenAnswer((_) async => <String>[]);
          // Member A confirms; member B hard-fails.
          when(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: _otherPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: rumor.id,
              messageEventId: _giftWrapId,
              recipientPubkey: _otherPubkey,
            ),
          );
          when(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: thirdPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure('relay down'),
          );
          when(
            () => mockDao.markFailed(
              placeholderId: any(named: 'placeholderId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async {});

          final repository = createRepository(
            conversationsDao: mockConversationsDao,
          );
          final result = await repository.publish(
            conversationId: groupConversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            emoji: '🔥',
          );

          expect(
            result.success,
            isFalse,
            reason: 'A partial fan-out is not a delivered reaction.',
          );
          // The critical invariant: the row must NOT be swapped to `sent`, or
          // swapPlaceholderId would clear rumor_event_json and the missed
          // member could never be re-driven.
          verifyNever(
            () => mockDao.swapPlaceholderId(
              placeholderId: any(named: 'placeholderId'),
              realRumorId: any(named: 'realRumorId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
          // Hard-failed member → the whole reaction is failed (kept
          // retryable), so the sweep re-drives the full rumor.
          verify(
            () => mockDao.markFailed(
              placeholderId: rumor.id,
              ownerPubkey: _ownerPubkey,
            ),
          ).called(1);
        },
      );

      test(
        'persistIncoming resolves the group conversation via the reel message',
        () async {
          final mockMessagesDao = _MockDirectMessagesDao();
          when(
            () => mockMessagesDao.getMessageById(
              _targetMessageId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer(
            (_) async => const DirectMessageRow(
              id: _targetMessageId,
              conversationId: groupConversationId,
              senderPubkey: _otherPubkey,
              content: 'reel',
              createdAt: 1700000000,
              giftWrapId: _giftWrapId,
              messageKind: 14,
              isDeleted: false,
              ownerPubkey: _ownerPubkey,
            ),
          );
          when(
            () => mockDao.upsertIncoming(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: any(named: 'reactorPubkey'),
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async {});

          final repository = createRepository(
            directMessagesDao: mockMessagesDao,
          );
          // A third party (neither us nor the author) reacts in the group.
          await repository.persistIncoming(
            rumorEvent: reactionRumor(reactorPubkey: thirdPubkey),
            giftWrapId: _giftWrapId,
          );

          verify(
            () => mockDao.upsertIncoming(
              id: any(named: 'id'),
              conversationId: groupConversationId,
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: thirdPubkey,
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).called(1);
        },
      );

      test(
        'persistIncoming drops a group reaction when the reel is unsynced',
        () async {
          final mockMessagesDao = _MockDirectMessagesDao();
          when(
            () => mockMessagesDao.getMessageById(
              _targetMessageId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer((_) async => null);

          final repository = createRepository(
            directMessagesDao: mockMessagesDao,
          );
          await repository.persistIncoming(
            rumorEvent: reactionRumor(reactorPubkey: thirdPubkey),
            giftWrapId: _giftWrapId,
          );

          verifyNever(
            () => mockDao.upsertIncoming(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: any(named: 'reactorPubkey'),
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
        },
      );
    });
  });
}
