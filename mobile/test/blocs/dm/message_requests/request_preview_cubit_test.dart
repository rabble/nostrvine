// ABOUTME: Unit tests for RequestPreviewCubit.
// ABOUTME: Verifies message count loading and participant pubkey resolution.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/message_requests/request_preview_cubit.dart';

class _MockDmRepository extends Mock implements DmRepository {}

void main() {
  const testPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const conversationId =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
  const inviteMessage = DmMessage(
    id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
    conversationId: conversationId,
    senderPubkey: otherPubkey,
    content: 'You were invited to collaborate.',
    createdAt: 1700000000,
    giftWrapId:
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    tags: [
      ['divine', 'collab-invite'],
      [
        'a',
        '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
        'wss://relay.divine.video',
      ],
      ['p', otherPubkey],
      ['role', 'Collaborator'],
      ['title', 'Skate loop'],
    ],
  );

  group(RequestPreviewCubit, () {
    late _MockDmRepository mockDmRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);
    });

    RequestPreviewCubit buildCubit({
      List<String> initialParticipantPubkeys = const [],
      bool isDmRestricted = false,
      bool Function(String)? isApprovedRecipient,
    }) {
      return RequestPreviewCubit(
        dmRepository: mockDmRepository,
        conversationId: conversationId,
        initialParticipantPubkeys: initialParticipantPubkeys,
        isDmRestricted: () => isDmRestricted,
        isApprovedRecipient: isApprovedRecipient ?? (_) => true,
      );
    }

    test('does not emit or throw when closed mid-load', () async {
      final completer = Completer<int>();
      when(
        () => mockDmRepository.countMessagesInConversation(any()),
      ).thenAnswer((_) => completer.future);
      when(
        () => mockDmRepository.getMessages(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => const []);

      final cubit = buildCubit(initialParticipantPubkeys: [otherPubkey]);
      final future = cubit.load();
      await cubit.close();
      completer.complete(5);
      await expectLater(future, completes);

      expect(cubit.state.status, RequestPreviewStatus.loading);
    });

    test('initial state is loading with empty data', () {
      final cubit = buildCubit();
      expect(cubit.state.status, equals(RequestPreviewStatus.loading));
      expect(cubit.state.messageCount, equals(0));
      expect(cubit.state.participantPubkeys, isEmpty);
    });

    test('exposes conversationId', () {
      final cubit = buildCubit();
      expect(cubit.conversationId, equals(conversationId));
    });

    group('load', () {
      blocTest<RequestPreviewCubit, RequestPreviewState>(
        'emits loaded with message count and provided pubkeys',
        setUp: () {
          when(
            () => mockDmRepository.countMessagesInConversation(any()),
          ).thenAnswer((_) async => 5);
          when(
            () =>
                mockDmRepository.getMessages(any(), limit: any(named: 'limit')),
          ).thenAnswer((_) async => [inviteMessage]);
        },
        build: () => buildCubit(initialParticipantPubkeys: [otherPubkey]),
        act: (cubit) => cubit.load(),
        expect: () => [
          const RequestPreviewState(
            status: RequestPreviewStatus.loaded,
            messageCount: 5,
            participantPubkeys: [otherPubkey],
            messages: [inviteMessage],
          ),
        ],
        verify: (_) {
          verify(
            () => mockDmRepository.countMessagesInConversation(conversationId),
          ).called(1);
          verifyNever(() => mockDmRepository.getConversation(any()));
          verify(
            () => mockDmRepository.getMessages(conversationId, limit: 10),
          ).called(1);
        },
      );

      blocTest<RequestPreviewCubit, RequestPreviewState>(
        'resolves pubkeys from DB when none provided',
        setUp: () {
          when(
            () => mockDmRepository.countMessagesInConversation(any()),
          ).thenAnswer((_) async => 3);
          when(() => mockDmRepository.getConversation(any())).thenAnswer(
            (_) async => DmConversation(
              id: conversationId,
              participantPubkeys: const [testPubkey, otherPubkey],
              isGroup: false,
              createdAt: 1700000000,
            ),
          );
          when(
            () =>
                mockDmRepository.getMessages(any(), limit: any(named: 'limit')),
          ).thenAnswer((_) async => [inviteMessage]);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const RequestPreviewState(
            status: RequestPreviewStatus.loaded,
            messageCount: 3,
            participantPubkeys: [otherPubkey],
            messages: [inviteMessage],
          ),
        ],
        verify: (_) {
          verify(
            () => mockDmRepository.getConversation(conversationId),
          ).called(1);
        },
      );

      blocTest<RequestPreviewCubit, RequestPreviewState>(
        'emits empty pubkeys when conversation not found in DB',
        setUp: () {
          when(
            () => mockDmRepository.countMessagesInConversation(any()),
          ).thenAnswer((_) async => 1);
          when(
            () => mockDmRepository.getConversation(any()),
          ).thenAnswer((_) async => null);
          when(
            () =>
                mockDmRepository.getMessages(any(), limit: any(named: 'limit')),
          ).thenAnswer((_) async => const []);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const RequestPreviewState(
            status: RequestPreviewStatus.loaded,
            messageCount: 1,
          ),
        ],
      );

      blocTest<RequestPreviewCubit, RequestPreviewState>(
        'emits error when loading fails',
        setUp: () {
          when(
            () => mockDmRepository.getConversation(any()),
          ).thenAnswer((_) async => null);
          when(
            () => mockDmRepository.countMessagesInConversation(any()),
          ).thenThrow(Exception('db error'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const RequestPreviewState(status: RequestPreviewStatus.error),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('protected-minor gate (#176)', () {
      blocTest<RequestPreviewCubit, RequestPreviewState>(
        'restricted + non-approved counterparty (provided pubkeys) is denied '
        'before any request data is read',
        build: () => buildCubit(
          initialParticipantPubkeys: [otherPubkey],
          isDmRestricted: true,
          isApprovedRecipient: (_) => false,
        ),
        act: (cubit) => cubit.load(),
        expect: () => [
          const RequestPreviewState(status: RequestPreviewStatus.denied),
        ],
        verify: (_) {
          // The whole point of the gate: no hidden request metadata is read
          // for a conversation the current user may not access.
          verifyNever(() => mockDmRepository.getConversation(any()));
          verifyNever(
            () => mockDmRepository.countMessagesInConversation(any()),
          );
          verifyNever(
            () =>
                mockDmRepository.getMessages(any(), limit: any(named: 'limit')),
          );
        },
      );

      blocTest<RequestPreviewCubit, RequestPreviewState>(
        'restricted + no route extras (direct or stale URL) fails closed '
        'without any repository read, even with all counterparties approved',
        // Approval cannot rescue this path: knowing the counterparty would
        // itself require reading the conversation. No repository stubs on
        // purpose — any read here is a regression and fails the test
        // (mocktail missing-stub + verifyNever).
        build: () => buildCubit(
          isDmRestricted: true,
          isApprovedRecipient: (_) => true,
        ),
        act: (cubit) => cubit.load(),
        expect: () => [
          const RequestPreviewState(status: RequestPreviewStatus.denied),
        ],
        verify: (_) {
          verifyNever(() => mockDmRepository.getConversation(any()));
          verifyNever(
            () => mockDmRepository.countMessagesInConversation(any()),
          );
          verifyNever(
            () =>
                mockDmRepository.getMessages(any(), limit: any(named: 'limit')),
          );
        },
      );

      blocTest<RequestPreviewCubit, RequestPreviewState>(
        'restricted + all counterparties approved loads normally',
        setUp: () {
          when(
            () => mockDmRepository.countMessagesInConversation(any()),
          ).thenAnswer((_) async => 2);
          when(
            () =>
                mockDmRepository.getMessages(any(), limit: any(named: 'limit')),
          ).thenAnswer((_) async => [inviteMessage]);
        },
        build: () => buildCubit(
          initialParticipantPubkeys: [otherPubkey],
          isDmRestricted: true,
          isApprovedRecipient: (p) => p == otherPubkey,
        ),
        act: (cubit) => cubit.load(),
        expect: () => [
          const RequestPreviewState(
            status: RequestPreviewStatus.loaded,
            messageCount: 2,
            participantPubkeys: [otherPubkey],
            messages: [inviteMessage],
          ),
        ],
      );
    });
  });
}
