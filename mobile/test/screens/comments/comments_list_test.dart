// ABOUTME: Widget tests for CommentsList component
// ABOUTME: Tests loading, error, empty, and data state rendering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/comments_provider.dart';
import 'package:openvine/screens/comments/widgets/comment_thread.dart';
import 'package:openvine/screens/comments/widgets/comments_empty_state.dart';
import 'package:openvine/screens/comments/widgets/comments_list.dart';
import 'package:openvine/services/user_profile_service.dart';

import '../../builders/comment_builder.dart';
import '../../builders/comment_node_builder.dart';

@GenerateMocks([UserProfileService])
import 'comments_list_test.mocks.dart';

// Full 64-character test IDs
const testVideoEventId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const testVideoAuthorPubkey =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';

void main() {
  group('CommentsList', () {
    late MockUserProfileService mockUserProfileService;
    late ScrollController scrollController;
    late Map<String, TextEditingController> replyControllers;

    setUp(() {
      mockUserProfileService = MockUserProfileService();
      scrollController = ScrollController();
      replyControllers = {};

      // Default mock behavior
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
      when(mockUserProfileService.shouldSkipProfileFetch(any)).thenReturn(true);
    });

    tearDown(() {
      scrollController.dispose();
      for (final controller in replyControllers.values) {
        controller.dispose();
      }
    });

    Widget buildTestWidget({
      required CommentsState commentsState,
      bool isOriginalVine = false,
      String? replyingToCommentId,
      bool isPosting = false,
    }) => ProviderScope(
      overrides: [
        userProfileServiceProvider.overrideWithValue(mockUserProfileService),
        commentsProvider(
          testVideoEventId,
          testVideoAuthorPubkey,
        ).overrideWith(() => _MockCommentsNotifier(commentsState)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CommentsList(
            videoEventId: testVideoEventId,
            videoEventPubkey: testVideoAuthorPubkey,
            isOriginalVine: isOriginalVine,
            scrollController: scrollController,
            replyingToCommentId: replyingToCommentId,
            replyControllers: replyControllers,
            isPosting: isPosting,
            onReplyToggle: (_) {},
            onReplySubmit: (_) {},
          ),
        ),
      ),
    );

    group('loading state', () {
      testWidgets('shows loading indicator when loading', (tester) async {
        final state = CommentsState(
          rootEventId: testVideoEventId,
          isLoading: true,
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('error state', () {
      testWidgets('shows error message when state has error', (tester) async {
        final state = CommentsState(
          rootEventId: testVideoEventId,
          error: 'Network error occurred',
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        expect(find.textContaining('Network error occurred'), findsOneWidget);
      });
    });

    group('empty state', () {
      testWidgets('shows CommentsEmptyState when no comments', (tester) async {
        final state = CommentsState(
          rootEventId: testVideoEventId,
          topLevelComments: [],
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        expect(find.byType(CommentsEmptyState), findsOneWidget);
      });

      testWidgets('passes isClassicVine to CommentsEmptyState', (tester) async {
        final state = CommentsState(
          rootEventId: testVideoEventId,
          topLevelComments: [],
        );

        await tester.pumpWidget(
          buildTestWidget(commentsState: state, isOriginalVine: true),
        );
        await tester.pump();

        // When isOriginalVine is true, the Classic Vine notice should appear
        expect(find.text('Classic Vine'), findsOneWidget);
      });

      testWidgets(
        'does not show Classic Vine notice when isOriginalVine is false',
        (tester) async {
          final state = CommentsState(
            rootEventId: testVideoEventId,
            topLevelComments: [],
          );

          await tester.pumpWidget(
            buildTestWidget(commentsState: state, isOriginalVine: false),
          );
          await tester.pump();

          expect(find.text('Classic Vine'), findsNothing);
        },
      );
    });

    group('data state', () {
      testWidgets('renders ListView when comments exist', (tester) async {
        final comments = CommentTreeBuilder.singleComment(
          content: 'Test comment',
        );
        final state = CommentsState(
          rootEventId: testVideoEventId,
          topLevelComments: comments,
          totalCommentCount: 1,
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('renders CommentThread for each top-level comment', (
        tester,
      ) async {
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
          topLevelComments: [comment1, comment2],
          totalCommentCount: 2,
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        expect(find.byType(CommentThread), findsNWidgets(2));
        expect(find.text('First comment'), findsOneWidget);
        expect(find.text('Second comment'), findsOneWidget);
      });

      testWidgets('passes replyingToCommentId to CommentThread', (
        tester,
      ) async {
        final comments = CommentTreeBuilder.singleComment(content: 'Test');
        replyControllers[TestCommentIds.comment1Id] = TextEditingController();

        final state = CommentsState(
          rootEventId: testVideoEventId,
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
          totalCommentCount: 1,
        );

        await tester.pumpWidget(
          buildTestWidget(
            commentsState: state,
            replyingToCommentId: TestCommentIds.comment1Id,
          ),
        );
        await tester.pump();

        // Should show "Cancel" instead of "Reply" when replying
        expect(find.text('Cancel'), findsOneWidget);
      });
    });

    group('scroll behavior', () {
      testWidgets('uses provided scroll controller', (tester) async {
        final comments = CommentTreeBuilder.singleComment();
        final state = CommentsState(
          rootEventId: testVideoEventId,
          topLevelComments: comments,
          totalCommentCount: 1,
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.controller, equals(scrollController));
      });
    });
  });
}

/// Mock CommentsNotifier that returns a fixed state
class _MockCommentsNotifier extends CommentsNotifier {
  _MockCommentsNotifier(this._state);
  final CommentsState _state;

  @override
  CommentsState build(String rootEventId, String rootAuthorPubkey) => _state;
}
