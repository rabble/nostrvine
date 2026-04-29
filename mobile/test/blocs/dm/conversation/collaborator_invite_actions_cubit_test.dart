// ABOUTME: Tests collaborator invite accept/ignore UI action state.
// ABOUTME: Verifies accept publishes while ignore stays local-only.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/services/collaborator_response_service.dart';

class _MockCollaboratorInviteStateStore extends Mock
    implements CollaboratorInviteStateStore {}

class _MockCollaboratorResponseService extends Mock
    implements CollaboratorResponseService {}

void main() {
  const currentUserPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const creatorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const invite = CollaboratorInvite(
    messageId:
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    videoAddress:
        '34236:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:skate-loop',
    videoKind: 34236,
    creatorPubkey: creatorPubkey,
    videoDTag: 'skate-loop',
    role: 'Collaborator',
    title: 'Skate loop',
  );

  late _MockCollaboratorInviteStateStore store;
  late _MockCollaboratorResponseService responseService;

  setUpAll(() {
    registerFallbackValue(invite);
    registerFallbackValue(CollaboratorInviteState.pending);
  });

  setUp(() {
    store = _MockCollaboratorInviteStateStore();
    responseService = _MockCollaboratorResponseService();
  });

  CollaboratorInviteActionsCubit buildCubit() {
    return CollaboratorInviteActionsCubit(
      stateStore: store,
      responseService: responseService,
      currentUserPubkey: currentUserPubkey,
    );
  }

  group(CollaboratorInviteActionsCubit, () {
    test('loads persisted invite state', () {
      when(
        () => store.getState(
          videoAddress: invite.videoAddress,
          creatorPubkey: invite.creatorPubkey,
          collaboratorPubkey: currentUserPubkey,
        ),
      ).thenReturn(CollaboratorInviteState.accepted);

      final cubit = buildCubit()..loadInvites([invite]);

      expect(cubit.state.stateFor(invite), CollaboratorInviteState.accepted);
    });

    blocTest<CollaboratorInviteActionsCubit, CollaboratorInviteActionsState>(
      'acceptInvite persists accepting, publishes, then persists accepted',
      setUp: () {
        when(
          () => store.setState(
            videoAddress: invite.videoAddress,
            creatorPubkey: invite.creatorPubkey,
            collaboratorPubkey: currentUserPubkey,
            state: any(named: 'state'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => responseService.acceptInvite(invite),
        ).thenAnswer(
          (_) async => const CollaboratorResponseResult.success(
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.acceptInvite(invite),
      expect: () => [
        isA<CollaboratorInviteActionsState>().having(
          (state) => state.stateFor(invite),
          'invite state',
          CollaboratorInviteState.accepting,
        ),
        isA<CollaboratorInviteActionsState>().having(
          (state) => state.stateFor(invite),
          'invite state',
          CollaboratorInviteState.accepted,
        ),
      ],
      verify: (_) {
        verifyInOrder([
          () => store.setState(
            videoAddress: invite.videoAddress,
            creatorPubkey: invite.creatorPubkey,
            collaboratorPubkey: currentUserPubkey,
            state: CollaboratorInviteState.accepting,
          ),
          () => responseService.acceptInvite(invite),
          () => store.setState(
            videoAddress: invite.videoAddress,
            creatorPubkey: invite.creatorPubkey,
            collaboratorPubkey: currentUserPubkey,
            state: CollaboratorInviteState.accepted,
          ),
        ]);
      },
    );

    blocTest<CollaboratorInviteActionsCubit, CollaboratorInviteActionsState>(
      'acceptInvite persists failed when publishing fails',
      setUp: () {
        when(
          () => store.setState(
            videoAddress: any(named: 'videoAddress'),
            creatorPubkey: any(named: 'creatorPubkey'),
            collaboratorPubkey: any(named: 'collaboratorPubkey'),
            state: any(named: 'state'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => responseService.acceptInvite(invite),
        ).thenAnswer(
          (_) async => const CollaboratorResponseResult.failure('relay down'),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.acceptInvite(invite),
      expect: () => [
        isA<CollaboratorInviteActionsState>().having(
          (state) => state.stateFor(invite),
          'invite state',
          CollaboratorInviteState.accepting,
        ),
        isA<CollaboratorInviteActionsState>().having(
          (state) => state.stateFor(invite),
          'invite state',
          CollaboratorInviteState.failed,
        ),
      ],
    );

    blocTest<CollaboratorInviteActionsCubit, CollaboratorInviteActionsState>(
      'ignoreInvite persists ignored without publishing',
      setUp: () {
        when(
          () => store.setState(
            videoAddress: invite.videoAddress,
            creatorPubkey: invite.creatorPubkey,
            collaboratorPubkey: currentUserPubkey,
            state: CollaboratorInviteState.ignored,
          ),
        ).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) => cubit.ignoreInvite(invite),
      expect: () => [
        isA<CollaboratorInviteActionsState>().having(
          (state) => state.stateFor(invite),
          'invite state',
          CollaboratorInviteState.ignored,
        ),
      ],
      verify: (_) {
        verifyNever(() => responseService.acceptInvite(any()));
      },
    );

    // #3559 — defense-in-depth. The render layer should not surface
    // accept/ignore for sender-side (self-creator) invites; if it ever
    // does, the cubit's assert fails loudly in debug and the runtime
    // guard suppresses any side effect in release.
    test(
      'acceptInvite no-ops when current user is the invite creator',
      () async {
        final selfCreatorCubit = CollaboratorInviteActionsCubit(
          stateStore: store,
          responseService: responseService,
          currentUserPubkey: creatorPubkey,
        );
        addTearDown(selfCreatorCubit.close);

        await expectLater(
          selfCreatorCubit.acceptInvite(invite),
          throwsA(isA<AssertionError>()),
        );

        verifyNever(() => responseService.acceptInvite(any()));
        verifyNever(
          () => store.setState(
            videoAddress: any(named: 'videoAddress'),
            creatorPubkey: any(named: 'creatorPubkey'),
            collaboratorPubkey: any(named: 'collaboratorPubkey'),
            state: any(named: 'state'),
          ),
        );
      },
    );

    test(
      'ignoreInvite no-ops when current user is the invite creator',
      () async {
        final selfCreatorCubit = CollaboratorInviteActionsCubit(
          stateStore: store,
          responseService: responseService,
          currentUserPubkey: creatorPubkey,
        );
        addTearDown(selfCreatorCubit.close);

        await expectLater(
          selfCreatorCubit.ignoreInvite(invite),
          throwsA(isA<AssertionError>()),
        );

        verifyNever(
          () => store.setState(
            videoAddress: any(named: 'videoAddress'),
            creatorPubkey: any(named: 'creatorPubkey'),
            collaboratorPubkey: any(named: 'collaboratorPubkey'),
            state: any(named: 'state'),
          ),
        );
      },
    );
  });
}
