// ABOUTME: Cubit tests for InlineReelReplyCubit (in-player reel text replies).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/inline_reel_reply/inline_reel_reply_cubit.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';

class _MockDmRepository extends Mock implements DmRepository {}

const _peer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _peer2 =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _convo = 'convo-id';
const _reelId =
    'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';
const _videoAuthor =
    '4444444444444444444444444444444444444444444444444444444444444444';
const _regularEventId =
    '5555555555555555555555555555555555555555555555555555555555555555';
const _relayHint = 'wss://relay.example.com';

/// Addressable (kind 34236) reel ref — coordinate `<kind>:<author>:<d>`.
const _addressableVideoRef = DmSharedVideoRef(
  coordinateOrId: '34236:$_videoAuthor:my-reel',
  videoKind: DmSharedVideoKind.addressableShortVideo,
  authorPubkey: _videoAuthor,
  relayHint: _relayHint,
);

/// Regular (kind 22) reel ref — `coordinateOrId` is the 64-hex event id.
const _regularVideoRef = DmSharedVideoRef(
  coordinateOrId: _regularEventId,
  videoKind: DmSharedVideoKind.shortVideo,
  authorPubkey: _videoAuthor,
  relayHint: _relayHint,
);

DmReplyContext oneToOne({bool isOwn = false}) => DmReplyContext(
  conversationId: _convo,
  participantPubkeys: const [_peer],
  isGroup: false,
  sharedReelMessageId: _reelId,
  messageAuthorPubkey: _peer,
  hintName: 'Alice',
  isOwnMessage: isOwn,
);

DmReplyContext oneToOneWithVideo({DmSharedVideoRef? ref}) => DmReplyContext(
  conversationId: _convo,
  participantPubkeys: const [_peer],
  isGroup: false,
  sharedReelMessageId: _reelId,
  messageAuthorPubkey: _peer,
  hintName: 'Alice',
  isOwnMessage: false,
  sharedVideoRef: ref ?? _addressableVideoRef,
);

DmReplyContext groupCtx() => const DmReplyContext(
  conversationId: _convo,
  participantPubkeys: [_peer, _peer2],
  isGroup: true,
  sharedReelMessageId: _reelId,
  messageAuthorPubkey: _peer,
  hintName: 'The Group',
  isOwnMessage: false,
);

DmReplyContext groupCtxWithVideo({DmSharedVideoRef? ref}) => DmReplyContext(
  conversationId: _convo,
  participantPubkeys: const [_peer, _peer2],
  isGroup: true,
  sharedReelMessageId: _reelId,
  messageAuthorPubkey: _peer,
  hintName: 'The Group',
  isOwnMessage: false,
  sharedVideoRef: ref ?? _addressableVideoRef,
);

void main() {
  group(InlineReelReplyCubit, () {
    late _MockDmRepository repo;

    setUp(() => repo = _MockDmRepository());

    test('does not emit or throw when closed mid-send', () async {
      final completer = Completer<NIP17SendResult>();
      when(
        () => repo.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = InlineReelReplyCubit(
        dmRepository: repo,
        replyContext: oneToOne(),
      );
      final future = cubit.submit('hi');
      // sending emitted synchronously; close before the send resolves.
      await cubit.close();
      completer.complete(
        NIP17SendResult.success(
          rumorEventId: 'r',
          messageEventId: 'g',
          recipientPubkey: _peer,
        ),
      );
      await expectLater(future, completes);

      expect(cubit.state.status, InlineReelReplyStatus.sending);
    });

    void stubSendSuccess() {
      when(
        () => repo.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'r',
          messageEventId: 'g',
          recipientPubkey: _peer,
        ),
      );
    }

    void stubSendSharedVideoSuccess() {
      when(
        () => repo.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'r',
          messageEventId: 'g',
          recipientPubkey: _peer,
        ),
      );
    }

    void stubSendSharedVideoGroupSuccess() {
      when(
        () => repo.sendSharedVideoGroup(
          recipientPubkeys: any(named: 'recipientPubkeys'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenAnswer(
        (_) async => [
          NIP17SendResult.success(
            rumorEventId: 'r',
            messageEventId: 'g',
            recipientPubkey: _peer,
          ),
        ],
      );
    }

    blocTest<InlineReelReplyCubit, InlineReelReplyState>(
      'empty content is a no-op',
      build: () =>
          InlineReelReplyCubit(dmRepository: repo, replyContext: oneToOne()),
      act: (cubit) => cubit.submit('   '),
      expect: () => const <InlineReelReplyState>[],
      verify: (_) {
        verifyNever(
          () => repo.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        );
      },
    );

    blocTest<InlineReelReplyCubit, InlineReelReplyState>(
      '1:1 reply threads under the reel and succeeds',
      build: () {
        stubSendSuccess();
        return InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: oneToOne(),
        );
      },
      act: (cubit) => cubit.submit('lol same'),
      expect: () => const [
        InlineReelReplyState(status: InlineReelReplyStatus.sending),
        InlineReelReplyState(status: InlineReelReplyStatus.success),
      ],
      verify: (_) {
        verify(
          () => repo.sendMessage(
            recipientPubkey: _peer,
            content: 'lol same',
            replyToId: _reelId,
          ),
        ).called(1);
      },
    );

    blocTest<InlineReelReplyCubit, InlineReelReplyState>(
      'group reply uses sendGroupMessage with the reel as reply parent',
      build: () {
        when(
          () => repo.sendGroupMessage(
            recipientPubkeys: any(named: 'recipientPubkeys'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        ).thenAnswer(
          (_) async => [
            NIP17SendResult.success(
              rumorEventId: 'r',
              messageEventId: 'g',
              recipientPubkey: _peer,
            ),
          ],
        );
        return InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: groupCtx(),
        );
      },
      act: (cubit) => cubit.submit('hi all'),
      expect: () => const [
        InlineReelReplyState(status: InlineReelReplyStatus.sending),
        InlineReelReplyState(status: InlineReelReplyStatus.success),
      ],
      verify: (_) {
        verify(
          () => repo.sendGroupMessage(
            recipientPubkeys: const [_peer, _peer2],
            content: 'hi all',
            replyToId: _reelId,
          ),
        ).called(1);
      },
    );

    blocTest<InlineReelReplyCubit, InlineReelReplyState>(
      'send returning failure result yields failure status',
      build: () {
        when(
          () => repo.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('relay down'));
        return InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: oneToOne(),
        );
      },
      act: (cubit) => cubit.submit('hi'),
      expect: () => const [
        InlineReelReplyState(status: InlineReelReplyStatus.sending),
        InlineReelReplyState(status: InlineReelReplyStatus.failure),
      ],
    );

    blocTest<InlineReelReplyCubit, InlineReelReplyState>(
      'StateError from send is Reportable',
      build: () {
        when(
          () => repo.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        ).thenThrow(StateError('not initialized'));
        return InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: oneToOne(),
        );
      },
      act: (cubit) => cubit.submit('hi'),
      expect: () => const [
        InlineReelReplyState(status: InlineReelReplyStatus.sending),
        InlineReelReplyState(status: InlineReelReplyStatus.failure),
      ],
      errors: () => [
        isA<Reportable<Object>>().having(
          (r) => r.unwrap(),
          'unwrap',
          isA<StateError>(),
        ),
      ],
    );

    blocTest<InlineReelReplyCubit, InlineReelReplyState>(
      'second submit while sending is dropped',
      build: () {
        when(
          () => repo.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return NIP17SendResult.success(
            rumorEventId: 'r',
            messageEventId: 'g',
            recipientPubkey: _peer,
          );
        });
        return InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: oneToOne(),
        );
      },
      act: (cubit) {
        cubit
          ..submit('one')
          ..submit('two');
      },
      verify: (_) {
        verify(
          () => repo.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        ).called(1);
      },
    );

    blocTest<InlineReelReplyCubit, InlineReelReplyState>(
      'acknowledge resets to initial',
      build: () {
        stubSendSuccess();
        return InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: oneToOne(),
        );
      },
      act: (cubit) async {
        await cubit.submit('hi');
        cubit.acknowledge();
      },
      skip: 2,
      expect: () => const [
        InlineReelReplyState(),
      ],
    );

    blocTest<InlineReelReplyCubit, InlineReelReplyState>(
      '1:1 with addressable video ref cites the video via sendSharedVideo',
      build: () {
        stubSendSharedVideoSuccess();
        return InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: oneToOneWithVideo(),
        );
      },
      act: (cubit) => cubit.submit('hi'),
      expect: () => const [
        InlineReelReplyState(status: InlineReelReplyStatus.sending),
        InlineReelReplyState(status: InlineReelReplyStatus.success),
      ],
      verify: (_) {
        verify(
          () => repo.sendSharedVideo(
            recipientPubkey: _peer,
            baseContent: 'hi',
            videoKind: 34236,
            videoAuthorPubkey: _videoAuthor,
            videoDTag: 'my-reel',
            videoEventId: any(named: 'videoEventId', that: isNull),
            relayHint: _relayHint,
            replyToId: _reelId,
          ),
        ).called(1);
        verifyNever(
          () => repo.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        );
      },
    );

    blocTest<InlineReelReplyCubit, InlineReelReplyState>(
      'group with addressable video ref cites via sendSharedVideoGroup',
      build: () {
        stubSendSharedVideoGroupSuccess();
        return InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: groupCtxWithVideo(),
        );
      },
      act: (cubit) => cubit.submit('hi'),
      expect: () => const [
        InlineReelReplyState(status: InlineReelReplyStatus.sending),
        InlineReelReplyState(status: InlineReelReplyStatus.success),
      ],
      verify: (_) {
        verify(
          () => repo.sendSharedVideoGroup(
            recipientPubkeys: const [_peer, _peer2],
            baseContent: 'hi',
            videoKind: 34236,
            videoAuthorPubkey: _videoAuthor,
            videoDTag: 'my-reel',
            videoEventId: any(named: 'videoEventId', that: isNull),
            relayHint: _relayHint,
            replyToId: _reelId,
          ),
        ).called(1);
        verifyNever(
          () => repo.sendGroupMessage(
            recipientPubkeys: any(named: 'recipientPubkeys'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        );
      },
    );

    blocTest<InlineReelReplyCubit, InlineReelReplyState>(
      'regular-kind video ref passes videoEventId and null videoDTag',
      build: () {
        stubSendSharedVideoSuccess();
        return InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: oneToOneWithVideo(ref: _regularVideoRef),
        );
      },
      act: (cubit) => cubit.submit('hi'),
      expect: () => const [
        InlineReelReplyState(status: InlineReelReplyStatus.sending),
        InlineReelReplyState(status: InlineReelReplyStatus.success),
      ],
      verify: (_) {
        verify(
          () => repo.sendSharedVideo(
            recipientPubkey: _peer,
            baseContent: 'hi',
            videoKind: 22,
            videoAuthorPubkey: _videoAuthor,
            videoDTag: any(named: 'videoDTag', that: isNull),
            videoEventId: _regularEventId,
            relayHint: _relayHint,
            replyToId: _reelId,
          ),
        ).called(1);
      },
    );

    blocTest<InlineReelReplyCubit, InlineReelReplyState>(
      '1:1 without a video ref still uses plain sendMessage',
      build: () {
        stubSendSuccess();
        return InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: oneToOne(),
        );
      },
      act: (cubit) => cubit.submit('hi'),
      verify: (_) {
        verify(
          () => repo.sendMessage(
            recipientPubkey: _peer,
            content: 'hi',
            replyToId: _reelId,
          ),
        ).called(1);
        verifyNever(
          () => repo.sendSharedVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            baseContent: any(named: 'baseContent'),
            videoKind: any(named: 'videoKind'),
            videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
            videoDTag: any(named: 'videoDTag'),
            videoEventId: any(named: 'videoEventId'),
            relayHint: any(named: 'relayHint'),
            replyToId: any(named: 'replyToId'),
          ),
        );
      },
    );

    blocTest<InlineReelReplyCubit, InlineReelReplyState>(
      'group without a video ref still uses plain sendGroupMessage',
      build: () {
        when(
          () => repo.sendGroupMessage(
            recipientPubkeys: any(named: 'recipientPubkeys'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        ).thenAnswer(
          (_) async => [
            NIP17SendResult.success(
              rumorEventId: 'r',
              messageEventId: 'g',
              recipientPubkey: _peer,
            ),
          ],
        );
        return InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: groupCtx(),
        );
      },
      act: (cubit) => cubit.submit('hi'),
      verify: (_) {
        verify(
          () => repo.sendGroupMessage(
            recipientPubkeys: const [_peer, _peer2],
            content: 'hi',
            replyToId: _reelId,
          ),
        ).called(1);
        verifyNever(
          () => repo.sendSharedVideoGroup(
            recipientPubkeys: any(named: 'recipientPubkeys'),
            baseContent: any(named: 'baseContent'),
            videoKind: any(named: 'videoKind'),
            videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
            videoDTag: any(named: 'videoDTag'),
            videoEventId: any(named: 'videoEventId'),
            relayHint: any(named: 'relayHint'),
            replyToId: any(named: 'replyToId'),
          ),
        );
      },
    );

    // #7316. A NIP-17 message is identified by its kind-14 rumor id, and that
    // id hashes the rumor's `created_at` — so a second `sendMessage` for the
    // same text is a different event the receiver cannot collapse, delivered
    // alongside the sweep's replay of the original row. Retry must re-drive
    // that row instead of sending again.
    group('retry', () {
      /// Stubs a 1:1 send that parks [queuedRumorId]. `null` models a send
      /// that left no row — a policy block, or an unwired queue DAO.
      void stubSendParks(String? queuedRumorId) {
        when(
          () => repo.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.failure(
            'no relay responded',
            retryablePending: true,
            queuedRumorId: queuedRumorId,
          ),
        );
      }

      void verifySendMessageCalled(int times) {
        verify(
          () => repo.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        ).called(times);
      }

      test('re-drives the parked row and never mints a second rumor', () async {
        stubSendParks('row-1');
        when(
          () => repo.recoverFullSend(
            rumorId: any(named: 'rumorId'),
            resetRetryBudget: any(named: 'resetRetryBudget'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: 'row-1',
            messageEventId: 'g',
            recipientPubkey: _peer,
          ),
        );

        final cubit = InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: oneToOne(),
        );
        addTearDown(cubit.close);

        await cubit.submit('hi');
        expect(cubit.state.status, InlineReelReplyStatus.failure);
        expect(cubit.state.queuedRumorIds, ['row-1']);

        await cubit.retry('hi');

        expect(cubit.state.status, InlineReelReplyStatus.success);
        expect(cubit.state.queuedRumorIds, isEmpty);
        verify(
          () => repo.recoverFullSend(rumorId: 'row-1', resetRetryBudget: true),
        ).called(1);
        // The anti-duplication contract: the original send, and only it.
        verifySendMessageCalled(1);
      });

      test('falls back to a fresh send when nothing was parked', () async {
        // A policy-blocked send returns before the enqueue, so there is no row
        // to re-drive and no second copy a fresh send could duplicate.
        stubSendParks(null);

        final cubit = InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: oneToOne(),
        );
        addTearDown(cubit.close);

        await cubit.submit('hi');
        expect(cubit.state.queuedRumorIds, isEmpty);

        await cubit.retry('hi');

        verifySendMessageCalled(2);
        verifyNever(
          () => repo.recoverFullSend(
            rumorId: any(named: 'rumorId'),
            resetRetryBudget: any(named: 'resetRetryBudget'),
          ),
        );
      });

      test('drops a row that is already gone without re-sending', () async {
        stubSendParks('row-1');
        when(
          () => repo.recoverFullSend(
            rumorId: any(named: 'rumorId'),
            resetRetryBudget: any(named: 'resetRetryBudget'),
          ),
        ).thenThrow(ArgumentError.value('row-1', 'rumorId', 'no queued row'));

        final cubit = InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: oneToOne(),
        );
        addTearDown(cubit.close);

        await cubit.submit('hi');
        await cubit.retry('hi');

        // The sweep may already have delivered it; we cannot prove otherwise,
        // so a replacement rumor is never minted.
        verifySendMessageCalled(1);
        expect(cubit.state.status, InlineReelReplyStatus.success);
        expect(cubit.state.queuedRumorIds, isEmpty);
      });

      test('re-drives every parked sibling of a group send', () async {
        when(
          () => repo.sendGroupMessage(
            recipientPubkeys: any(named: 'recipientPubkeys'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        ).thenAnswer(
          (_) async => const [
            NIP17SendResult.failure('nope', queuedRumorId: 'row-a'),
            NIP17SendResult.failure('nope', queuedRumorId: 'row-b'),
          ],
        );
        when(
          () => repo.recoverFullSend(
            rumorId: any(named: 'rumorId'),
            resetRetryBudget: any(named: 'resetRetryBudget'),
          ),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#rumorId] == 'row-a'
              ? NIP17SendResult.success(
                  rumorEventId: 'row-a',
                  messageEventId: 'g',
                  recipientPubkey: _peer,
                )
              : const NIP17SendResult.failure('still down'),
        );

        final cubit = InlineReelReplyCubit(
          dmRepository: repo,
          replyContext: groupCtx(),
        );
        addTearDown(cubit.close);

        await cubit.submit('hi');
        expect(cubit.state.queuedRumorIds, ['row-a', 'row-b']);

        await cubit.retry('hi');

        verify(
          () => repo.recoverFullSend(rumorId: 'row-a', resetRetryBudget: true),
        ).called(1);
        verify(
          () => repo.recoverFullSend(rumorId: 'row-b', resetRetryBudget: true),
        ).called(1);
        // A further retry targets exactly the sibling still outstanding.
        expect(cubit.state.queuedRumorIds, ['row-b']);
        // The original fan-out and only it — retry adds no second one.
        verify(
          () => repo.sendGroupMessage(
            recipientPubkeys: any(named: 'recipientPubkeys'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        ).called(1);
      });
    });
  });
}
