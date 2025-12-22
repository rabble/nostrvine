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

    setUp(() {
      mockUserProfileService = MockUserProfileService();
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
      when(mockUserProfileService.shouldSkipProfileFetch(any)).thenReturn(true);
    });

    Widget buildTestWidget({
      required CommentsState commentsState,
      bool isOriginalVine = false,
      String? replyingToCommentId,
      bool isPosting = false,
      ScrollController? scrollController,
      Map<String, TextEditingController>? replyControllers,
    }) {
      final sc = scrollController ?? ScrollController();
      final rc = replyControllers ?? <String, TextEditingController>{};

      return ProviderScope(
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
              scrollController: sc,
              replyingToCommentId: replyingToCommentId,
              replyControllers: rc,
              isPosting: isPosting,
              onReplyToggle: (_) {},
              onReplySubmit: (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('shows loading indicator when loading', (tester) async {
      final state = CommentsState(
        rootEventId: testVideoEventId,
        isLoading: true,
      );

      await tester.pumpWidget(buildTestWidget(commentsState: state));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when state has error', (tester) async {
      final state = CommentsState(
        rootEventId: testVideoEventId,
        error: 'Network error occurred',
      );

      await tester.pumpWidget(buildTestWidget(commentsState: state));
      await tester.pump();

      expect(find.textContaining('Network error occurred'), findsOneWidget);
    });

    testWidgets('shows CommentsEmptyState when no comments', (tester) async {
      final state = CommentsState(
        rootEventId: testVideoEventId,
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
        topLevelComments: [comment1, comment2],
        totalCommentCount: 2,
      );

      await tester.pumpWidget(buildTestWidget(commentsState: state));
      await tester.pump();

      expect(find.byType(CommentThread), findsNWidgets(2));
      expect(find.text('First comment'), findsOneWidget);
      expect(find.text('Second comment'), findsOneWidget);
    });

    testWidgets('shows Cancel when replying to comment', (tester) async {
      final replyControllers = {
        TestCommentIds.comment1Id: TextEditingController(),
      };

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
          replyControllers: replyControllers,
        ),
      );
      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);

      // Clean up
      replyControllers.values.forEach((c) => c.dispose());
    });

    testWidgets('uses provided scroll controller', (tester) async {
      final scrollController = ScrollController();
      final comments = CommentTreeBuilder.singleComment();
      final state = CommentsState(
        rootEventId: testVideoEventId,
        topLevelComments: comments,
        totalCommentCount: 1,
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

/// Mock CommentsNotifier that returns a fixed state
class _MockCommentsNotifier extends CommentsNotifier {
  _MockCommentsNotifier(this._state);
  final CommentsState _state;

  @override
  CommentsState build(String rootEventId, String rootAuthorPubkey) => _state;
}
