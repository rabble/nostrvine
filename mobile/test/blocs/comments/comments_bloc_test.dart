// ABOUTME: Tests for CommentsBloc - loading comments, posting, and tree building
// ABOUTME: Tests comment stream handling and error cases

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/follow_repository.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockContentReportingService extends Mock
    implements ContentReportingService {}

class _MockMuteService extends Mock implements MuteService {}

class _MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

class _MockUserProfileService extends Mock implements UserProfileService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const CommentsLoadRequested());
    registerFallbackValue(ContentFilterReason.spam);
  });

  group('CommentsBloc', () {
    late _MockCommentsRepository mockCommentsRepository;
    late _MockAuthService mockAuthService;
    late _MockLikesRepository mockLikesRepository;
    late _MockContentReportingService mockContentReportingService;
    late _MockMuteService mockMuteService;
    late _MockContentBlocklistService mockContentBlocklistService;
    late _MockUserProfileService mockUserProfileService;
    late _MockFollowRepository mockFollowRepository;

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
      mockLikesRepository = _MockLikesRepository();
      mockContentReportingService = _MockContentReportingService();
      mockMuteService = _MockMuteService();
      mockContentBlocklistService = _MockContentBlocklistService();
      mockUserProfileService = _MockUserProfileService();
      mockFollowRepository = _MockFollowRepository();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(validId('currentuser'));

      // Default stubs for like-related calls
      when(
        () => mockLikesRepository.getLikeCounts(any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockLikesRepository.isLiked(any()),
      ).thenAnswer((_) async => false);

      // Default stubs for mention search dependencies
      when(
        () => mockUserProfileService.getCachedProfile(any()),
      ).thenReturn(null);
      when(
        () => mockUserProfileService.searchUsers(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
    });

    // Video kind 34236 for NIP-71 addressable short videos
    const testRootEventKind = 34236;

    CommentsBloc createBloc({
      String? rootEventId,
      String? rootAuthorPubkey,
      UserProfileService? userProfileService,
      FollowRepository? followRepository,
    }) => CommentsBloc(
      commentsRepository: mockCommentsRepository,
      authService: mockAuthService,
      likesRepository: mockLikesRepository,
      contentReportingServiceFuture: Future.value(mockContentReportingService),
      muteServiceFuture: Future.value(mockMuteService),
      contentBlocklistService: mockContentBlocklistService,
      rootEventId: rootEventId ?? validId('root'),
      rootEventKind: testRootEventKind,
      rootAuthorPubkey: rootAuthorPubkey ?? validId('author'),
      userProfileService: userProfileService ?? mockUserProfileService,
      followRepository: followRepository ?? mockFollowRepository,
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
            comments: [comment],
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
              .having((s) => s.comments.length, 'comments count', 1),
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
              .having((s) => s.comments, 'comments', isEmpty),
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
            comments: [parentComment, replyComment],
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
          // Should have 2 total comments (1 parent + 1 reply)
          expect(bloc.state.comments.length, 2);
          // Find the parent comment (no replyToEventId)
          final parentComments = bloc.state.comments
              .where((c) => c.replyToEventId == null)
              .toList();
          expect(parentComments.length, 1);
          // Find replies to the parent comment
          final replies = bloc.state.comments
              .where((c) => c.replyToEventId == parentComments.first.id)
              .toList();
          expect(replies.length, 1);
        },
      );
    });

    group('CommentsLoadMoreRequested', () {
      blocTest<CommentsBloc, CommentsState>(
        'does nothing when status is not success',
        build: createBloc,
        seed: () => const CommentsState(status: CommentsStatus.loading),
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        expect: () => <CommentsState>[],
      );

      blocTest<CommentsBloc, CommentsState>(
        'does nothing when already loading more',
        build: createBloc,
        seed: () => const CommentsState(
          status: CommentsStatus.success,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        expect: () => <CommentsState>[],
      );

      blocTest<CommentsBloc, CommentsState>(
        'does nothing when no more content',
        build: createBloc,
        seed: () => const CommentsState(
          status: CommentsStatus.success,
          hasMoreContent: false,
        ),
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        expect: () => <CommentsState>[],
      );

      blocTest<CommentsBloc, CommentsState>(
        'does nothing when comments list is empty',
        build: createBloc,
        seed: () => const CommentsState(
          status: CommentsStatus.success,
          hasMoreContent: true,
          commentsById: {},
        ),
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        expect: () => <CommentsState>[],
      );

      blocTest<CommentsBloc, CommentsState>(
        'loads more comments and appends to list',
        setUp: () {
          final olderComment = Comment(
            id: validId('older'),
            content: 'Older comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          final thread = CommentThread(
            rootEventId: validId('root'),
            comments: [olderComment],
            totalCount: 1,
            commentCache: {olderComment.id: olderComment},
          );
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => thread);
        },
        build: createBloc,
        seed: () {
          final existingComment = Comment(
            id: validId('existing'),
            content: 'Existing comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            hasMoreContent: true,
            commentsById: {existingComment.id: existingComment},
          );
        },
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<CommentsState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.comments.length, 'comments count', 2),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'sets hasMoreContent to false when fewer than page size returned',
        setUp: () {
          // Return only 1 comment (less than page size of 50)
          final olderComment = Comment(
            id: validId('older'),
            content: 'Older comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          final thread = CommentThread(
            rootEventId: validId('root'),
            comments: [olderComment],
            totalCount: 1,
            commentCache: {olderComment.id: olderComment},
          );
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => thread);
        },
        build: createBloc,
        seed: () {
          final existingComment = Comment(
            id: validId('existing'),
            content: 'Existing comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            hasMoreContent: true,
            commentsById: {existingComment.id: existingComment},
          );
        },
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<CommentsState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.hasMoreContent, 'hasMoreContent', false),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'handles error gracefully when loading more fails',
        setUp: () {
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        seed: () {
          final existingComment = Comment(
            id: validId('existing'),
            content: 'Existing comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            hasMoreContent: true,
            commentsById: {existingComment.id: existingComment},
          );
        },
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          // Should reset isLoadingMore but preserve existing comments
          isA<CommentsState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.comments.length, 'comments count', 1),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'passes correct before cursor to repository',
        setUp: () {
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => CommentThread.empty(validId('root')));
        },
        build: createBloc,
        seed: () {
          // Comment with specific timestamp
          final existingComment = Comment(
            id: validId('existing'),
            content: 'Existing comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            hasMoreContent: true,
            commentsById: {existingComment.id: existingComment},
          );
        },
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        verify: (_) {
          // Verify that before cursor is the exact timestamp of the oldest comment
          // (no longer subtracting 1 second - deduplication handles overlaps)
          final expectedCursor = DateTime.fromMillisecondsSinceEpoch(
            2000000000,
          );

          verify(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              limit: 50,
              before: expectedCursor,
            ),
          ).called(1);
        },
      );

      blocTest<CommentsBloc, CommentsState>(
        'deduplicates comments when loading more returns overlapping results',
        setUp: () {
          // Return the same comment that already exists (simulating overlap)
          final duplicateComment = Comment(
            id: validId('existing'),
            content: 'Existing comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          final newComment = Comment(
            id: validId('new'),
            content: 'New older comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          final thread = CommentThread(
            rootEventId: validId('root'),
            comments: [duplicateComment, newComment],
            totalCount: 2,
            commentCache: {
              duplicateComment.id: duplicateComment,
              newComment.id: newComment,
            },
          );
          when(
            () => mockCommentsRepository.loadComments(
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => thread);
        },
        build: createBloc,
        seed: () {
          final existingComment = Comment(
            id: validId('existing'),
            content: 'Existing comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            hasMoreContent: true,
            commentsById: {existingComment.id: existingComment},
          );
        },
        act: (bloc) => bloc.add(const CommentsLoadMoreRequested()),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          // Should have 2 comments (1 existing + 1 new), not 3 (duplicate filtered)
          isA<CommentsState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.comments.length, 'comments count', 2),
        ],
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
          commentsById: {},
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const CommentSubmitted()),
        expect: () => [
          // First: isPosting = true
          isA<CommentsState>().having((s) => s.isPosting, 'isPosting', true),
          // Second: error emitted, no comments added
          isA<CommentsState>()
              .having((s) => s.comments.length, 'comments', 0)
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
            commentsById: {parentComment.id: parentComment},
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
                (s) => s.comments.where((c) => c.replyToEventId != null).length,
                'replies',
                0,
              )
              .having((s) => s.isPosting, 'isPosting', false)
              .having((s) => s.error, 'error', CommentsError.postReplyFailed),
        ],
      );
    });

    group('CommentLikeToggled', () {
      blocTest<CommentsBloc, CommentsState>(
        'emits optimistic like update when unliked comment is toggled',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) async => true);
        },
        build: createBloc,
        seed: () {
          final comment = Comment(
            id: validId('likecomment'),
            content: 'Likeable comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            commentsById: {comment.id: comment},
            commentLikeCounts: {comment.id: 5},
            likedCommentIds: const {},
          );
        },
        act: (bloc) => bloc.add(
          CommentLikeToggled(
            commentId: validId('likecomment'),
            authorPubkey: validId('commenter'),
          ),
        ),
        expect: () => [
          // First emit: optimistic update with like added
          isA<CommentsState>()
              .having(
                (s) => s.likedCommentIds.contains(validId('likecomment')),
                'liked',
                true,
              )
              .having(
                (s) => s.commentLikeCounts[validId('likecomment')],
                'count',
                6,
              )
              .having(
                (s) => s.likeInProgressCommentId,
                'likeInProgressCommentId',
                validId('likecomment'),
              ),
          // Second emit: clears likeInProgressCommentId on success
          isA<CommentsState>()
              .having(
                (s) => s.likedCommentIds.contains(validId('likecomment')),
                'liked',
                true,
              )
              .having(
                (s) => s.commentLikeCounts[validId('likecomment')],
                'count',
                6,
              )
              .having(
                (s) => s.likeInProgressCommentId,
                'likeInProgressCommentId',
                null,
              ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits optimistic unlike update when liked comment is toggled',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenAnswer((_) async => false);
        },
        build: createBloc,
        seed: () {
          final comment = Comment(
            id: validId('likecomment'),
            content: 'Already liked comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            commentsById: {comment.id: comment},
            commentLikeCounts: {comment.id: 3},
            likedCommentIds: {comment.id},
          );
        },
        act: (bloc) => bloc.add(
          CommentLikeToggled(
            commentId: validId('likecomment'),
            authorPubkey: validId('commenter'),
          ),
        ),
        expect: () => [
          // First emit: optimistic unlike
          isA<CommentsState>()
              .having(
                (s) => s.likedCommentIds.contains(validId('likecomment')),
                'liked',
                false,
              )
              .having(
                (s) => s.commentLikeCounts[validId('likecomment')],
                'count',
                2,
              )
              .having(
                (s) => s.likeInProgressCommentId,
                'likeInProgressCommentId',
                validId('likecomment'),
              ),
          // Second emit: clears likeInProgressCommentId on success
          isA<CommentsState>()
              .having(
                (s) => s.likedCommentIds.contains(validId('likecomment')),
                'liked',
                false,
              )
              .having(
                (s) => s.likeInProgressCommentId,
                'likeInProgressCommentId',
                null,
              ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'reverts optimistic update on failure',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              targetKind: any(named: 'targetKind'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        seed: () {
          final comment = Comment(
            id: validId('likecomment'),
            content: 'Comment to like',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            commentsById: {comment.id: comment},
            commentLikeCounts: {comment.id: 5},
            likedCommentIds: const {},
          );
        },
        act: (bloc) => bloc.add(
          CommentLikeToggled(
            commentId: validId('likecomment'),
            authorPubkey: validId('commenter'),
          ),
        ),
        expect: () => [
          // First emit: optimistic like
          isA<CommentsState>()
              .having(
                (s) => s.likedCommentIds.contains(validId('likecomment')),
                'liked',
                true,
              )
              .having(
                (s) => s.commentLikeCounts[validId('likecomment')],
                'count',
                6,
              ),
          // Second emit: reverted on error
          isA<CommentsState>()
              .having(
                (s) => s.likedCommentIds.contains(validId('likecomment')),
                'liked',
                false,
              )
              .having(
                (s) => s.commentLikeCounts[validId('likecomment')],
                'count',
                5,
              )
              .having((s) => s.error, 'error', CommentsError.likeFailed),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'does nothing when same comment like is in progress',
        build: createBloc,
        seed: () {
          final comment = Comment(
            id: validId('likecomment'),
            content: 'Comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            commentsById: {comment.id: comment},
            likeInProgressCommentId: validId('likecomment'),
          );
        },
        act: (bloc) => bloc.add(
          CommentLikeToggled(
            commentId: validId('likecomment'),
            authorPubkey: validId('commenter'),
          ),
        ),
        expect: () => <CommentsState>[],
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits error when not authenticated',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
        },
        build: createBloc,
        seed: () {
          final comment = Comment(
            id: validId('likecomment'),
            content: 'Comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            commentsById: {comment.id: comment},
          );
        },
        act: (bloc) => bloc.add(
          CommentLikeToggled(
            commentId: validId('likecomment'),
            authorPubkey: validId('commenter'),
          ),
        ),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.error,
            'error',
            CommentsError.notAuthenticated,
          ),
        ],
      );
    });

    group('CommentLikeCountsFetchRequested', () {
      blocTest<CommentsBloc, CommentsState>(
        'fetches like counts and liked status for all comments',
        setUp: () {
          when(() => mockLikesRepository.getLikeCounts(any())).thenAnswer(
            (_) async => {validId('comment1'): 10, validId('comment2'): 3},
          );
          when(
            () => mockLikesRepository.isLiked(validId('comment1')),
          ).thenAnswer((_) async => true);
          when(
            () => mockLikesRepository.isLiked(validId('comment2')),
          ).thenAnswer((_) async => false);
        },
        build: createBloc,
        seed: () {
          final comment1 = Comment(
            id: validId('comment1'),
            content: 'First comment',
            authorPubkey: validId('commenter1'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          final comment2 = Comment(
            id: validId('comment2'),
            content: 'Second comment',
            authorPubkey: validId('commenter2'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            commentsById: {comment1.id: comment1, comment2.id: comment2},
          );
        },
        act: (bloc) => bloc.add(const CommentLikeCountsFetchRequested()),
        expect: () => [
          isA<CommentsState>()
              .having(
                (s) => s.commentLikeCounts[validId('comment1')],
                'comment1 count',
                10,
              )
              .having(
                (s) => s.commentLikeCounts[validId('comment2')],
                'comment2 count',
                3,
              )
              .having(
                (s) => s.likedCommentIds.contains(validId('comment1')),
                'comment1 liked',
                true,
              )
              .having(
                (s) => s.likedCommentIds.contains(validId('comment2')),
                'comment2 liked',
                false,
              ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'does nothing when commentsById is empty',
        build: createBloc,
        seed: () => const CommentsState(
          status: CommentsStatus.success,
          commentsById: {},
        ),
        act: (bloc) => bloc.add(const CommentLikeCountsFetchRequested()),
        expect: () => <CommentsState>[],
        verify: (_) {
          verifyNever(() => mockLikesRepository.getLikeCounts(any()));
          verifyNever(() => mockLikesRepository.isLiked(any()));
        },
      );

      blocTest<CommentsBloc, CommentsState>(
        'handles errors gracefully',
        setUp: () {
          when(
            () => mockLikesRepository.getLikeCounts(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        seed: () {
          final comment = Comment(
            id: validId('comment1'),
            content: 'A comment',
            authorPubkey: validId('commenter'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            commentsById: {comment.id: comment},
          );
        },
        act: (bloc) => bloc.add(const CommentLikeCountsFetchRequested()),
        expect: () => <CommentsState>[],
      );
    });

    group('CommentsSortModeChanged', () {
      blocTest<CommentsBloc, CommentsState>(
        'emits state with newest sort mode',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const CommentsSortModeChanged(CommentsSortMode.newest)),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.sortMode,
            'sortMode',
            CommentsSortMode.newest,
          ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits state with oldest sort mode',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const CommentsSortModeChanged(CommentsSortMode.oldest)),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.sortMode,
            'sortMode',
            CommentsSortMode.oldest,
          ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits state with topEngagement sort mode',
        build: createBloc,
        act: (bloc) => bloc.add(
          const CommentsSortModeChanged(CommentsSortMode.topEngagement),
        ),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.sortMode,
            'sortMode',
            CommentsSortMode.topEngagement,
          ),
        ],
      );

      test('comments getter returns newest first when sort mode is newest', () {
        final older = Comment(
          id: validId('older'),
          content: 'Older',
          authorPubkey: validId('commenter'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
          rootEventId: validId('root'),
          rootAuthorPubkey: validId('author'),
        );
        final newer = Comment(
          id: validId('newer'),
          content: 'Newer',
          authorPubkey: validId('commenter'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
          rootEventId: validId('root'),
          rootAuthorPubkey: validId('author'),
        );
        final state = CommentsState(
          sortMode: CommentsSortMode.newest,
          commentsById: {older.id: older, newer.id: newer},
        );

        final comments = state.comments;
        expect(comments.first.id, newer.id);
        expect(comments.last.id, older.id);
      });

      test('comments getter returns oldest first when sort mode is oldest', () {
        final older = Comment(
          id: validId('older'),
          content: 'Older',
          authorPubkey: validId('commenter'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
          rootEventId: validId('root'),
          rootAuthorPubkey: validId('author'),
        );
        final newer = Comment(
          id: validId('newer'),
          content: 'Newer',
          authorPubkey: validId('commenter'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
          rootEventId: validId('root'),
          rootAuthorPubkey: validId('author'),
        );
        final state = CommentsState(
          sortMode: CommentsSortMode.oldest,
          commentsById: {older.id: older, newer.id: newer},
        );

        final comments = state.comments;
        expect(comments.first.id, older.id);
        expect(comments.last.id, newer.id);
      });
    });

    group('CommentReportRequested', () {
      blocTest<CommentsBloc, CommentsState>(
        'reports comment successfully',
        setUp: () {
          when(
            () => mockContentReportingService.reportContent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              reason: any(named: 'reason'),
              details: any(named: 'details'),
            ),
          ).thenAnswer((_) async => ReportResult.createSuccess('report-id'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          CommentReportRequested(
            commentId: validId('badcomment'),
            authorPubkey: validId('baduser'),
            reason: ContentFilterReason.spam,
          ),
        ),
        expect: () => <CommentsState>[],
        verify: (_) {
          verify(
            () => mockContentReportingService.reportContent(
              eventId: validId('badcomment'),
              authorPubkey: validId('baduser'),
              reason: ContentFilterReason.spam,
              details: '',
            ),
          ).called(1);
        },
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits error when reporting fails',
        setUp: () {
          when(
            () => mockContentReportingService.reportContent(
              eventId: any(named: 'eventId'),
              authorPubkey: any(named: 'authorPubkey'),
              reason: any(named: 'reason'),
              details: any(named: 'details'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          CommentReportRequested(
            commentId: validId('badcomment'),
            authorPubkey: validId('baduser'),
            reason: ContentFilterReason.harassment,
          ),
        ),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.error,
            'error',
            CommentsError.reportFailed,
          ),
        ],
      );
    });

    group('CommentBlockUserRequested', () {
      blocTest<CommentsBloc, CommentsState>(
        'blocks user and removes their comments',
        setUp: () {
          when(
            () => mockMuteService.muteUser(any()),
          ).thenAnswer((_) async => true);
          when(
            () => mockContentBlocklistService.blockUser(any()),
          ).thenReturn(null);
        },
        build: createBloc,
        seed: () {
          final comment1 = Comment(
            id: validId('goodcomment'),
            content: 'Good comment',
            authorPubkey: validId('gooduser'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          final comment2 = Comment(
            id: validId('badcomment1'),
            content: 'Bad comment 1',
            authorPubkey: validId('baduser'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          final comment3 = Comment(
            id: validId('badcomment2'),
            content: 'Bad comment 2',
            authorPubkey: validId('baduser'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(3000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          // Add a reply to comment2 from gooduser to test replyCountsByCommentId
          final reply = Comment(
            id: validId('replytocomment2'),
            content: 'Reply to bad comment',
            authorPubkey: validId('gooduser'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(2500000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
            replyToEventId: validId('badcomment1'),
            replyToAuthorPubkey: validId('baduser'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            commentsById: {
              comment1.id: comment1,
              comment2.id: comment2,
              comment3.id: comment3,
              reply.id: reply,
            },
            replyCountsByCommentId: {validId('badcomment1'): 1},
          );
        },
        act: (bloc) => bloc.add(CommentBlockUserRequested(validId('baduser'))),
        expect: () => [
          isA<CommentsState>()
              .having((s) => s.commentsById.length, 'comments count', 2)
              .having(
                (s) => s.commentsById.containsKey(validId('goodcomment')),
                'good comment preserved',
                true,
              )
              .having(
                (s) => s.commentsById.containsKey(validId('badcomment1')),
                'bad comment1 removed',
                false,
              )
              .having(
                (s) => s.commentsById.containsKey(validId('badcomment2')),
                'bad comment2 removed',
                false,
              )
              .having((s) => s.replyCountsByCommentId, 'reply counts updated', {
                validId('badcomment1'): 1,
              }),
        ],
        verify: (_) {
          verify(() => mockMuteService.muteUser(validId('baduser'))).called(1);
          verify(
            () => mockContentBlocklistService.blockUser(validId('baduser')),
          ).called(1);
        },
      );

      blocTest<CommentsBloc, CommentsState>(
        'emits error when blocking fails',
        setUp: () {
          when(
            () => mockMuteService.muteUser(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        seed: () {
          final comment = Comment(
            id: validId('comment'),
            content: 'Comment',
            authorPubkey: validId('baduser'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            commentsById: {comment.id: comment},
          );
        },
        act: (bloc) => bloc.add(CommentBlockUserRequested(validId('baduser'))),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.error,
            'error',
            CommentsError.blockFailed,
          ),
        ],
      );
    });

    group('MentionSearchRequested', () {
      blocTest<CommentsBloc, CommentsState>(
        'filters suggestions by query matching display name',
        setUp: () {
          when(
            () => mockUserProfileService.getCachedProfile(validId('user1')),
          ).thenReturn(
            UserProfile(
              pubkey: validId('user1'),
              rawData: const {},
              createdAt: DateTime.now(),
              eventId: validId('event1'),
              displayName: 'Alice',
            ),
          );
          when(
            () => mockUserProfileService.getCachedProfile(validId('user2')),
          ).thenReturn(
            UserProfile(
              pubkey: validId('user2'),
              rawData: const {},
              createdAt: DateTime.now(),
              eventId: validId('event2'),
              displayName: 'Bob',
            ),
          );
        },
        build: createBloc,
        seed: () {
          final comment1 = Comment(
            id: validId('comment1'),
            content: 'Comment 1',
            authorPubkey: validId('user1'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          final comment2 = Comment(
            id: validId('comment2'),
            content: 'Comment 2',
            authorPubkey: validId('user2'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            commentsById: {comment1.id: comment1, comment2.id: comment2},
          );
        },
        act: (bloc) => bloc.add(const MentionSearchRequested('ali')),
        expect: () => [
          // Tier 1: local match for Alice only
          // Tier 2 produces identical state (no new remote results),
          // so BLoC deduplicates via Equatable — only one emit.
          isA<CommentsState>()
              .having((s) => s.mentionQuery, 'mentionQuery', 'ali')
              .having(
                (s) => s.mentionSuggestions.length,
                'suggestions count',
                1,
              )
              .having(
                (s) => s.mentionSuggestions.first.displayName,
                'displayName',
                'Alice',
              ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'clears suggestions on empty query',
        build: createBloc,
        seed: () => CommentsState(
          mentionQuery: 'test',
          mentionSuggestions: [MentionSuggestion(pubkey: validId('user1'))],
        ),
        act: (bloc) => bloc.add(const MentionSearchRequested('')),
        expect: () => [
          isA<CommentsState>()
              .having((s) => s.mentionQuery, 'mentionQuery', '')
              .having((s) => s.mentionSuggestions, 'suggestions', isEmpty),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'includes following list in search candidates',
        setUp: () {
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([validId('followee1')]);
          when(
            () => mockUserProfileService.getCachedProfile(validId('followee1')),
          ).thenReturn(
            UserProfile(
              pubkey: validId('followee1'),
              rawData: const {},
              createdAt: DateTime.now(),
              eventId: validId('event3'),
              displayName: 'FollowedUser',
            ),
          );
        },
        build: createBloc,
        seed: () => const CommentsState(status: CommentsStatus.success),
        act: (bloc) => bloc.add(const MentionSearchRequested('follow')),
        expect: () => [
          // Tier 1: following list match.
          // Tier 2 produces identical state (no new remote results),
          // so BLoC deduplicates via Equatable — only one emit.
          isA<CommentsState>().having(
            (s) => s.mentionSuggestions.length,
            'suggestions count',
            1,
          ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'fetches remote results when fewer than 5 local matches',
        setUp: () {
          when(
            () => mockUserProfileService.searchUsers(
              'rem',
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              UserProfile(
                pubkey: validId('remote1'),
                rawData: const {},
                createdAt: DateTime.now(),
                eventId: validId('event4'),
                displayName: 'RemoteUser',
              ),
            ],
          );
        },
        build: createBloc,
        seed: () => const CommentsState(status: CommentsStatus.success),
        act: (bloc) => bloc.add(const MentionSearchRequested('rem')),
        expect: () => [
          // Tier 1: no local matches
          isA<CommentsState>().having(
            (s) => s.mentionSuggestions,
            'suggestions',
            isEmpty,
          ),
          // Tier 2: remote result
          isA<CommentsState>()
              .having(
                (s) => s.mentionSuggestions.length,
                'suggestions count',
                1,
              )
              .having(
                (s) => s.mentionSuggestions.first.displayName,
                'displayName',
                'RemoteUser',
              ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'deduplicates authors in suggestions',
        setUp: () {
          when(
            () => mockUserProfileService.getCachedProfile(validId('sameuser')),
          ).thenReturn(
            UserProfile(
              pubkey: validId('sameuser'),
              rawData: const {},
              createdAt: DateTime.now(),
              eventId: validId('event5'),
              displayName: 'SameUser',
            ),
          );
        },
        build: createBloc,
        seed: () {
          final comment1 = Comment(
            id: validId('comment1'),
            content: 'Comment 1',
            authorPubkey: validId('sameuser'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          final comment2 = Comment(
            id: validId('comment2'),
            content: 'Comment 2',
            authorPubkey: validId('sameuser'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            commentsById: {comment1.id: comment1, comment2.id: comment2},
          );
        },
        act: (bloc) => bloc.add(const MentionSearchRequested('same')),
        expect: () => [
          // Tier 1: deduplicated to single suggestion.
          // Tier 2 produces identical state (no new remote results),
          // so BLoC deduplicates via Equatable — only one emit.
          isA<CommentsState>().having(
            (s) => s.mentionSuggestions.length,
            'suggestions count',
            1,
          ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'works without profile service (null)',
        build: () =>
            createBloc(userProfileService: null, followRepository: null),
        seed: () {
          final comment = Comment(
            id: validId('comment1'),
            content: 'Comment',
            authorPubkey: validId('user1'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
          );
          return CommentsState(
            status: CommentsStatus.success,
            commentsById: {comment.id: comment},
          );
        },
        act: (bloc) => bloc.add(const MentionSearchRequested('test')),
        expect: () => [
          // No profile service = no matches (can't look up names)
          isA<CommentsState>()
              .having((s) => s.mentionQuery, 'mentionQuery', 'test')
              .having((s) => s.mentionSuggestions, 'suggestions', isEmpty),
        ],
      );
    });

    group('MentionSuggestionsCleared', () {
      blocTest<CommentsBloc, CommentsState>(
        'clears mention query and suggestions',
        build: createBloc,
        seed: () => CommentsState(
          mentionQuery: 'test',
          mentionSuggestions: [MentionSuggestion(pubkey: validId('user1'))],
        ),
        act: (bloc) => bloc.add(const MentionSuggestionsCleared()),
        expect: () => [
          isA<CommentsState>()
              .having((s) => s.mentionQuery, 'mentionQuery', '')
              .having((s) => s.mentionSuggestions, 'suggestions', isEmpty),
        ],
      );
    });

    group('MentionRegistered', () {
      blocTest<CommentsBloc, CommentsState>(
        'adds displayName to npub mapping in activeMentions',
        build: createBloc,
        act: (bloc) => bloc.add(
          const MentionRegistered(displayName: 'Alice', npub: 'npub1alice'),
        ),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.activeMentions,
            'activeMentions',
            {'Alice': 'npub1alice'},
          ),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'accumulates multiple mentions',
        build: createBloc,
        seed: () =>
            const CommentsState(activeMentions: {'Alice': 'npub1alice'}),
        act: (bloc) => bloc.add(
          const MentionRegistered(displayName: 'Bob', npub: 'npub1bob'),
        ),
        expect: () => [
          isA<CommentsState>().having(
            (s) => s.activeMentions,
            'activeMentions',
            {'Alice': 'npub1alice', 'Bob': 'npub1bob'},
          ),
        ],
      );
    });

    group('mention conversion on submit', () {
      blocTest<CommentsBloc, CommentsState>(
        'converts @displayName to nostr:npub in posted text',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(validId('currentuser'));

          final postedComment = Comment(
            id: validId('posted'),
            content: 'hey nostr:npub1alice what do you think?',
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
        seed: () => const CommentsState(
          mainInputText: 'hey @Alice what do you think?',
          activeMentions: {'Alice': 'npub1alice'},
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const CommentSubmitted()),
        verify: (_) {
          verify(
            () => mockCommentsRepository.postComment(
              content: 'hey nostr:npub1alice what do you think?',
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
        'clears activeMentions after successful post',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(validId('currentuser'));

          final postedComment = Comment(
            id: validId('posted'),
            content: 'hey nostr:npub1alice',
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
        seed: () => const CommentsState(
          mainInputText: 'hey @Alice',
          activeMentions: {'Alice': 'npub1alice'},
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const CommentSubmitted()),
        expect: () => [
          // isPosting = true
          isA<CommentsState>().having((s) => s.isPosting, 'isPosting', true),
          // Success: mentions cleared, text cleared
          isA<CommentsState>()
              .having((s) => s.isPosting, 'isPosting', false)
              .having((s) => s.mainInputText, 'mainInputText', '')
              .having((s) => s.activeMentions, 'activeMentions', isEmpty),
        ],
      );

      blocTest<CommentsBloc, CommentsState>(
        'handles multiple mentions with longest-first replacement',
        setUp: () {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(validId('currentuser'));

          final postedComment = Comment(
            id: validId('posted'),
            content: 'nostr:npub1ali and nostr:npub1alice',
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
        seed: () => const CommentsState(
          mainInputText: '@Ali and @Alice',
          activeMentions: {'Alice': 'npub1alice', 'Ali': 'npub1ali'},
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const CommentSubmitted()),
        verify: (_) {
          // "Alice" (longer) should be replaced first, preventing
          // "@Ali" from partially matching "@Alice"
          verify(
            () => mockCommentsRepository.postComment(
              content: 'nostr:npub1ali and nostr:npub1alice',
              rootEventId: any(named: 'rootEventId'),
              rootEventKind: any(named: 'rootEventKind'),
              rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
              replyToEventId: null,
              replyToAuthorPubkey: null,
            ),
          ).called(1);
        },
      );
    });
  });

  group('threadedComments', () {
    // Helper to create valid hex IDs (64 hex characters)
    String validId(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    test('builds correct tree with parent and child', () {
      final parent = Comment(
        id: validId('parent'),
        content: 'Parent',
        authorPubkey: validId('user1'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );
      final child = Comment(
        id: validId('child'),
        content: 'Child',
        authorPubkey: validId('user2'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
        replyToEventId: validId('parent'),
        replyToAuthorPubkey: validId('user1'),
      );

      final state = CommentsState(
        sortMode: CommentsSortMode.oldest,
        commentsById: {parent.id: parent, child.id: child},
      );

      final threaded = state.threadedComments;
      expect(threaded.length, 2); // flattened: parent, child
      expect(threaded[0].depth, 0);
      expect(threaded[0].comment.id, parent.id);
      expect(threaded[1].depth, 1);
      expect(threaded[1].comment.id, child.id);
    });

    test('orphaned replies appear at depth 0', () {
      final orphan = Comment(
        id: validId('orphan'),
        content: 'Orphaned reply',
        authorPubkey: validId('user1'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
        replyToEventId: validId('missing'),
        replyToAuthorPubkey: validId('user2'),
      );

      final state = CommentsState(commentsById: {orphan.id: orphan});

      final threaded = state.threadedComments;
      expect(threaded.length, 1);
      expect(threaded[0].depth, 0);
    });

    test('deep nesting is preserved in tree structure', () {
      // Create a chain: c0 -> c1 -> c2 -> c3 -> c4 -> c5
      final comments = <Comment>[];
      for (var i = 0; i <= 5; i++) {
        comments.add(
          Comment(
            id: validId('c$i'),
            content: 'Comment $i',
            authorPubkey: validId('user$i'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              1000000000 + i * 1000,
            ),
            rootEventId: validId('root'),
            rootAuthorPubkey: validId('author'),
            replyToEventId: i > 0 ? validId('c${i - 1}') : null,
            replyToAuthorPubkey: i > 0 ? validId('user${i - 1}') : null,
          ),
        );
      }

      final state = CommentsState(
        sortMode: CommentsSortMode.oldest,
        commentsById: {for (final c in comments) c.id: c},
      );

      final threaded = state.threadedComments;
      expect(threaded.length, 6);
      for (var i = 0; i <= 5; i++) {
        expect(threaded[i].depth, i);
        expect(threaded[i].comment.id, validId('c$i'));
      }
    });

    test('empty commentsById returns empty list', () {
      const state = CommentsState();

      expect(state.threadedComments, isEmpty);
    });

    test('multiple root comments are sorted correctly', () {
      final older = Comment(
        id: validId('older'),
        content: 'Older',
        authorPubkey: validId('user1'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );
      final newer = Comment(
        id: validId('newer'),
        content: 'Newer',
        authorPubkey: validId('user2'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );

      final state = CommentsState(
        sortMode: CommentsSortMode.newest,
        commentsById: {older.id: older, newer.id: newer},
      );

      final threaded = state.threadedComments;
      expect(threaded[0].comment.id, newer.id);
      expect(threaded[1].comment.id, older.id);
    });
  });

  group('CommentsState', () {
    test('supports value equality', () {
      final state1 = CommentsState(
        status: CommentsStatus.success,
        rootEventId: 'event1',
        rootAuthorPubkey: 'author1',
        commentsById: const {},
      );
      final state2 = CommentsState(
        status: CommentsStatus.success,
        rootEventId: 'event1',
        rootAuthorPubkey: 'author1',
        commentsById: const {},
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

    test('comments sorts by engagement score correctly', () {
      // Helper for IDs in this scope
      String id(String suffix) {
        final hexSuffix = suffix.codeUnits
            .map((c) => c.toRadixString(16).padLeft(2, '0'))
            .join();
        return hexSuffix.padLeft(64, '0');
      }

      // Create comments with same timestamp so time decay is equal
      final now = DateTime.now();
      final lowEngagement = Comment(
        id: id('low'),
        content: 'Low engagement',
        authorPubkey: id('commenter'),
        createdAt: now,
        rootEventId: id('root'),
        rootAuthorPubkey: id('author'),
      );
      final highEngagement = Comment(
        id: id('high'),
        content: 'High engagement',
        authorPubkey: id('commenter'),
        createdAt: now,
        rootEventId: id('root'),
        rootAuthorPubkey: id('author'),
      );

      final state = CommentsState(
        sortMode: CommentsSortMode.topEngagement,
        commentsById: {
          lowEngagement.id: lowEngagement,
          highEngagement.id: highEngagement,
        },
        commentLikeCounts: {lowEngagement.id: 1, highEngagement.id: 20},
        replyCountsByCommentId: {lowEngagement.id: 0, highEngagement.id: 5},
      );

      final comments = state.comments;
      expect(comments.first.id, highEngagement.id);
      expect(comments.last.id, lowEngagement.id);
    });

    test('copyWith without likeInProgressCommentId clears it', () {
      const state = CommentsState(likeInProgressCommentId: 'some-comment-id');

      final updated = state.copyWith();

      expect(updated.likeInProgressCommentId, null);
    });

    test('copyWith with likeInProgressCommentId preserves it', () {
      const state = CommentsState();

      final updated = state.copyWith(
        likeInProgressCommentId: 'some-comment-id',
      );

      expect(updated.likeInProgressCommentId, 'some-comment-id');
    });

    test(
      'clearActiveReply clears mention query, suggestions, and activeMentions',
      () {
        final state = CommentsState(
          activeReplyCommentId: 'comment1',
          replyInputText: 'draft',
          mentionQuery: 'test',
          mentionSuggestions: [const MentionSuggestion(pubkey: 'abc')],
          activeMentions: const {'Alice': 'npub1alice'},
        );

        final updated = state.clearActiveReply();

        expect(updated.mentionQuery, '');
        expect(updated.mentionSuggestions, isEmpty);
        expect(updated.activeMentions, isEmpty);
      },
    );

    test('copyWith preserves mention fields when not specified', () {
      final state = CommentsState(
        mentionQuery: 'test',
        mentionSuggestions: [const MentionSuggestion(pubkey: 'abc')],
        activeMentions: const {'Alice': 'npub1alice'},
      );

      final updated = state.copyWith(mainInputText: 'hello');

      expect(updated.mentionQuery, 'test');
      expect(updated.mentionSuggestions.length, 1);
      expect(updated.activeMentions, {'Alice': 'npub1alice'});
    });
  });

  group(MentionSuggestion, () {
    test('supports value equality', () {
      const suggestion1 = MentionSuggestion(pubkey: 'abc');
      const suggestion2 = MentionSuggestion(pubkey: 'abc');
      const suggestion3 = MentionSuggestion(pubkey: 'def');

      expect(suggestion1, equals(suggestion2));
      expect(suggestion1, isNot(equals(suggestion3)));
    });

    test('includes all fields in equality', () {
      const suggestion1 = MentionSuggestion(
        pubkey: 'abc',
        displayName: 'Alice',
        picture: 'pic.jpg',
      );
      const suggestion2 = MentionSuggestion(
        pubkey: 'abc',
        displayName: 'Alice',
        picture: 'pic.jpg',
      );
      const suggestion3 = MentionSuggestion(
        pubkey: 'abc',
        displayName: 'Bob',
        picture: 'pic.jpg',
      );

      expect(suggestion1, equals(suggestion2));
      expect(suggestion1, isNot(equals(suggestion3)));
    });

    test('treats null and non-null optional fields as unequal', () {
      const withName = MentionSuggestion(pubkey: 'abc', displayName: 'Alice');
      const withoutName = MentionSuggestion(pubkey: 'abc');

      expect(withName, isNot(equals(withoutName)));
    });
  });

  group(CommentNode, () {
    // Helper to create valid hex IDs (64 hex characters)
    String validId(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    test('stores comment and depth', () {
      final comment = Comment(
        id: validId('test'),
        content: 'Test',
        authorPubkey: validId('user'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );

      final node = CommentNode(comment: comment, depth: 2);

      expect(node.comment.id, comment.id);
      expect(node.depth, 2);
      expect(node.replies, isEmpty);
    });

    test('stores child replies', () {
      final parent = Comment(
        id: validId('parent'),
        content: 'Parent',
        authorPubkey: validId('user1'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );
      final child = Comment(
        id: validId('child'),
        content: 'Child',
        authorPubkey: validId('user2'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );

      final childNode = CommentNode(comment: child, depth: 1);
      final parentNode = CommentNode(comment: parent, replies: [childNode]);

      expect(parentNode.replies.length, 1);
      expect(parentNode.replies.first.comment.id, child.id);
    });
  });

  group('engagementScore', () {
    // Helper to create valid hex IDs (64 hex characters)
    String validId(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    test('returns zero for comment with no engagement', () {
      final comment = Comment(
        id: validId('test'),
        content: 'Test',
        authorPubkey: validId('user'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );
      final now = DateTime.now();

      final score = CommentsBloc.engagementScore(
        comment: comment,
        now: now,
        likeCounts: {},
        replyCounts: {},
      );

      expect(score, equals(0.0));
    });

    test('weights replies more than likes', () {
      final comment = Comment(
        id: validId('test'),
        content: 'Test',
        authorPubkey: validId('user'),
        createdAt: DateTime.now(),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );
      final now = DateTime.now();

      final likesOnlyScore = CommentsBloc.engagementScore(
        comment: comment,
        now: now,
        likeCounts: {comment.id: 2},
        replyCounts: {},
      );

      final repliesOnlyScore = CommentsBloc.engagementScore(
        comment: comment,
        now: now,
        likeCounts: {},
        replyCounts: {comment.id: 1},
      );

      // 1 reply (weight 2) == 2 likes (weight 1 each)
      // So repliesOnlyScore with 1 reply = likesOnlyScore with 2 likes
      expect(repliesOnlyScore, equals(likesOnlyScore));
    });

    test('older comments score lower due to time decay', () {
      final now = DateTime.now();
      final recentComment = Comment(
        id: validId('recent'),
        content: 'Recent',
        authorPubkey: validId('user'),
        createdAt: now.subtract(const Duration(hours: 1)),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );
      final oldComment = Comment(
        id: validId('old'),
        content: 'Old',
        authorPubkey: validId('user'),
        createdAt: now.subtract(const Duration(hours: 48)),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );

      final recentScore = CommentsBloc.engagementScore(
        comment: recentComment,
        now: now,
        likeCounts: {recentComment.id: 10},
        replyCounts: {},
      );
      final oldScore = CommentsBloc.engagementScore(
        comment: oldComment,
        now: now,
        likeCounts: {oldComment.id: 10},
        replyCounts: {},
      );

      expect(recentScore, greaterThan(oldScore));
    });
  });

  group('threadedComments advanced', () {
    // Helper to create valid hex IDs (64 hex characters)
    String validId(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    test('sorts siblings by time within a parent', () {
      final parent = Comment(
        id: validId('parent'),
        content: 'Parent',
        authorPubkey: validId('user1'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );
      final olderReply = Comment(
        id: validId('older'),
        content: 'Older reply',
        authorPubkey: validId('user2'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
        replyToEventId: validId('parent'),
        replyToAuthorPubkey: validId('user1'),
      );
      final newerReply = Comment(
        id: validId('newer'),
        content: 'Newer reply',
        authorPubkey: validId('user3'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(3000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
        replyToEventId: validId('parent'),
        replyToAuthorPubkey: validId('user1'),
      );

      // With oldest sort, replies should be: older, newer
      final state = CommentsState(
        sortMode: CommentsSortMode.oldest,
        commentsById: {
          parent.id: parent,
          olderReply.id: olderReply,
          newerReply.id: newerReply,
        },
      );

      final threaded = state.threadedComments;
      expect(threaded.length, 3);
      expect(threaded[0].comment.id, parent.id);
      expect(threaded[0].depth, 0);
      expect(threaded[1].comment.id, olderReply.id);
      expect(threaded[1].depth, 1);
      expect(threaded[2].comment.id, newerReply.id);
      expect(threaded[2].depth, 1);
    });

    test('threadedComments sorts roots by topEngagement', () {
      final now = DateTime.now();
      final lowEngagement = Comment(
        id: validId('low'),
        content: 'Low engagement root',
        authorPubkey: validId('user1'),
        createdAt: now,
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );
      final highEngagement = Comment(
        id: validId('high'),
        content: 'High engagement root',
        authorPubkey: validId('user2'),
        createdAt: now,
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );

      final state = CommentsState(
        sortMode: CommentsSortMode.topEngagement,
        commentsById: {
          lowEngagement.id: lowEngagement,
          highEngagement.id: highEngagement,
        },
        commentLikeCounts: {lowEngagement.id: 1, highEngagement.id: 20},
        replyCountsByCommentId: {lowEngagement.id: 0, highEngagement.id: 5},
      );

      final threaded = state.threadedComments;
      expect(threaded.length, 2);
      expect(threaded[0].comment.id, highEngagement.id);
      expect(threaded[1].comment.id, lowEngagement.id);
    });

    test('preserves DFS order with mixed depth children', () {
      // Tree: A -> B -> D
      //       A -> C
      // DFS oldest should be: A(0), B(1), D(2), C(1)
      final a = Comment(
        id: validId('a'),
        content: 'A',
        authorPubkey: validId('user1'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
      );
      final b = Comment(
        id: validId('b'),
        content: 'B',
        authorPubkey: validId('user2'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
        replyToEventId: validId('a'),
        replyToAuthorPubkey: validId('user1'),
      );
      final c = Comment(
        id: validId('c'),
        content: 'C',
        authorPubkey: validId('user3'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(3000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
        replyToEventId: validId('a'),
        replyToAuthorPubkey: validId('user1'),
      );
      final d = Comment(
        id: validId('d'),
        content: 'D',
        authorPubkey: validId('user4'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(4000000000),
        rootEventId: validId('root'),
        rootAuthorPubkey: validId('author'),
        replyToEventId: validId('b'),
        replyToAuthorPubkey: validId('user2'),
      );

      final state = CommentsState(
        sortMode: CommentsSortMode.oldest,
        commentsById: {a.id: a, b.id: b, c.id: c, d.id: d},
      );

      final threaded = state.threadedComments;
      expect(threaded.length, 4);
      // DFS: A, B, D (child of B), C
      expect(threaded[0].comment.id, a.id);
      expect(threaded[0].depth, 0);
      expect(threaded[1].comment.id, b.id);
      expect(threaded[1].depth, 1);
      expect(threaded[2].comment.id, d.id);
      expect(threaded[2].depth, 2);
      expect(threaded[3].comment.id, c.id);
      expect(threaded[3].depth, 1);
    });
  });

  group('clearActiveReply preserves state', () {
    test('preserves like counts and sort mode', () {
      final state = CommentsState(
        activeReplyCommentId: 'comment1',
        replyInputText: 'draft',
        sortMode: CommentsSortMode.topEngagement,
        commentLikeCounts: const {'c1': 5},
        likedCommentIds: const {'c1'},
      );

      final updated = state.clearActiveReply();

      expect(updated.activeReplyCommentId, null);
      expect(updated.replyInputText, '');
      expect(updated.sortMode, CommentsSortMode.topEngagement);
      expect(updated.commentLikeCounts, {'c1': 5});
      expect(updated.likedCommentIds, {'c1'});
    });

    test('preserves mainInputText', () {
      const state = CommentsState(
        activeReplyCommentId: 'comment1',
        replyInputText: 'reply draft',
        mainInputText: 'main draft',
      );

      final updated = state.clearActiveReply();

      expect(updated.mainInputText, 'main draft');
      expect(updated.replyInputText, '');
    });
  });
}
