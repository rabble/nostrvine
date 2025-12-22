// ABOUTME: Widget tests for CommentsList component
// ABOUTME: Tests loading, error, empty, and data state rendering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/comments/comment_context_provider.dart';
import 'package:openvine/screens/comments/widgets/comment_thread.dart';
import 'package:openvine/state/comments_state.dart';
import 'package:openvine/screens/comments/widgets/comments_empty_state.dart';
import 'package:openvine/screens/comments/widgets/comments_list.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/state/comment_input_state.dart';

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
      CommentInputState? inputState,
      bool isOriginalVine = false,
      ScrollController? scrollController,
    }) {
      final sc = scrollController ?? ScrollController();
      final input = inputState ?? CommentInputState.initial;
      final ctx = (eventId: testVideoEventId, pubkey: testVideoAuthorPubkey);

      return ProviderScope(
        overrides: [
          userProfileServiceProvider.overrideWithValue(mockUserProfileService),
          commentContextProvider.overrideWithValue(ctx),
          currentCommentsProvider.overrideWith((ref) => commentsState),
          currentCommentInputProvider.overrideWith(
            () => _MockCurrentCommentInput(input),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CommentsList(
              isOriginalVine: isOriginalVine,
              scrollController: sc,
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

      final inputState = CommentInputState(
        activeReplyCommentId: TestCommentIds.comment1Id,
        replyInputTexts: {TestCommentIds.comment1Id: ''},
      );

      await tester.pumpWidget(
        buildTestWidget(commentsState: state, inputState: inputState),
      );
      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);
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

/// Mock CurrentCommentInput that manages state for testing
class _MockCurrentCommentInput extends CurrentCommentInput {
  _MockCurrentCommentInput(this._initialState);

  final CommentInputState _initialState;

  @override
  CommentInputState build() => _initialState;

  @override
  void toggleReply(String commentId) {
    if (state.activeReplyCommentId == commentId) {
      state = state.copyWith(activeReplyCommentId: null);
    } else {
      final updatedReplies = Map<String, String>.from(state.replyInputTexts);
      updatedReplies.putIfAbsent(commentId, () => '');
      state = state.copyWith(
        activeReplyCommentId: commentId,
        replyInputTexts: updatedReplies,
      );
    }
  }

  @override
  void updateMainText(String text) {
    state = state.copyWith(mainInputText: text, error: null);
  }

  @override
  void updateReplyText(String commentId, String text) {
    final updatedReplies = Map<String, String>.from(state.replyInputTexts);
    updatedReplies[commentId] = text;
    state = state.copyWith(replyInputTexts: updatedReplies, error: null);
  }

  @override
  Future<void> postMainComment() async {}

  @override
  Future<void> postReply(
    String parentCommentId,
    String? parentAuthorPubkey,
  ) async {}

  @override
  void clearError() {
    state = state.copyWith(error: null);
  }
}
