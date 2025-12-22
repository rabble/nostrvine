// ABOUTME: Widget tests for CommentsScreen main container
// ABOUTME: Tests full comment screen integration, posting, and reply management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/comments_provider.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/screens/comments/widgets/comment_input.dart';
import 'package:openvine/screens/comments/widgets/comments_drag_handle.dart';
import 'package:openvine/screens/comments/widgets/comments_header.dart';
import 'package:openvine/screens/comments/widgets/comments_list.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/user_profile_service.dart';

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
      VideoEvent? videoEvent,
    }) {
      final state =
          commentsState ??
          CommentsState(rootEventId: testVideoEventId, topLevelComments: []);

      return ProviderScope(
        overrides: [
          socialServiceProvider.overrideWithValue(mockSocialService),
          userProfileServiceProvider.overrideWithValue(mockUserProfileService),
          commentsProvider(
            testVideoEventId,
            testVideoAuthorPubkey,
          ).overrideWith(() => _MockCommentsNotifier(state)),
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

    group('posting comments', () {
      testWidgets('calls SocialService.postComment when sending', (
        tester,
      ) async {
        when(
          mockSocialService.postComment(
            content: anyNamed('content'),
            rootEventId: anyNamed('rootEventId'),
            rootEventAuthorPubkey: anyNamed('rootEventAuthorPubkey'),
            replyToEventId: anyNamed('replyToEventId'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        // Enter text and tap send
        await tester.enterText(find.byType(TextField).first, 'Test comment');
        await tester.pump();

        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        verify(
          mockSocialService.postComment(
            content: 'Test comment',
            rootEventId: testVideoEventId,
            rootEventAuthorPubkey: testVideoAuthorPubkey,
            replyToEventId: null,
          ),
        ).called(1);
      });

      testWidgets('clears input after successful post', (tester) async {
        when(
          mockSocialService.postComment(
            content: anyNamed('content'),
            rootEventId: anyNamed('rootEventId'),
            rootEventAuthorPubkey: anyNamed('rootEventAuthorPubkey'),
            replyToEventId: anyNamed('replyToEventId'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        await tester.enterText(find.byType(TextField).first, 'Test comment');
        await tester.pump();

        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Input should be cleared
        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(textField.controller?.text, isEmpty);
      });

      testWidgets('does not post empty comment', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        // Don't enter any text, just tap send
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        verifyNever(
          mockSocialService.postComment(
            content: anyNamed('content'),
            rootEventId: anyNamed('rootEventId'),
            rootEventAuthorPubkey: anyNamed('rootEventAuthorPubkey'),
            replyToEventId: anyNamed('replyToEventId'),
          ),
        );
      });

      testWidgets('does not post whitespace-only comment', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        await tester.enterText(find.byType(TextField).first, '   ');
        await tester.pump();

        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        verifyNever(
          mockSocialService.postComment(
            content: anyNamed('content'),
            rootEventId: anyNamed('rootEventId'),
            rootEventAuthorPubkey: anyNamed('rootEventAuthorPubkey'),
            replyToEventId: anyNamed('replyToEventId'),
          ),
        );
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

    group('error handling', () {
      testWidgets('shows snackbar on post error', (tester) async {
        when(
          mockSocialService.postComment(
            content: anyNamed('content'),
            rootEventId: anyNamed('rootEventId'),
            rootEventAuthorPubkey: anyNamed('rootEventAuthorPubkey'),
            replyToEventId: anyNamed('replyToEventId'),
          ),
        ).thenThrow(Exception('Network error'));

        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        await tester.enterText(find.byType(TextField).first, 'Test comment');
        await tester.pump();

        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Should show error snackbar
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('Failed to post comment'), findsOneWidget);
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

    group('show modal', () {
      testWidgets('CommentsScreen.show opens modal bottom sheet', (
        tester,
      ) async {
        final state = CommentsState(
          rootEventId: testVideoEventId,
          topLevelComments: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              socialServiceProvider.overrideWithValue(mockSocialService),
              userProfileServiceProvider.overrideWithValue(
                mockUserProfileService,
              ),
              commentsProvider(
                testVideoEventId,
                testVideoAuthorPubkey,
              ).overrideWith(() => _MockCommentsNotifier(state)),
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

/// Mock CommentsNotifier that returns a fixed state
class _MockCommentsNotifier extends CommentsNotifier {
  _MockCommentsNotifier(this._state);
  final CommentsState _state;

  @override
  CommentsState build(String rootEventId, String rootAuthorPubkey) => _state;
}
