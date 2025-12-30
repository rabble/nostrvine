// ABOUTME: Widget tests for CommentsList component
// ABOUTME: Tests loading, error, empty, and data state rendering

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/services/user_profile_service.dart';

import '../../builders/comment_builder.dart';
import '../../builders/comment_node_builder.dart';

class MockUserProfileService extends Mock implements UserProfileService {}

class MockNostrClient extends Mock implements NostrClient {}

class MockCommentsBloc extends MockBloc<CommentsEvent, CommentsState>
    implements CommentsBloc {}

// Full 64-character test IDs
const testVideoEventId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const testVideoAuthorPubkey =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';

void main() {
  group('CommentsList', () {
    late MockUserProfileService mockUserProfileService;
    late MockNostrClient mockNostrClient;
    late MockCommentsBloc mockCommentsBloc;

    setUpAll(() {
      registerFallbackValue(const CommentsLoadRequested());
    });

    setUp(() {
      mockUserProfileService = MockUserProfileService();
      mockNostrClient = MockNostrClient();
      mockCommentsBloc = MockCommentsBloc();

      when(
        () => mockUserProfileService.getCachedProfile(any()),
      ).thenReturn(null);
      when(
        () => mockUserProfileService.shouldSkipProfileFetch(any()),
      ).thenReturn(true);
      // Return empty string to indicate user is not the comment author (no 3-dot menu)
      when(() => mockNostrClient.publicKey).thenReturn('');
    });

    Widget buildTestWidget({
      required CommentsState commentsState,
      bool isOriginalVine = false,
      ScrollController? scrollController,
    }) {
      final sc = scrollController ?? ScrollController();

      when(() => mockCommentsBloc.state).thenReturn(commentsState);

      return ProviderScope(
        overrides: [
          userProfileServiceProvider.overrideWithValue(mockUserProfileService),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BlocProvider<CommentsBloc>.value(
              value: mockCommentsBloc,
              child: CommentsList(
                isOriginalVine: isOriginalVine,
                scrollController: sc,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows loading indicator when loading', (tester) async {
      final state = CommentsState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.loading,
      );

      await tester.pumpWidget(buildTestWidget(commentsState: state));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when state has error', (tester) async {
      final state = CommentsState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.failure,
        error: CommentsError.loadFailed,
      );

      await tester.pumpWidget(buildTestWidget(commentsState: state));
      await tester.pump();

      expect(find.textContaining('Failed to load comments'), findsOneWidget);
    });

    testWidgets('shows CommentsEmptyState when no comments', (tester) async {
      final state = CommentsState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
        topLevelComments: [],
      );

      await tester.pumpWidget(buildTestWidget(commentsState: state));
      await tester.pump();

      expect(find.byType(CommentsEmptyState), findsOneWidget);
    });

    testWidgets('shows Classic Vine notice when isOriginalVine', (
      tester,
    ) async {
      final state = CommentsState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
        topLevelComments: [],
      );

      await tester.pumpWidget(
        buildTestWidget(commentsState: state, isOriginalVine: true),
      );
      await tester.pump();

      expect(find.text('Classic Vine'), findsOneWidget);
    });

    testWidgets('renders CommentThread for each comment', (tester) async {
      final comment1 = CommentNodeBuilder()
          .withComment(
            CommentBuilder()
                .withId(TestCommentIds.comment1Id)
                .withContent('First comment')
                .build(),
          )
          .build();

      final comment2 = CommentNodeBuilder()
          .withComment(
            CommentBuilder()
                .withId(TestCommentIds.comment2Id)
                .withContent('Second comment')
                .build(),
          )
          .build();

      final state = CommentsState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
        topLevelComments: [comment1, comment2],
      );

      await tester.pumpWidget(buildTestWidget(commentsState: state));
      await tester.pump();

      expect(find.byType(CommentThread), findsNWidgets(2));
      expect(find.text('First comment'), findsOneWidget);
      expect(find.text('Second comment'), findsOneWidget);
    });

    testWidgets('shows Cancel when replying to comment', (tester) async {
      final state = CommentsState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
        topLevelComments: [
          CommentNodeBuilder()
              .withComment(
                CommentBuilder()
                    .withId(TestCommentIds.comment1Id)
                    .withContent('Test')
                    .build(),
              )
              .build(),
        ],
        activeReplyCommentId: TestCommentIds.comment1Id,
        replyInputText: '',
      );

      await tester.pumpWidget(buildTestWidget(commentsState: state));
      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('uses provided scroll controller', (tester) async {
      final scrollController = ScrollController();
      final comments = CommentTreeBuilder.singleComment();
      final state = CommentsState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
        topLevelComments: comments,
      );

      await tester.pumpWidget(
        buildTestWidget(
          commentsState: state,
          scrollController: scrollController,
        ),
      );
      await tester.pump();

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.controller, equals(scrollController));

      scrollController.dispose();
    });
  });
}
