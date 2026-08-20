// ABOUTME: Tests for MessageRequestActionsCubit - decline, mark-all-read,
// ABOUTME: and remove-all actions for message requests.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

const _testConversationId1 =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _testConversationId2 =
    'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
const _testSenderPubkey =
    'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';
const _testOwnerPubkey =
    'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5';

void main() {
  group(MessageRequestActionsCubit, () {
    late _MockDmRepository mockDmRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      when(() => mockDmRepository.userPubkey).thenReturn(_testOwnerPubkey);
    });

    MessageRequestActionsCubit createCubit() => MessageRequestActionsCubit(
      dmRepository: mockDmRepository,
      blocklistRepository: mockBlocklistRepository,
    );

    test('returns true but does not emit when closed mid-decline', () async {
      final completer = Completer<void>();
      when(
        () => mockDmRepository.removeConversation(_testConversationId1),
      ).thenAnswer((_) => completer.future);

      final cubit = createCubit();
      final future = cubit.declineRequest(_testConversationId1);
      // processing emitted synchronously; close before the delete resolves.
      await cubit.close();
      completer.complete();

      // The removal completed, so the caller sees `true` even though the
      // guarded `success` emit was skipped. A state read would still show
      // `processing` and wrongly report failure (#7881 review, finding 5).
      expect(await future, isTrue);
      expect(cubit.state.status, MessageRequestActionsStatus.processing);
    });

    test('returns true but does not emit when closed mid-block', () async {
      final completer = Completer<void>();
      when(
        () => mockBlocklistRepository.blockUser(
          _testSenderPubkey,
          ourPubkey: _testOwnerPubkey,
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.removeConversation(_testConversationId1),
      ).thenAnswer((_) => completer.future);

      final cubit = createCubit();
      final future = cubit.blockAndRemoveRequest(
        _testConversationId1,
        _testSenderPubkey,
      );
      await cubit.close();
      completer.complete();

      expect(await future, isTrue);
      expect(cubit.state.status, MessageRequestActionsStatus.processing);
    });

    test('initial state has idle status', () {
      final cubit = createCubit();

      expect(cubit.state.status, equals(MessageRequestActionsStatus.idle));

      cubit.close();
    });

    group('declineRequest', () {
      test('returns true when removeConversation succeeds', () async {
        when(
          () => mockDmRepository.removeConversation(_testConversationId1),
        ).thenAnswer((_) async {});

        final cubit = createCubit();
        expect(await cubit.declineRequest(_testConversationId1), isTrue);

        await cubit.close();
      });

      test('returns false when removeConversation throws', () async {
        when(
          () => mockDmRepository.removeConversation(_testConversationId1),
        ).thenThrow(Exception('db failure'));

        final cubit = createCubit();
        // The false return is what drives the caller's error snackbar; the
        // widget tests stub the mock, so this is the only coverage of the
        // real catch-returns-false contract (#7881 review, finding 5).
        expect(await cubit.declineRequest(_testConversationId1), isFalse);

        await cubit.close();
      });

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

    group('blockAndRemoveRequest', () {
      test('returns true when the block and removal succeed', () async {
        when(
          () => mockBlocklistRepository.blockUser(
            _testSenderPubkey,
            ourPubkey: _testOwnerPubkey,
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockDmRepository.removeConversation(_testConversationId1),
        ).thenAnswer((_) async {});

        final cubit = createCubit();
        expect(
          await cubit.blockAndRemoveRequest(
            _testConversationId1,
            _testSenderPubkey,
          ),
          isTrue,
        );

        await cubit.close();
      });

      test('returns false when the block fails', () async {
        when(
          () => mockBlocklistRepository.blockUser(
            _testSenderPubkey,
            ourPubkey: _testOwnerPubkey,
          ),
        ).thenThrow(Exception('publish failure'));

        final cubit = createCubit();
        expect(
          await cubit.blockAndRemoveRequest(
            _testConversationId1,
            _testSenderPubkey,
          ),
          isFalse,
        );

        await cubit.close();
      });

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'blocks the sender then removes the conversation, in that order',
        setUp: () {
          when(
            () => mockBlocklistRepository.blockUser(
              _testSenderPubkey,
              ourPubkey: _testOwnerPubkey,
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.removeConversation(_testConversationId1),
          ).thenAnswer((_) async {});
        },
        build: createCubit,
        act: (cubit) => cubit.blockAndRemoveRequest(
          _testConversationId1,
          _testSenderPubkey,
        ),
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.success,
          ),
        ],
        verify: (_) {
          verifyInOrder([
            () => mockBlocklistRepository.blockUser(
              _testSenderPubkey,
              ourPubkey: _testOwnerPubkey,
            ),
            () => mockDmRepository.removeConversation(_testConversationId1),
          ]);
        },
      );

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'does not remove the conversation when the block fails',
        setUp: () {
          when(
            () => mockBlocklistRepository.blockUser(
              _testSenderPubkey,
              ourPubkey: _testOwnerPubkey,
            ),
          ).thenThrow(Exception('publish failure'));
        },
        build: createCubit,
        act: (cubit) => cubit.blockAndRemoveRequest(
          _testConversationId1,
          _testSenderPubkey,
        ),
        errors: () => [isA<Exception>()],
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.error,
          ),
        ],
        verify: (_) {
          verifyNever(() => mockDmRepository.removeConversation(any()));
        },
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
