// ABOUTME: Widget tests for CommentsScreen main container
// ABOUTME: Tests full comment screen integration, posting, and reply management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/comments/comment_context_provider.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/screens/comments/widgets/comment_input.dart';
import 'package:openvine/screens/comments/widgets/comments_drag_handle.dart';
import 'package:openvine/screens/comments/widgets/comments_header.dart';
import 'package:openvine/screens/comments/widgets/comments_list.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/state/comment_input_state.dart';
import 'package:openvine/state/comments_state.dart';

import '../../builders/comment_builder.dart';
import '../../builders/comment_node_builder.dart';
import '../../helpers/test_helpers.dart';

@GenerateMocks([SocialService, UserProfileService])
import 'comments_screen_test.mocks.dart';

// Full 64-character test IDs
const testVideoEventId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const testVideoAuthorPubkey =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';

void main() {
  group('CommentsScreen', () {
    late MockSocialService mockSocialService;
    late MockUserProfileService mockUserProfileService;
    late ScrollController scrollController;
    late VideoEvent testVideoEvent;

    setUp(() {
      mockSocialService = MockSocialService();
      mockUserProfileService = MockUserProfileService();
      scrollController = ScrollController();

      testVideoEvent = TestHelpers.createVideoEvent(
        id: testVideoEventId,
        pubkey: testVideoAuthorPubkey,
      );

      // Default mock behavior
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
      when(mockUserProfileService.shouldSkipProfileFetch(any)).thenReturn(true);
      when(
        mockSocialService.fetchCommentsForEvent(any),
      ).thenAnswer((_) => const Stream.empty());
    });

    tearDown(() {
      scrollController.dispose();
    });

    Widget buildTestWidget({
      CommentsState? commentsState,
      CommentInputState? inputState,
      VideoEvent? videoEvent,
    }) {
      final state =
          commentsState ??
          CommentsState(rootEventId: testVideoEventId, topLevelComments: []);
      final input = inputState ?? CommentInputState.initial;
      final ctx = (eventId: testVideoEventId, pubkey: testVideoAuthorPubkey);

      return ProviderScope(
        overrides: [
          socialServiceProvider.overrideWithValue(mockSocialService),
          userProfileServiceProvider.overrideWithValue(mockUserProfileService),
          commentContextProvider.overrideWithValue(ctx),
          currentCommentsProvider.overrideWith((ref) => state),
          currentCommentInputProvider.overrideWith(
            () => _MockCurrentCommentInput(input),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CommentsScreen(
              videoEvent: videoEvent ?? testVideoEvent,
              sheetScrollController: scrollController,
            ),
          ),
        ),
      );
    }

    group('widget structure', () {
      testWidgets('renders CommentsDragHandle', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(CommentsDragHandle), findsOneWidget);
      });

      testWidgets('renders CommentsHeader', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(CommentsHeader), findsOneWidget);
        expect(find.text('Comments'), findsOneWidget);
      });

      testWidgets('renders CommentsList', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(CommentsList), findsOneWidget);
      });

      testWidgets('renders CommentInput', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(CommentInput), findsOneWidget);
      });

      testWidgets('renders Divider between header and list', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(Divider), findsOneWidget);
      });
    });

    group('comment input', () {
      testWidgets('has "Add a comment..." hint text', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.text('Add a comment...'), findsOneWidget);
      });

      testWidgets('allows text entry', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        await tester.enterText(find.byType(TextField).first, 'Test comment');
        await tester.pump();

        expect(find.text('Test comment'), findsOneWidget);
      });
    });

    group('reply toggling', () {
      testWidgets('tapping Reply shows reply input', (tester) async {
        final comments = [
          CommentNodeBuilder()
              .withComment(
                CommentBuilder()
                    .withId(TestCommentIds.comment1Id)
                    .withContent('Test comment')
                    .build(),
              )
              .build(),
        ];

        final state = CommentsState(
          rootEventId: testVideoEventId,
          topLevelComments: comments,
          totalCommentCount: 1,
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        // Find and tap Reply button
        await tester.tap(find.text('Reply'));
        await tester.pump();

        // Should now show Cancel and reply input
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Write a reply...'), findsOneWidget);
      });

      testWidgets('tapping Cancel hides reply input', (tester) async {
        final comments = [
          CommentNodeBuilder()
              .withComment(
                CommentBuilder()
                    .withId(TestCommentIds.comment1Id)
                    .withContent('Test comment')
                    .build(),
              )
              .build(),
        ];

        final state = CommentsState(
          rootEventId: testVideoEventId,
          topLevelComments: comments,
          totalCommentCount: 1,
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        // Tap Reply to show reply input
        await tester.tap(find.text('Reply'));
        await tester.pump();

        // Tap Cancel to hide it
        await tester.tap(find.text('Cancel'));
        await tester.pump();

        // Should show Reply again
        expect(find.text('Reply'), findsOneWidget);
        expect(find.text('Cancel'), findsNothing);
        expect(find.text('Write a reply...'), findsNothing);
      });
    });

    group('loading states', () {
      testWidgets('shows loading indicator in list when loading', (
        tester,
      ) async {
        final state = CommentsState(
          rootEventId: testVideoEventId,
          isLoading: true,
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows empty state when no comments', (tester) async {
        final state = CommentsState(
          rootEventId: testVideoEventId,
          topLevelComments: [],
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        expect(
          find.text('No comments yet.\nBe the first to comment!'),
          findsOneWidget,
        );
      });
    });

    group('error handling', () {
      testWidgets('renders without error when input state has no error', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        // Should render normally without error
        expect(find.byType(CommentsScreen), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      });
    });

    group('show modal', () {
      testWidgets('CommentsScreen.show opens modal bottom sheet', (
        tester,
      ) async {
        final state = CommentsState(
          rootEventId: testVideoEventId,
          topLevelComments: [],
        );
        final ctx = (eventId: testVideoEventId, pubkey: testVideoAuthorPubkey);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              socialServiceProvider.overrideWithValue(mockSocialService),
              userProfileServiceProvider.overrideWithValue(
                mockUserProfileService,
              ),
              commentContextProvider.overrideWithValue(ctx),
              currentCommentsProvider.overrideWith((ref) => state),
              currentCommentInputProvider.overrideWith(
                () => _MockCurrentCommentInput(CommentInputState.initial),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () =>
                        CommentsScreen.show(context, testVideoEvent),
                    child: const Text('Open Comments'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap button to open modal
        await tester.tap(find.text('Open Comments'));
        await tester.pumpAndSettle();

        // Verify CommentsScreen is shown in modal
        expect(find.byType(CommentsScreen), findsOneWidget);
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
        expect(find.text('Comments'), findsOneWidget);
      });
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
