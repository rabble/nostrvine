// ABOUTME: Cubit tests for InlineReelReplyCubit (in-player reel text replies).

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
  });
}
