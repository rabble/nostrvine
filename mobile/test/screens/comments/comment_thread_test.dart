// ABOUTME: Widget tests for CommentThread component
// ABOUTME: Tests comment rendering, nesting, reply toggle, and profile integration

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/comments_provider.dart';
import 'package:openvine/screens/comments/widgets/comment_thread.dart';
import 'package:openvine/screens/comments/widgets/comments_reply_input.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../builders/comment_builder.dart';
import '../../builders/comment_node_builder.dart';

@GenerateMocks([UserProfileService])
import 'comment_thread_test.mocks.dart';

void main() {
  group('CommentThread', () {
    late MockUserProfileService mockUserProfileService;
    late Map<String, TextEditingController> replyControllers;

    setUp(() {
      mockUserProfileService = MockUserProfileService();
      replyControllers = {};

      // Default mock behavior
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
      when(mockUserProfileService.shouldSkipProfileFetch(any)).thenReturn(true);
    });

    tearDown(() {
      for (final controller in replyControllers.values) {
        controller.dispose();
      }
    });

    Widget buildTestWidget({
      required CommentNode node,
      int depth = 0,
      String? replyingToCommentId,
      bool isPosting = false,
      void Function(String)? onReplyToggle,
      void Function(String)? onReplySubmit,
    }) {
      // Create reply controller if replying
      if (replyingToCommentId != null) {
        replyControllers[replyingToCommentId] ??= TextEditingController();
      }

      return ProviderScope(
        overrides: [
          userProfileServiceProvider.overrideWithValue(mockUserProfileService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommentThread(
                node: node,
                depth: depth,
                replyingToCommentId: replyingToCommentId,
                replyControllers: replyControllers,
                isPosting: isPosting,
                onReplyToggle: onReplyToggle ?? (_) {},
                onReplySubmit: onReplySubmit ?? (_) {},
              ),
            ),
          ),
        ),
      );
    }

    group('basic rendering', () {
      testWidgets('renders comment content correctly', (tester) async {
        final comment = CommentBuilder()
            .withContent('This is a test comment')
            .build();
        final node = CommentNodeBuilder().withComment(comment).build();

        await tester.pumpWidget(buildTestWidget(node: node));
        await tester.pump();

        expect(find.text('This is a test comment'), findsOneWidget);
      });

      testWidgets('renders relative time', (tester) async {
        final comment = CommentBuilder()
            .postedAgo(const Duration(hours: 2))
            .build();
        final node = CommentNodeBuilder().withComment(comment).build();

        await tester.pumpWidget(buildTestWidget(node: node));
        await tester.pump();

        expect(find.text('2h ago'), findsOneWidget);
      });

      testWidgets('shows "Unknown" when profile not cached', (tester) async {
        when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);

        final comment = CommentBuilder().build();
        final node = CommentNodeBuilder().withComment(comment).build();

        await tester.pumpWidget(buildTestWidget(node: node));
        await tester.pump();

        expect(find.text('Unknown'), findsOneWidget);
      });

      testWidgets('shows user display name when profile is cached', (tester) async {
        final profile = UserProfile(
          pubkey: TestCommentIds.author1Pubkey,
          rawData: const <String, dynamic>{},
          createdAt: DateTime.now(),
          eventId: TestCommentIds.comment1Id,
          displayName: 'Test User',
          name: 'testuser',
        );
        when(mockUserProfileService.getCachedProfile(TestCommentIds.author1Pubkey))
            .thenReturn(profile);

        final comment = CommentBuilder()
            .withAuthorPubkey(TestCommentIds.author1Pubkey)
            .build();
        final node = CommentNodeBuilder().withComment(comment).build();

        await tester.pumpWidget(buildTestWidget(node: node));
        await tester.pump();

        expect(find.text('Test User'), findsOneWidget);
      });
    });

    group('indentation', () {
      testWidgets('renders at different depth levels', (tester) async {
        final comment = CommentBuilder().build();
        final node = CommentNodeBuilder().withComment(comment).build();

        // Just verify it renders without error at various depths
        await tester.pumpWidget(buildTestWidget(node: node, depth: 0));
        await tester.pump();
        expect(find.byType(CommentThread), findsOneWidget);

        await tester.pumpWidget(buildTestWidget(node: node, depth: 2));
        await tester.pump();
        expect(find.byType(CommentThread), findsOneWidget);
      });
    });

    group('reply button', () {
      testWidgets('shows "Reply" button', (tester) async {
        final comment = CommentBuilder().build();
        final node = CommentNodeBuilder().withComment(comment).build();

        await tester.pumpWidget(buildTestWidget(node: node));
        await tester.pump();

        expect(find.text('Reply'), findsOneWidget);
      });

      testWidgets('shows "Cancel" when replying to this comment', (tester) async {
        final comment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .build();
        final node = CommentNodeBuilder().withComment(comment).build();

        await tester.pumpWidget(buildTestWidget(
          node: node,
          replyingToCommentId: TestCommentIds.comment1Id,
        ));
        await tester.pump();

        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Reply'), findsNothing);
      });

      testWidgets('calls onReplyToggle when Reply is tapped', (tester) async {
        var toggledCommentId = '';
        final comment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .build();
        final node = CommentNodeBuilder().withComment(comment).build();

        await tester.pumpWidget(buildTestWidget(
          node: node,
          onReplyToggle: (id) => toggledCommentId = id,
        ));
        await tester.pump();

        await tester.tap(find.text('Reply'));
        await tester.pump();

        expect(toggledCommentId, equals(TestCommentIds.comment1Id));
      });
    });

    group('reply input', () {
      testWidgets('shows CommentsReplyInput when replying', (tester) async {
        final comment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .build();
        final node = CommentNodeBuilder().withComment(comment).build();

        await tester.pumpWidget(buildTestWidget(
          node: node,
          replyingToCommentId: TestCommentIds.comment1Id,
        ));
        await tester.pump();

        expect(find.byType(CommentsReplyInput), findsOneWidget);
      });

      testWidgets('does not show reply input for different comment', (tester) async {
        final comment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .build();
        final node = CommentNodeBuilder().withComment(comment).build();

        await tester.pumpWidget(buildTestWidget(
          node: node,
          replyingToCommentId: TestCommentIds.comment2Id, // Different ID
        ));
        await tester.pump();

        expect(find.byType(CommentsReplyInput), findsNothing);
      });
    });

    group('nested replies', () {
      testWidgets('renders nested replies recursively', (tester) async {
        final parentComment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withContent('Parent comment')
            .build();

        final replyComment = CommentBuilder()
            .withId(TestCommentIds.comment2Id)
            .withContent('Reply comment')
            .asReplyTo(
              parentEventId: TestCommentIds.comment1Id,
              parentAuthorPubkey: TestCommentIds.author1Pubkey,
            )
            .build();

        final replyNode = CommentNodeBuilder().withComment(replyComment).build();
        final parentNode = CommentNodeBuilder()
            .withComment(parentComment)
            .withReplies([replyNode])
            .build();

        await tester.pumpWidget(buildTestWidget(node: parentNode));
        await tester.pump();

        // Both comments should be visible
        expect(find.text('Parent comment'), findsOneWidget);
        expect(find.text('Reply comment'), findsOneWidget);
      });

      testWidgets('deeply nested replies are indented correctly', (tester) async {
        // Create a 3-level deep thread
        final level2Reply = CommentNodeBuilder()
            .withComment(
              CommentBuilder()
                  .withId(TestCommentIds.comment3Id)
                  .withContent('Level 2 reply')
                  .build(),
            )
            .build();

        final level1Reply = CommentNodeBuilder()
            .withComment(
              CommentBuilder()
                  .withId(TestCommentIds.comment2Id)
                  .withContent('Level 1 reply')
                  .build(),
            )
            .withReplies([level2Reply])
            .build();

        final topLevel = CommentNodeBuilder()
            .withComment(
              CommentBuilder()
                  .withId(TestCommentIds.comment1Id)
                  .withContent('Top level')
                  .build(),
            )
            .withReplies([level1Reply])
            .build();

        await tester.pumpWidget(buildTestWidget(node: topLevel));
        await tester.pump();

        // All three levels should be visible
        expect(find.text('Top level'), findsOneWidget);
        expect(find.text('Level 1 reply'), findsOneWidget);
        expect(find.text('Level 2 reply'), findsOneWidget);

        // Each level should have a CommentThread
        expect(find.byType(CommentThread), findsNWidgets(3));
      });
    });

    group('user avatar', () {
      testWidgets('renders UserAvatar widget', (tester) async {
        final comment = CommentBuilder().build();
        final node = CommentNodeBuilder().withComment(comment).build();

        await tester.pumpWidget(buildTestWidget(node: node));
        await tester.pump();

        expect(find.byType(UserAvatar), findsOneWidget);
      });
    });
  });
}
