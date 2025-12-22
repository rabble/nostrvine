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

    setUp(() {
      mockUserProfileService = MockUserProfileService();
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
      when(mockUserProfileService.shouldSkipProfileFetch(any)).thenReturn(true);
    });

    Widget buildTestWidget({
      required CommentNode node,
      int depth = 0,
      String? replyingToCommentId,
      Map<String, TextEditingController>? replyControllers,
      bool isPosting = false,
      void Function(String)? onReplyToggle,
      void Function(String)? onReplySubmit,
    }) {
      final rc = replyControllers ?? <String, TextEditingController>{};

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
                replyControllers: rc,
                isPosting: isPosting,
                onReplyToggle: onReplyToggle ?? (_) {},
                onReplySubmit: onReplySubmit ?? (_) {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders comment content', (tester) async {
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

    testWidgets('shows Unknown when profile not cached', (tester) async {
      final comment = CommentBuilder().build();
      final node = CommentNodeBuilder().withComment(comment).build();

      await tester.pumpWidget(buildTestWidget(node: node));
      await tester.pump();

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('shows display name when profile cached', (tester) async {
      final profile = UserProfile(
        pubkey: TestCommentIds.author1Pubkey,
        rawData: const <String, dynamic>{},
        createdAt: DateTime.now(),
        eventId: TestCommentIds.comment1Id,
        displayName: 'Test User',
        name: 'testuser',
      );
      when(
        mockUserProfileService.getCachedProfile(TestCommentIds.author1Pubkey),
      ).thenReturn(profile);

      final comment = CommentBuilder()
          .withAuthorPubkey(TestCommentIds.author1Pubkey)
          .build();
      final node = CommentNodeBuilder().withComment(comment).build();

      await tester.pumpWidget(buildTestWidget(node: node));
      await tester.pump();

      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('renders at different depth levels', (tester) async {
      final comment = CommentBuilder().build();
      final node = CommentNodeBuilder().withComment(comment).build();

      await tester.pumpWidget(buildTestWidget(node: node, depth: 0));
      await tester.pump();
      expect(find.byType(CommentThread), findsOneWidget);

      await tester.pumpWidget(buildTestWidget(node: node, depth: 2));
      await tester.pump();
      expect(find.byType(CommentThread), findsOneWidget);
    });

    testWidgets('shows Reply button', (tester) async {
      final comment = CommentBuilder().build();
      final node = CommentNodeBuilder().withComment(comment).build();

      await tester.pumpWidget(buildTestWidget(node: node));
      await tester.pump();

      expect(find.text('Reply'), findsOneWidget);
    });

    testWidgets('shows Cancel when replying', (tester) async {
      final replyControllers = {
        TestCommentIds.comment1Id: TextEditingController(),
      };

      final comment = CommentBuilder()
          .withId(TestCommentIds.comment1Id)
          .build();
      final node = CommentNodeBuilder().withComment(comment).build();

      await tester.pumpWidget(
        buildTestWidget(
          node: node,
          replyingToCommentId: TestCommentIds.comment1Id,
          replyControllers: replyControllers,
        ),
      );
      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Reply'), findsNothing);

      replyControllers.values.forEach((c) => c.dispose());
    });

    testWidgets('calls onReplyToggle when Reply tapped', (tester) async {
      var toggledId = '';
      final comment = CommentBuilder()
          .withId(TestCommentIds.comment1Id)
          .build();
      final node = CommentNodeBuilder().withComment(comment).build();

      await tester.pumpWidget(
        buildTestWidget(node: node, onReplyToggle: (id) => toggledId = id),
      );
      await tester.pump();

      await tester.tap(find.text('Reply'));
      await tester.pump();

      expect(toggledId, equals(TestCommentIds.comment1Id));
    });

    testWidgets('shows CommentsReplyInput when replying', (tester) async {
      final replyControllers = {
        TestCommentIds.comment1Id: TextEditingController(),
      };

      final comment = CommentBuilder()
          .withId(TestCommentIds.comment1Id)
          .build();
      final node = CommentNodeBuilder().withComment(comment).build();

      await tester.pumpWidget(
        buildTestWidget(
          node: node,
          replyingToCommentId: TestCommentIds.comment1Id,
          replyControllers: replyControllers,
        ),
      );
      await tester.pump();

      expect(find.byType(CommentsReplyInput), findsOneWidget);

      replyControllers.values.forEach((c) => c.dispose());
    });

    testWidgets('renders nested replies', (tester) async {
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

      expect(find.text('Parent comment'), findsOneWidget);
      expect(find.text('Reply comment'), findsOneWidget);
    });

    testWidgets('renders deeply nested thread', (tester) async {
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

      expect(find.text('Top level'), findsOneWidget);
      expect(find.text('Level 1 reply'), findsOneWidget);
      expect(find.text('Level 2 reply'), findsOneWidget);
      expect(find.byType(CommentThread), findsNWidgets(3));
    });

    testWidgets('renders UserAvatar', (tester) async {
      final comment = CommentBuilder().build();
      final node = CommentNodeBuilder().withComment(comment).build();

      await tester.pumpWidget(buildTestWidget(node: node));
      await tester.pump();

      expect(find.byType(UserAvatar), findsOneWidget);
    });
  });
}
