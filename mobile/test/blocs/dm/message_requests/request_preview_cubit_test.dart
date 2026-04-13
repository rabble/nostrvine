// ABOUTME: Unit tests for RequestPreviewCubit.
// ABOUTME: Verifies message count loading and participant pubkey resolution.

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

  group(RequestPreviewCubit, () {
    late _MockDmRepository mockDmRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);
    });

    RequestPreviewCubit buildCubit({
      List<String> initialParticipantPubkeys = const [],
    }) {
      return RequestPreviewCubit(
        dmRepository: mockDmRepository,
        conversationId: conversationId,
        initialParticipantPubkeys: initialParticipantPubkeys,
      );
    }

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
        },
        build: () => buildCubit(
          initialParticipantPubkeys: [otherPubkey],
        ),
        act: (cubit) => cubit.load(),
        expect: () => [
          const RequestPreviewState(
            status: RequestPreviewStatus.loaded,
            messageCount: 5,
            participantPubkeys: [otherPubkey],
          ),
        ],
        verify: (_) {
          verify(
            () => mockDmRepository.countMessagesInConversation(conversationId),
          ).called(1);
          verifyNever(() => mockDmRepository.getConversation(any()));
        },
      );

      blocTest<RequestPreviewCubit, RequestPreviewState>(
        'resolves pubkeys from DB when none provided',
        setUp: () {
          when(
            () => mockDmRepository.countMessagesInConversation(any()),
          ).thenAnswer((_) async => 3);
          when(
            () => mockDmRepository.getConversation(any()),
          ).thenAnswer(
            (_) async => DmConversation(
              id: conversationId,
              participantPubkeys: const [testPubkey, otherPubkey],
              isGroup: false,
              createdAt: 1700000000,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const RequestPreviewState(
            status: RequestPreviewStatus.loaded,
            messageCount: 3,
            participantPubkeys: [otherPubkey],
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
  });
}
