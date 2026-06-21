// ABOUTME: Cubit tests for ConversationReactionsCubit.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';

class _MockReactionsRepository extends Mock implements DmReactionsRepository {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _peer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _convo =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _msgId =
    'mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm';

void main() {
  group(ConversationReactionsCubit, () {
    late _MockReactionsRepository repo;
    late StreamController<List<DmReaction>> streamController;

    setUp(() {
      repo = _MockReactionsRepository();
      streamController = StreamController<List<DmReaction>>.broadcast();
      when(
        () => repo.watchForConversation(any()),
      ).thenAnswer((_) => streamController.stream);
    });

    tearDown(() async {
      await streamController.close();
    });

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'transitions through loading -> loaded on subscription tick',
      build: () => ConversationReactionsCubit(
        reactionsRepository: repo,
        ownerPubkey: _owner,
      ),
      act: (cubit) async {
        cubit.add(
          const ConversationReactionsStarted(conversationId: _convo),
        );
        await Future<void>.delayed(Duration.zero);
        streamController.add(const <DmReaction>[]);
      },
      expect: () => [
        isA<ConversationReactionsState>().having(
          (s) => s.status,
          'status',
          ConversationReactionsStatus.loading,
        ),
        isA<ConversationReactionsState>().having(
          (s) => s.status,
          'status',
          ConversationReactionsStatus.loaded,
        ),
      ],
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'toggle publishes; pending then cleared on success',
      build: () {
        when(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        ).thenAnswer(
          (_) async => const DmReactionPublishResult(
            success: true,
            rumorId: 'r-1',
          ),
        );
        return ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        );
      },
      act: (cubit) async {
        cubit.add(
          const ConversationReactionToggled(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '❤️',
          ),
        );
      },
      expect: () => [
        isA<ConversationReactionsState>().having(
          (s) =>
              s.pending[const ReactionPublishKey(
                messageId: _msgId,
                emoji: '❤️',
              )],
          'pending entry',
          ReactionPublishLocalStatus.sending,
        ),
        isA<ConversationReactionsState>().having(
          (s) => s.pending.isEmpty,
          'pending cleared',
          isTrue,
        ),
      ],
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'toggle publish failure marks pending as failed',
      build: () {
        when(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        ).thenAnswer(
          (_) async => const DmReactionPublishResult(
            success: false,
            rumorId: 'r-2',
            errorMessage: 'relay down',
          ),
        );
        return ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        );
      },
      act: (cubit) async {
        cubit.add(
          const ConversationReactionToggled(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '🔥',
          ),
        );
      },
      verify: (cubit) {
        final entry =
            cubit.state.pending[const ReactionPublishKey(
              messageId: _msgId,
              emoji: '🔥',
            )];
        expect(entry, ReactionPublishLocalStatus.failed);
      },
    );

    DmReaction ownReaction(String emoji) => DmReaction(
      id: 'own-$emoji',
      conversationId: _convo,
      targetMessageId: _msgId,
      targetMessageAuthor: _peer,
      reactorPubkey: _owner,
      emoji: emoji,
      createdAt: 1700000000,
      ownerPubkey: _owner,
      publishStatus: DmReactionPublishStatus.sent,
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'set publishes when there is no active reaction',
      build: () {
        when(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        ).thenAnswer(
          (_) async =>
              const DmReactionPublishResult(success: true, rumorId: 'r-set'),
        );
        return ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        );
      },
      act: (cubit) => cubit.add(
        const ConversationReactionSet(
          conversationId: _convo,
          messageId: _msgId,
          messageAuthorPubkey: _peer,
          emoji: '❤️',
        ),
      ),
      verify: (_) {
        verify(
          () => repo.publish(
            conversationId: _convo,
            targetMessageId: _msgId,
            targetMessageAuthor: _peer,
            emoji: '❤️',
          ),
        ).called(1);
      },
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'set is a no-op when the active emoji already matches',
      build: () {
        when(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        ).thenAnswer(
          (_) async =>
              const DmReactionPublishResult(success: true, rumorId: 'x'),
        );
        return ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        );
      },
      act: (cubit) async {
        cubit.add(const ConversationReactionsStarted(conversationId: _convo));
        await Future<void>.delayed(Duration.zero);
        streamController.add([ownReaction('❤️')]);
        await Future<void>.delayed(Duration.zero);
        cubit.add(
          const ConversationReactionSet(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '❤️',
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) {
        verifyNever(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        );
        // And it must NOT remove the active reaction (set != toggle).
        verifyNever(
          () => repo.removeOwn(
            rumorId: any(named: 'rumorId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
          ),
        );
      },
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'set with a different emoji publishes (supersede handled by repo)',
      build: () {
        when(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        ).thenAnswer(
          (_) async =>
              const DmReactionPublishResult(success: true, rumorId: 'r-new'),
        );
        return ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        );
      },
      act: (cubit) async {
        cubit.add(const ConversationReactionsStarted(conversationId: _convo));
        await Future<void>.delayed(Duration.zero);
        streamController.add([ownReaction('❤️')]);
        await Future<void>.delayed(Duration.zero);
        cubit.add(
          const ConversationReactionSet(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '😂',
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) {
        verify(
          () => repo.publish(
            conversationId: _convo,
            targetMessageId: _msgId,
            targetMessageAuthor: _peer,
            emoji: '😂',
          ),
        ).called(1);
      },
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'subscription tick groups reactions by message id',
      build: () => ConversationReactionsCubit(
        reactionsRepository: repo,
        ownerPubkey: _owner,
      ),
      act: (cubit) async {
        cubit.add(
          const ConversationReactionsStarted(conversationId: _convo),
        );
        await Future<void>.delayed(Duration.zero);
        streamController.add([
          const DmReaction(
            id: 'r-3',
            conversationId: _convo,
            targetMessageId: _msgId,
            targetMessageAuthor: _peer,
            reactorPubkey: _peer,
            emoji: '👍',
            createdAt: 1700000000,
            ownerPubkey: _owner,
            publishStatus: DmReactionPublishStatus.received,
          ),
        ]);
      },
      verify: (cubit) {
        final list = cubit.state.reactionsByMessageId[_msgId];
        expect(list, isNotNull);
        expect(list!.length, 1);
        expect(list.first.emoji, '👍');
      },
    );

    group('optimistic chip (#5389)', () {
      bool ownPending(ConversationReactionsState s, String emoji) => s
          .reactionsFor(_msgId)
          .any(
            (r) =>
                r.reactorPubkey == _owner &&
                r.emoji == emoji &&
                r.publishStatus == DmReactionPublishStatus.pending,
          );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'paints the own chip synchronously, before the publish resolves',
        build: () {
          when(
            () => repo.publish(
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              emoji: any(named: 'emoji'),
            ),
          ).thenAnswer(
            (_) async =>
                const DmReactionPublishResult(success: true, rumorId: 'r-1'),
          );
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) => cubit.add(
          const ConversationReactionToggled(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '❤️',
          ),
        ),
        expect: () => [
          // FIRST emit already carries the chip — no stream tick, no DB wait.
          isA<ConversationReactionsState>()
              .having(
                (s) => ownPending(s, '❤️'),
                'optimistic chip present',
                isTrue,
              )
              .having(
                (s) =>
                    s.pending[const ReactionPublishKey(
                      messageId: _msgId,
                      emoji: '❤️',
                    )],
                'pending sending',
                ReactionPublishLocalStatus.sending,
              ),
          // After publish: pending cleared, overlay still bridges until a tick.
          isA<ConversationReactionsState>()
              .having((s) => s.pending.isEmpty, 'pending cleared', isTrue)
              .having((s) => ownPending(s, '❤️'), 'chip still present', isTrue),
        ],
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'reconciles the optimistic add when the persisted row arrives (no dupe)',
        build: () {
          when(
            () => repo.publish(
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              emoji: any(named: 'emoji'),
            ),
          ).thenAnswer(
            (_) async =>
                const DmReactionPublishResult(success: true, rumorId: 'r-1'),
          );
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) async {
          cubit.add(const ConversationReactionsStarted(conversationId: _convo));
          await Future<void>.delayed(Duration.zero);
          cubit.add(
            const ConversationReactionToggled(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '❤️',
            ),
          );
          await Future<void>.delayed(Duration.zero);
          streamController.add([ownReaction('❤️')]);
          await Future<void>.delayed(Duration.zero);
        },
        verify: (cubit) {
          expect(cubit.state.optimistic, isEmpty);
          final chips = cubit.state
              .reactionsFor(_msgId)
              .where((r) => r.emoji == '❤️')
              .toList();
          expect(chips, hasLength(1));
          expect(chips.first.publishStatus, DmReactionPublishStatus.sent);
        },
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'toggle-off hides the own chip synchronously',
        build: () {
          when(
            () => repo.removeOwn(
              rumorId: any(named: 'rumorId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
            ),
          ).thenAnswer((_) async {});
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) async {
          cubit.add(const ConversationReactionsStarted(conversationId: _convo));
          await Future<void>.delayed(Duration.zero);
          streamController.add([ownReaction('❤️')]);
          await Future<void>.delayed(Duration.zero);
          cubit.add(
            const ConversationReactionToggled(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '❤️',
            ),
          );
          await Future<void>.delayed(Duration.zero);
        },
        verify: (cubit) {
          expect(
            cubit.state.reactionsFor(_msgId).any((r) => r.isOwn),
            isFalse,
          );
          verify(
            () => repo.removeOwn(
              rumorId: 'own-❤️',
              targetMessageAuthor: _peer,
            ),
          ).called(1);
        },
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'set with a different emoji optimistically swaps the chip',
        build: () {
          when(
            () => repo.publish(
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              emoji: any(named: 'emoji'),
            ),
          ).thenAnswer(
            (_) async =>
                const DmReactionPublishResult(success: true, rumorId: 'r-new'),
          );
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) async {
          cubit.add(const ConversationReactionsStarted(conversationId: _convo));
          await Future<void>.delayed(Duration.zero);
          streamController.add([ownReaction('❤️')]);
          await Future<void>.delayed(Duration.zero);
          cubit.add(
            const ConversationReactionSet(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '😂',
            ),
          );
          await Future<void>.delayed(Duration.zero);
        },
        verify: (cubit) {
          final emojis = cubit.state
              .reactionsFor(_msgId)
              .where((r) => r.isOwn)
              .map((r) => r.emoji)
              .toSet();
          expect(emojis, contains('😂'));
          expect(emojis, isNot(contains('❤️')));
        },
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'drops the optimistic add when the insert never persisted',
        build: () {
          when(
            () => repo.publish(
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              emoji: any(named: 'emoji'),
            ),
          ).thenAnswer(
            (_) async => const DmReactionPublishResult(
              success: false,
              rumorId: 'r-x',
              errorMessage: 'Optimistic insert failed',
            ),
          );
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) => cubit.add(
          const ConversationReactionToggled(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '🔥',
          ),
        ),
        verify: (cubit) {
          expect(cubit.state.optimistic, isEmpty);
          expect(cubit.state.reactionsFor(_msgId), isEmpty);
          expect(
            cubit.state.pending[const ReactionPublishKey(
              messageId: _msgId,
              emoji: '🔥',
            )],
            ReactionPublishLocalStatus.failed,
          );
        },
      );
    });
  });
}
