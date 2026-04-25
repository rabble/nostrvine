// ABOUTME: Tests for MessageRequestActionsCubit - decline, mark-all-read,
// ABOUTME: and remove-all actions for message requests.

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';

class _MockDmRepository extends Mock implements DmRepository {}

const _testConversationId1 =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _testConversationId2 =
    'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';

void main() {
  group(MessageRequestActionsCubit, () {
    late _MockDmRepository mockDmRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
    });

    MessageRequestActionsCubit createCubit() =>
        MessageRequestActionsCubit(dmRepository: mockDmRepository);

    test('initial state has idle status', () {
      final cubit = createCubit();

      expect(cubit.state.status, equals(MessageRequestActionsStatus.idle));

      cubit.close();
    });

    group('declineRequest', () {
      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'emits [processing, success] when removeConversation succeeds',
        setUp: () {
          when(
            () => mockDmRepository.removeConversation(_testConversationId1),
          ).thenAnswer((_) async {});
        },
        build: createCubit,
        act: (cubit) => cubit.declineRequest(_testConversationId1),
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockDmRepository.removeConversation(_testConversationId1),
          ).called(1);
        },
      );

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'emits [processing, error] when removeConversation throws',
        setUp: () {
          when(
            () => mockDmRepository.removeConversation(_testConversationId1),
          ).thenThrow(Exception('db failure'));
        },
        build: createCubit,
        act: (cubit) => cubit.declineRequest(_testConversationId1),
        errors: () => [isA<Exception>()],
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.error,
          ),
        ],
      );
    });

    group('markAllRequestsAsRead', () {
      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'emits [processing, success] when markConversationsAsRead succeeds',
        setUp: () {
          when(
            () => mockDmRepository.markConversationsAsRead(any()),
          ).thenAnswer((_) async {});
        },
        build: createCubit,
        act: (cubit) => cubit.markAllRequestsAsRead([
          _testConversationId1,
          _testConversationId2,
        ]),
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockDmRepository.markConversationsAsRead([
              _testConversationId1,
              _testConversationId2,
            ]),
          ).called(1);
        },
      );

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'does not emit when conversationIds is empty',
        build: createCubit,
        act: (cubit) => cubit.markAllRequestsAsRead([]),
        expect: () => const <MessageRequestActionsState>[],
      );

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'emits [processing, error] when markConversationsAsRead throws',
        setUp: () {
          when(
            () => mockDmRepository.markConversationsAsRead(any()),
          ).thenThrow(Exception('db failure'));
        },
        build: createCubit,
        act: (cubit) => cubit.markAllRequestsAsRead([_testConversationId1]),
        errors: () => [isA<Exception>()],
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.error,
          ),
        ],
      );
    });

    group('removeAllRequests', () {
      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'emits [processing, success] when removeConversations succeeds',
        setUp: () {
          when(
            () => mockDmRepository.removeConversations(any()),
          ).thenAnswer((_) async {});
        },
        build: createCubit,
        act: (cubit) => cubit.removeAllRequests([
          _testConversationId1,
          _testConversationId2,
        ]),
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockDmRepository.removeConversations([
              _testConversationId1,
              _testConversationId2,
            ]),
          ).called(1);
        },
      );

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'does not emit when conversationIds is empty',
        build: createCubit,
        act: (cubit) => cubit.removeAllRequests([]),
        expect: () => const <MessageRequestActionsState>[],
      );

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'emits [processing, error] when removeConversations throws',
        setUp: () {
          when(
            () => mockDmRepository.removeConversations(any()),
          ).thenThrow(Exception('db failure'));
        },
        build: createCubit,
        act: (cubit) => cubit.removeAllRequests([_testConversationId1]),
        errors: () => [isA<Exception>()],
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.error,
          ),
        ],
      );
    });

    group('$MessageRequestActionsState', () {
      test('supports value equality', () {
        const state1 = MessageRequestActionsState(
          status: MessageRequestActionsStatus.processing,
        );
        const state2 = MessageRequestActionsState(
          status: MessageRequestActionsStatus.processing,
        );

        expect(state1, equals(state2));
      });

      test('states with different status are not equal', () {
        const state1 = MessageRequestActionsState(
          status: MessageRequestActionsStatus.processing,
        );
        const state2 = MessageRequestActionsState(
          status: MessageRequestActionsStatus.success,
        );

        expect(state1, isNot(equals(state2)));
      });

      test('copyWith returns same object when no parameters provided', () {
        const state = MessageRequestActionsState(
          status: MessageRequestActionsStatus.processing,
        );
        final updated = state.copyWith();

        expect(updated.status, equals(MessageRequestActionsStatus.processing));
      });

      test('copyWith replaces status', () {
        const state = MessageRequestActionsState();
        final updated = state.copyWith(
          status: MessageRequestActionsStatus.processing,
        );

        expect(updated.status, equals(MessageRequestActionsStatus.processing));
      });

      test('props contains status', () {
        const state = MessageRequestActionsState(
          status: MessageRequestActionsStatus.success,
        );

        expect(state.props, [MessageRequestActionsStatus.success]);
      });
    });
  });
}
