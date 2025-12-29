// ABOUTME: Tests for CommentInputCubit - text input, reply mode, and posting
// ABOUTME: Tests UI state management for comment input fields

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comment_input_cubit.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';

class _MockCommentsBloc extends Mock implements CommentsBloc {}

void main() {
  setUpAll(() {
    // Register fallback value for sealed CommentsEvent class
    registerFallbackValue(const CommentsLoadRequested());
  });

  group('CommentInputCubit', () {
    late _MockCommentsBloc mockCommentsBloc;

    setUp(() {
      mockCommentsBloc = _MockCommentsBloc();
    });

    CommentInputCubit createCubit() =>
        CommentInputCubit(commentsBloc: mockCommentsBloc);

    test('initial state is CommentInputState.initial', () {
      final cubit = createCubit();
      expect(cubit.state, CommentInputState.initial);
      cubit.close();
    });

    group('updateMainText', () {
      blocTest<CommentInputCubit, CommentInputState>(
        'updates main input text',
        build: createCubit,
        act: (cubit) => cubit.updateMainText('Hello'),
        expect: () => [
          isA<CommentInputState>().having(
            (s) => s.mainInputText,
            'mainInputText',
            'Hello',
          ),
        ],
      );

      blocTest<CommentInputCubit, CommentInputState>(
        'clears error when updating text',
        seed: () => const CommentInputState(error: 'Some error'),
        build: createCubit,
        act: (cubit) => cubit.updateMainText('New text'),
        expect: () => [
          isA<CommentInputState>()
              .having((s) => s.mainInputText, 'mainInputText', 'New text')
              .having((s) => s.error, 'error', null),
        ],
      );
    });

    group('updateReplyText', () {
      blocTest<CommentInputCubit, CommentInputState>(
        'updates reply text for a specific comment',
        build: createCubit,
        act: (cubit) => cubit.updateReplyText('comment1', 'Reply text'),
        expect: () => [
          isA<CommentInputState>().having(
            (s) => s.getReplyText('comment1'),
            'reply text',
            'Reply text',
          ),
        ],
      );
    });

    group('toggleReply', () {
      blocTest<CommentInputCubit, CommentInputState>(
        'opens reply for a comment',
        build: createCubit,
        act: (cubit) => cubit.toggleReply('comment1'),
        expect: () => [
          isA<CommentInputState>().having(
            (s) => s.activeReplyCommentId,
            'activeReplyCommentId',
            'comment1',
          ),
        ],
      );

      blocTest<CommentInputCubit, CommentInputState>(
        'closes reply when toggling same comment',
        seed: () => const CommentInputState(activeReplyCommentId: 'comment1'),
        build: createCubit,
        act: (cubit) => cubit.toggleReply('comment1'),
        expect: () => [
          isA<CommentInputState>().having(
            (s) => s.activeReplyCommentId,
            'activeReplyCommentId',
            null,
          ),
        ],
      );

      blocTest<CommentInputCubit, CommentInputState>(
        'switches to different comment when toggling another',
        seed: () => const CommentInputState(activeReplyCommentId: 'comment1'),
        build: createCubit,
        act: (cubit) => cubit.toggleReply('comment2'),
        expect: () => [
          isA<CommentInputState>().having(
            (s) => s.activeReplyCommentId,
            'activeReplyCommentId',
            'comment2',
          ),
        ],
      );
    });

    group('postMainComment', () {
      blocTest<CommentInputCubit, CommentInputState>(
        'does nothing when text is empty',
        seed: () => const CommentInputState(mainInputText: ''),
        build: createCubit,
        act: (cubit) => cubit.postMainComment(),
        expect: () => <CommentInputState>[],
      );

      blocTest<CommentInputCubit, CommentInputState>(
        'does nothing when text is only whitespace',
        seed: () => const CommentInputState(mainInputText: '   '),
        build: createCubit,
        act: (cubit) => cubit.postMainComment(),
        expect: () => <CommentInputState>[],
      );

      blocTest<CommentInputCubit, CommentInputState>(
        'posts comment and clears text on success',
        seed: () => const CommentInputState(mainInputText: 'Test comment'),
        build: createCubit,
        act: (cubit) => cubit.postMainComment(),
        expect: () => [
          // First emit: isMainPosting = true
          isA<CommentInputState>()
              .having((s) => s.isMainPosting, 'isMainPosting', true)
              .having((s) => s.mainInputText, 'mainInputText', 'Test comment'),
          // Second emit: isMainPosting = false, text cleared
          isA<CommentInputState>()
              .having((s) => s.isMainPosting, 'isMainPosting', false)
              .having((s) => s.mainInputText, 'mainInputText', ''),
        ],
        verify: (_) {
          verify(() => mockCommentsBloc.add(any())).called(1);
        },
      );
    });

    group('postReply', () {
      blocTest<CommentInputCubit, CommentInputState>(
        'does nothing when reply text is empty',
        seed: () => const CommentInputState(replyInputTexts: {'comment1': ''}),
        build: createCubit,
        act: (cubit) => cubit.postReply('comment1', 'author1'),
        expect: () => <CommentInputState>[],
      );

      blocTest<CommentInputCubit, CommentInputState>(
        'posts reply and clears input on success',
        seed: () => const CommentInputState(
          replyInputTexts: {'comment1': 'Reply text'},
          activeReplyCommentId: 'comment1',
        ),
        build: createCubit,
        act: (cubit) => cubit.postReply('comment1', 'author1'),
        expect: () => [
          // First emit: posting
          isA<CommentInputState>().having(
            (s) => s.isReplyPosting('comment1'),
            'isReplyPosting',
            true,
          ),
          // Second emit: done, text cleared, reply closed
          isA<CommentInputState>()
              .having(
                (s) => s.isReplyPosting('comment1'),
                'isReplyPosting',
                false,
              )
              .having((s) => s.getReplyText('comment1'), 'replyText', '')
              .having(
                (s) => s.activeReplyCommentId,
                'activeReplyCommentId',
                null,
              ),
        ],
        verify: (_) {
          verify(() => mockCommentsBloc.add(any())).called(1);
        },
      );
    });

    group('clearError', () {
      blocTest<CommentInputCubit, CommentInputState>(
        'clears the error',
        seed: () => const CommentInputState(error: 'Some error'),
        build: createCubit,
        act: (cubit) => cubit.clearError(),
        expect: () => [
          isA<CommentInputState>().having((s) => s.error, 'error', null),
        ],
      );
    });

    group('reset', () {
      blocTest<CommentInputCubit, CommentInputState>(
        'resets to initial state',
        seed: () => const CommentInputState(
          mainInputText: 'Some text',
          activeReplyCommentId: 'comment1',
          isMainPosting: true,
        ),
        build: createCubit,
        act: (cubit) => cubit.reset(),
        expect: () => [CommentInputState.initial],
      );
    });
  });

  group('CommentInputState', () {
    test('supports value equality', () {
      const state1 = CommentInputState(mainInputText: 'Test');
      const state2 = CommentInputState(mainInputText: 'Test');

      expect(state1, equals(state2));
    });

    test('initial state has correct defaults', () {
      const state = CommentInputState.initial;

      expect(state.mainInputText, '');
      expect(state.replyInputTexts, isEmpty);
      expect(state.activeReplyCommentId, null);
      expect(state.isMainPosting, false);
      expect(state.postingReplyIds, isEmpty);
      expect(state.error, null);
    });

    test('isReplyPosting returns correct value', () {
      const state = CommentInputState(
        postingReplyIds: {'comment1', 'comment2'},
      );

      expect(state.isReplyPosting('comment1'), true);
      expect(state.isReplyPosting('comment2'), true);
      expect(state.isReplyPosting('comment3'), false);
    });

    test('isAnyPosting returns true when main posting', () {
      const state = CommentInputState(isMainPosting: true);
      expect(state.isAnyPosting, true);
    });

    test('isAnyPosting returns true when reply posting', () {
      const state = CommentInputState(postingReplyIds: {'comment1'});
      expect(state.isAnyPosting, true);
    });

    test('isAnyPosting returns false when nothing posting', () {
      const state = CommentInputState();
      expect(state.isAnyPosting, false);
    });

    test('getReplyText returns empty string for unknown comment', () {
      const state = CommentInputState();
      expect(state.getReplyText('unknown'), '');
    });

    test('getReplyText returns correct text for known comment', () {
      const state = CommentInputState(
        replyInputTexts: {'comment1': 'Reply text'},
      );
      expect(state.getReplyText('comment1'), 'Reply text');
    });

    test('copyWith updates values correctly', () {
      const state = CommentInputState(
        mainInputText: 'Original',
        activeReplyCommentId: 'comment1',
      );

      final updated = state.copyWith(
        mainInputText: 'Updated',
        clearActiveReply: true,
      );

      expect(updated.mainInputText, 'Updated');
      expect(updated.activeReplyCommentId, null);
    });

    test('copyWith clearError removes error', () {
      const state = CommentInputState(error: 'Some error');

      final updated = state.copyWith(clearError: true);

      expect(updated.error, null);
    });
  });
}
