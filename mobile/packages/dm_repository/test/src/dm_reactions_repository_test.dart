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
          () => mockDao.getOwnLiveReaction(
            targetMessageId: _targetMessageId,
            reactorPubkey: _ownerPubkey,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOptimistic(
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
        ).thenAnswer((_) async {});
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
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
          () => mockDao.insertOptimistic(
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
      },
    );

    test('publish marks failed when send returns failure', () async {
      final rumor = reactionRumor();
      when(
        () => mockDao.getOwnLiveReaction(
          targetMessageId: _targetMessageId,
          reactorPubkey: _ownerPubkey,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockMessageService.buildRumor(
          recipientPubkey: _otherPubkey,
          content: '🔥',
          eventKind: EventKind.reaction,
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenReturn(rumor);
      when(
        () => mockDao.insertOptimistic(
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
      ).thenAnswer((_) async {});
      when(
        () => mockMessageService.sendRumor(
          rumorEvent: rumor,
          recipientPubkey: _otherPubkey,
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

    test('publish reports optimistic insert failures', () async {
      final rumor = reactionRumor();
      when(
        () => mockDao.getOwnLiveReaction(
          targetMessageId: _targetMessageId,
          reactorPubkey: _ownerPubkey,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockMessageService.buildRumor(
          recipientPubkey: _otherPubkey,
          content: '🔥',
          eventKind: EventKind.reaction,
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenReturn(rumor);
      when(
        () => mockDao.insertOptimistic(
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
      'removeOwn soft-deletes locally and publishes wrapped kind 5',
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
          () => mockDao.softDelete(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async => 1);
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '',
            eventKind: EventKind.eventDeletion,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(deletionRumor);
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('ignored'));

        final repository = createRepository();
        await repository.removeOwn(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockDao.softDelete(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
          ),
        ).called(1);
      },
    );

    test('persistIncoming validates event shape before upsert', () async {
      final repository = createRepository();

      await repository.persistIncoming(
        rumorEvent: reactionRumor(content: ''),
        giftWrapId: _giftWrapId,
      );
      await repository.persistIncoming(
        rumorEvent: reactionRumor(
          tags: [
            ['p', _otherPubkey],
          ],
        ),
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
      await repository.persistIncoming(
        rumorEvent: reactionRumor(),
        giftWrapId: _giftWrapId,
      );

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
      await repository.persistIncoming(
        rumorEvent: reactionRumor(),
        giftWrapId: _giftWrapId,
      );

      expect(
        reporterSites,
        contains(
          DmReactionsRepositoryReportableSites.persistIncomingDaoUpsert,
        ),
      );
    });

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
        await repository.handleIncomingDeletion(
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
      await repository.handleIncomingDeletion(
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

      verifyNever(
        () => mockDao.softDelete(
          id: any(named: 'id'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      );
    });

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
          when(
            () => mockDao.getOwnLiveReaction(
              targetMessageId: _targetMessageId,
              reactorPubkey: _ownerPubkey,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer((_) async => null);
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
            () => mockDao.insertOptimistic(
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
          ).thenAnswer((_) async {});
          when(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
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
            ),
          ).called(1);
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: thirdPubkey,
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
