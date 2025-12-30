// ABOUTME: Tests for CommentsBloc - loading comments, posting, and tree building
// ABOUTME: Tests comment stream handling and error cases

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/services/auth_service.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('CommentsBloc', () {
    late _MockCommentsRepository mockCommentsRepository;
    late _MockAuthService mockAuthService;

    // Helper to create valid hex IDs (64 hex characters)
    String validId(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockCommentsRepository = _MockCommentsRepository();
      mockAuthService = _MockAuthService();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(validId('currentuser'));
    });

    // Video kind 34236 for NIP-71 addressable short videos
    const testRootEventKind = 34236;

    CommentsBloc createBloc({String? rootEventId, String? rootAuthorPubkey}) =>
        CommentsBloc(
          commentsRepository: mockCommentsRepository,
          authService: mockAuthService,
          rootEventId: rootEventId ?? validId('root'),
          rootEventKind: testRootEventKind,
          rootAuthorPubkey: rootAuthorPubkey ?? validId('author'),
        );

    test('initial state has correct rootEventId and rootAuthorPubkey', () {
      final bloc = createBloc(
        rootEventId: validId('testevent'),
        rootAuthorPubkey: validId('testauthor'),
      );

      expect(bloc.state.rootEventId, validId('testevent'));
      expect(bloc.state.rootAuthorPubkey, validId('testauthor'));
      expect(bloc.state.status, CommentsStatus.initial);

      bloc.close();
    });

    group('CommentsLoadRequested', () {
      blocTest<CommentsBloc, CommentsState>(
        'emits [loading, success] when comments load successfully',
        setUp: () {
          final comment = Comment(
            id: validId('comment1'),
            content: 'Test comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.now(),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          final thread = CommentThread(
            rootEventId: validId('root'),
            topLevelComments: [CommentNode(comment: comment)],
            totalCount: 1,
            commentCache: {comment.id: comment},
          );
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => thread);
        },
        build: () => createBloc(),
        act: (bloc) => bloc.add(const CommentsLoadRequested()),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.status,
            'status',
            CommentsStatus.loading,
          ),
          isA<CommentsState>()
              .having((s) => s.status, 'status', CommentsStatus.success)
              .having((s) => s.topLevelComments.length, 'comments count', 1),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits [loading, success] with empty list when no comments',
        setUp: () {
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => CommentThread.empty(validId('root')));
        },
        build: () => createBloc(),
        act: (bloc) => bloc.add(const CommentsLoadRequested()),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.status,
            'status',
            CommentsStatus.loading,
          ),
          isA<CommentsState>()
              .having((s) => s.status, 'status', CommentsStatus.success)
              .having((s) => s.topLevelComments, 'comments', isEmpty),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits [loading, failure] when loading fails',
        setUp: () {
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: () => createBloc(),
        act: (bloc) => bloc.add(const CommentsLoadRequested()),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.status,
            'status',
            CommentsStatus.loading,
          ),
          isA<CommentsState>()
              .having((s) => s.status, 'status', CommentsStatus.failure)
              .having((s) => s.error, 'error', CommentsError.loadFailed),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'builds correct comment tree with replies',
        setUp: () {
          final parentComment = Comment(
            id: validId('parent'),
            content: 'Parent comment',
            authorPubkey: validId('commenter1'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          final replyComment = Comment(
            id: validId('reply'),
            content: 'Reply comment',
            authorPubkey: validId('commenter2'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000001000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
            replyToEventId: parentComment.id,
            replyToAuthorPubkey: validId('commenter1'),
          );
          final thread = CommentThread(
            rootEventId: validId('root'),
            topLevelComments: [
              CommentNode(
                comment: parentComment,
                replies: [CommentNode(comment: replyComment)],
              ),
            ],
            totalCount: 2,
            commentCache: {
              parentComment.id: parentComment,
              replyComment.id: replyComment,
            },
          );
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => thread);
        },
        build: () => createBloc(),
        act: (bloc) => bloc.add(const CommentsLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.topLevelComments.length, 1);
          expect(bloc.state.topLevelComments.first.replies.length, 1);
        },
      );
    });

    group('CommentTextChanged', () {
      blocTest<CommentsBloc, CommentsState>(
        'updates main input text when commentId is null',
        build: createBloc,
        act: (bloc) => bloc.add(const CommentTextChanged('Hello')),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.mainInputText,
            'mainInputText',
            'Hello',
          ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'updates reply text when commentId is provided',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const CommentTextChanged('Reply', commentId: 'comment1')),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.replyInputText,
            'replyInputText',
            'Reply',
          ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'clears error when updating text',
        seed: () => const CommentsState(error: CommentsError.loadFailed),
        build: createBloc,
        act: (bloc) => bloc.add(const CommentTextChanged('New text')),
        expect: () => [
          isA<CommentsState>()
              .having((s) => s.mainInputText, 'mainInputText', 'New text')
              .having((s) => s.error, 'error', null),
        ],
      );
    });

    group('CommentReplyToggled', () {
      blocTest<CommentsBloc, CommentsState>(
        'opens reply for a comment',
        build: createBloc,
        act: (bloc) => bloc.add(const CommentReplyToggled('comment1')),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.activeReplyCommentId,
            'activeReplyCommentId',
            'comment1',
          ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'closes reply when toggling same comment',
        seed: () => const CommentsState(activeReplyCommentId: 'comment1'),
        build: createBloc,
        act: (bloc) => bloc.add(const CommentReplyToggled('comment1')),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.activeReplyCommentId,
            'activeReplyCommentId',
            null,
          ),
        ],
      );
    });

    group('CommentSubmitted', () {
      blocTest<CommentsBloc, CommentsState>(
        'posts main comment via repository when authenticated',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(validId('currentuser'));

          // Mock successful post
          final postedComment = Comment(
            id: validId('posted'),
            content: 'Test',
            authorPubkey: validId('currentuser'),
            createdAt: DateTime.now(),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            ),
          ).thenAnswer((_) async => postedComment);
        },
        seed: () => const CommentsState(mainInputText: 'Test comment'),
        build: createBloc,
        act: (bloc) => bloc.add(const CommentSubmitted()),
        verify: (_) {
          verify(
            () => mockCommentsRepository.postComment(
              content: 'Test comment',
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              replyToEventId: null,
              replyToAuthorPubkey: null,
            ),
          ).called(1);
        },
      );

      blocTest<CommentsBloc, CommentsState>(
        'posts reply via repository when parentCommentId provided',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(validId('currentuser'));

          final postedComment = Comment(
            id: validId('posted'),
            content: 'Reply',
            authorPubkey: validId('currentuser'),
            createdAt: DateTime.now(),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
            replyToEventId: 'parent1',
          );
          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            ),
          ).thenAnswer((_) async => postedComment);
        },
        seed: () => const CommentsState(
          replyInputText: 'Reply text',
          activeReplyCommentId: 'parent1',
        ),
        build: createBloc,
        act: (bloc) => bloc.add(
          const CommentSubmitted(
            parentCommentId: 'parent1',
            parentAuthorPubkey: 'author1',
          ),
        ),
        verify: (_) {
          verify(
            () => mockCommentsRepository.postComment(
              content: 'Reply text',
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              replyToEventId: 'parent1',
              replyToAuthorPubkey: 'author1',
            ),
          ).called(1);
        },
      );

      blocTest<CommentsBloc, CommentsState>(
        'does nothing when text is empty',
        seed: () => const CommentsState(mainInputText: ''),
        build: createBloc,
        act: (bloc) => bloc.add(const CommentSubmitted()),
        expect: () => <CommentsState>[],
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits error when not authenticated',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
        },
        seed: () => const CommentsState(mainInputText: 'Test'),
        build: createBloc,
        act: (bloc) => bloc.add(const CommentSubmitted()),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.error,
            'error',
            CommentsError.notAuthenticated,
          ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits error when posting fails',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(validId('currentuser'));

          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        seed: () => const CommentsState(
          mainInputText: 'Test comment',
          topLevelComments: [],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const CommentSubmitted()),
        expect: () => [
          // First: isPosting = true
          isA<CommentsState>().having((s) => s.isPosting, 'isPosting', true),
          // Second: error emitted, no comments added
          isA<CommentsState>()
              .having((s) => s.topLevelComments.length, 'comments', 0)
              .having((s) => s.isPosting, 'isPosting', false)
              .having((s) => s.error, 'error', CommentsError.postCommentFailed),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits error when posting reply fails',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(validId('currentuser'));

          when(
            () => mockCommentsRepository.postComment(
              content: any(named: 'content'),
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              replyToEventId: any(named: 'replyToEventId'),
              replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        seed: () {
          final parentComment = Comment(
            id: validId('parent'),
            content: 'Parent comment',
            authorPubkey: validId('author1'),
            createdAt: DateTime.now(),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            replyInputText: 'Reply text',
            activeReplyCommentId: validId('parent'),
            topLevelComments: [CommentNode(comment: parentComment)],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          CommentSubmitted(
            parentCommentId: validId('parent'),
            parentAuthorPubkey: validId('author1'),
          ),
        ),
        expect: () => [
          // First: isPosting = true
          isA<CommentsState>().having((s) => s.isPosting, 'isPosting', true),
          // Second: error emitted, no reply added
          isA<CommentsState>()
              .having(
                (s) => s.topLevelComments.first.replies.length,
                'replies',
                0,
              )
              .having((s) => s.isPosting, 'isPosting', false)
              .having((s) => s.error, 'error', CommentsError.postReplyFailed),
        ],
      );
    });
  });

  group('CommentsState', () {
    test('supports value equality', () {
      final state1 = CommentsState(
        status: CommentsStatus.success,
        rootEventId: 'event1',
        rootAuthorPubkey: 'author1',
        topLevelComments: const [],
      );
      final state2 = CommentsState(
        status: CommentsStatus.success,
        rootEventId: 'event1',
        rootAuthorPubkey: 'author1',
        topLevelComments: const [],
      );

      expect(state1, equals(state2));
    });

    test('copyWith creates copy with updated values', () {
      const state = CommentsState(
        status: CommentsStatus.initial,
        rootEventId: 'event1',
        rootAuthorPubkey: 'author1',
      );

      final updated = state.copyWith(
        status: CommentsStatus.loading,
        error: CommentsError.loadFailed,
      );

      expect(updated.status, CommentsStatus.loading);
      expect(updated.error, CommentsError.loadFailed);
      expect(updated.rootEventId, 'event1');
    });

    test('copyWith preserves values when not specified', () {
      const state = CommentsState(
        status: CommentsStatus.success,
        rootEventId: 'event1',
        rootAuthorPubkey: 'author1',
      );

      final updated = state.copyWith();

      expect(updated.status, CommentsStatus.success);
      expect(updated.rootEventId, 'event1');
    });

    test('copyWith sets error to null by default', () {
      const state = CommentsState(error: CommentsError.loadFailed);

      final updated = state.copyWith();

      expect(updated.error, null);
    });

    test('clearActiveReply clears activeReplyCommentId and replyInputText', () {
      const state = CommentsState(
        activeReplyCommentId: 'comment1',
        replyInputText: 'draft reply',
      );

      final updated = state.clearActiveReply();

      expect(updated.activeReplyCommentId, null);
      expect(updated.replyInputText, '');
    });

    test('copyWith preserves activeReplyCommentId when not provided', () {
      const state = CommentsState(activeReplyCommentId: 'comment1');

      final updated = state.copyWith(mainInputText: 'test');

      expect(updated.activeReplyCommentId, 'comment1');
    });

    test('isReplyPosting returns true when posting reply to that comment', () {
      const state = CommentsState(
        isPosting: true,
        activeReplyCommentId: 'comment1',
      );

      expect(state.isReplyPosting('comment1'), true);
      expect(state.isReplyPosting('comment2'), false);
    });

    test('isReplyPosting returns false when not posting', () {
      const state = CommentsState(
        isPosting: false,
        activeReplyCommentId: 'comment1',
      );

      expect(state.isReplyPosting('comment1'), false);
    });
  });

  group('CommentNode', () {
    test('totalReplyCount returns correct count including nested replies', () {
      final node = CommentNode(
        comment: Comment(
          id: 'comment1',
          content: 'Parent',
          authorPubkey: 'author1',
          createdAt: DateTime.now(),
          rootEventId: 'root',
          rootAuthorPubkey: 'author',
        ),
        replies: [
          CommentNode(
            comment: Comment(
              id: 'reply1',
              content: 'Reply 1',
              authorPubkey: 'author2',
              createdAt: DateTime.now(),
              rootEventId: 'root',
              rootAuthorPubkey: 'author',
            ),
            replies: [
              CommentNode(
                comment: Comment(
                  id: 'nested1',
                  content: 'Nested reply',
                  authorPubkey: 'author3',
                  createdAt: DateTime.now(),
                  rootEventId: 'root',
                  rootAuthorPubkey: 'author',
                ),
              ),
            ],
          ),
          CommentNode(
            comment: Comment(
              id: 'reply2',
              content: 'Reply 2',
              authorPubkey: 'author4',
              createdAt: DateTime.now(),
              rootEventId: 'root',
              rootAuthorPubkey: 'author',
            ),
          ),
        ],
      );

      expect(node.totalReplyCount, 3);
    });

    test('supports value equality', () {
      final comment = Comment(
        id: 'comment1',
        content: 'Test',
        authorPubkey: 'author1',
        createdAt: DateTime(2024),
        rootEventId: 'root',
        rootAuthorPubkey: 'author',
      );

      final node1 = CommentNode(comment: comment);
      final node2 = CommentNode(comment: comment);

      expect(node1, equals(node2));
    });
  });
}
