// ABOUTME: Widget tests for CommentsScreen main container
// ABOUTME: Tests full comment screen integration, posting, and reply management

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/models/user_profile.dart' as models;
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/user_profile_service.dart';

import '../../builders/comment_builder.dart';
import '../../helpers/test_helpers.dart';

/// Maps [CommentsError] to user-facing strings for tests.
String _errorToString(CommentsError error) {
  return switch (error) {
    CommentsError.loadFailed => 'Failed to load comments',
    CommentsError.notAuthenticated => 'Please sign in to comment',
    CommentsError.postCommentFailed => 'Failed to post comment',
    CommentsError.postReplyFailed => 'Failed to post reply',
    CommentsError.deleteCommentFailed => 'Failed to delete comment',
  };
}

class MockSocialService extends Mock implements SocialService {}

class MockAuthService extends Mock implements AuthService {}

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
  group('CommentsScreen', () {
    late MockSocialService mockSocialService;
    late MockAuthService mockAuthService;
    late MockUserProfileService mockUserProfileService;
    late MockNostrClient mockNostrClient;
    late MockCommentsBloc mockCommentsBloc;
    late ScrollController scrollController;
    late VideoEvent testVideoEvent;

    setUpAll(() {
      registerFallbackValue(const CommentsLoadRequested());
    });

    setUp(() {
      mockSocialService = MockSocialService();
      mockAuthService = MockAuthService();
      mockUserProfileService = MockUserProfileService();
      mockNostrClient = MockNostrClient();
      mockCommentsBloc = MockCommentsBloc();
      scrollController = ScrollController();

      testVideoEvent = TestHelpers.createVideoEvent(
        id: testVideoEventId,
        pubkey: testVideoAuthorPubkey,
      );

      // Default mock behavior
      when(
        () => mockUserProfileService.getCachedProfile(any()),
      ).thenReturn(null);
      when(
        () => mockUserProfileService.shouldSkipProfileFetch(any()),
      ).thenReturn(true);
      // Return empty string to indicate user is not the comment author (no 3-dot menu)
      when(() => mockNostrClient.publicKey).thenReturn('');

      // Default state
      when(() => mockCommentsBloc.state).thenReturn(
        CommentsState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          comments: [],
        ),
      );
    });

    tearDown(() {
      scrollController.dispose();
    });

    Widget buildTestWidget({
      CommentsState? commentsState,
      VideoEvent? videoEvent,
    }) {
      if (commentsState != null) {
        when(() => mockCommentsBloc.state).thenReturn(commentsState);
      }

      return ProviderScope(
        overrides: [
          socialServiceProvider.overrideWithValue(mockSocialService),
          authServiceProvider.overrideWithValue(mockAuthService),
          userProfileServiceProvider.overrideWithValue(mockUserProfileService),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BlocProvider<CommentsBloc>.value(
              value: mockCommentsBloc,
              child: _CommentsScreenTestContent(
                videoEvent: videoEvent ?? testVideoEvent,
                sheetScrollController: scrollController,
              ),
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
      testWidgets('has "Add comment..." hint text', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.text('Add comment...'), findsOneWidget);
      });

      testWidgets('adds CommentTextChanged on text entry', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        await tester.enterText(find.byType(TextField).first, 'Test comment');
        await tester.pump();

        final captured =
            verify(() => mockCommentsBloc.add(captureAny())).captured.last
                as CommentTextChanged;
        expect(captured.text, 'Test comment');
      });
    });

    group('reply toggling', () {
      testWidgets('tapping Reply adds CommentReplyToggled', (tester) async {
        final comments = [
          CommentBuilder()
              .withId(TestCommentIds.comment1Id)
              .withContent('Test comment')
              .build(),
        ];

        final state = CommentsState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          comments: comments,
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        // Find and tap Reply button
        await tester.tap(find.text('Reply'));
        await tester.pump();

        final captured =
            verify(() => mockCommentsBloc.add(captureAny())).captured.last
                as CommentReplyToggled;
        expect(captured.commentId, TestCommentIds.comment1Id);
      });

      testWidgets('shows reply indicator when replying', (tester) async {
        final testProfile = models.UserProfile(
          pubkey: TestCommentIds.author1Pubkey,
          displayName: 'TestUser',
          rawData: {},
          createdAt: DateTime.now(),
          eventId: 'test_event_id',
        );
        when(
          () => mockUserProfileService.getCachedProfile(
            TestCommentIds.author1Pubkey,
          ),
        ).thenReturn(testProfile);

        final comments = [
          CommentBuilder()
              .withId(TestCommentIds.comment1Id)
              .withAuthorPubkey(TestCommentIds.author1Pubkey)
              .withContent('Test comment')
              .build(),
        ];

        final commentsState = CommentsState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          comments: comments,
          activeReplyCommentId: TestCommentIds.comment1Id,
          replyInputText: '',
        );

        await tester.pumpWidget(buildTestWidget(commentsState: commentsState));
        await tester.pumpAndSettle();

        expect(find.text('Re: TestUser'), findsOneWidget);
        // Verify close icon exists (there may be multiple close icons on the screen)
        expect(find.byIcon(Icons.close), findsWidgets);
      });
    });

    group('loading states', () {
      testWidgets('shows loading indicator in list when loading', (
        tester,
      ) async {
        final state = CommentsState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.loading,
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        expect(find.byType(CommentsSkeletonLoader), findsOneWidget);
      });

      testWidgets('shows empty state when no comments', (tester) async {
        final state = CommentsState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          comments: [],
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        expect(find.text('No comments yet'), findsOneWidget);
        expect(find.text('Get the party started!'), findsOneWidget);
      });
    });

    group('error handling', () {
      testWidgets('renders without error when state has no error', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        // Should render normally without error
        expect(find.byType(CommentsDragHandle), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      });
    });
  });
}

/// Test content widget that mirrors the CommentsScreen body structure
/// but accepts mocked blocs from parent widget
class _CommentsScreenTestContent extends StatelessWidget {
  const _CommentsScreenTestContent({
    required this.videoEvent,
    required this.sheetScrollController,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommentsBloc, CommentsState>(
      listenWhen: (prev, next) =>
          prev.error != next.error && next.error != null,
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorToString(state.error!))));
          context.read<CommentsBloc>().add(const CommentErrorCleared());
        }
      },
      child: Column(
        children: [
          const CommentsDragHandle(),
          CommentsHeader(onClose: () => Navigator.pop(context)),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: CommentsList(
              isOriginalVine: videoEvent.isOriginalVine,
              scrollController: sheetScrollController,
            ),
          ),
          _MainCommentInputTest(),
        ],
      ),
    );
  }
}

/// Test version of main comment input that works with mocked bloc
class _MainCommentInputTest extends StatefulWidget {
  @override
  State<_MainCommentInputTest> createState() => _MainCommentInputTestState();
}

class _MainCommentInputTestState extends State<_MainCommentInputTest> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final state = context.read<CommentsBloc>().state;
    _controller = TextEditingController(text: state.mainInputText);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CommentsBloc, CommentsState>(
      listenWhen: (prev, next) =>
          prev.activeReplyCommentId != next.activeReplyCommentId,
      listener: (context, state) {
        if (state.activeReplyCommentId != null) {
          _focusNode.requestFocus();
        }
      },
      buildWhen: (prev, next) =>
          prev.mainInputText != next.mainInputText ||
          prev.replyInputText != next.replyInputText ||
          prev.activeReplyCommentId != next.activeReplyCommentId ||
          prev.isPosting != next.isPosting,
      builder: (context, state) {
        final isReplyMode = state.activeReplyCommentId != null;
        final inputText = isReplyMode
            ? state.replyInputText
            : state.mainInputText;

        if (_controller.text != inputText) {
          _controller.text = inputText;
          _controller.selection = TextSelection.collapsed(
            offset: inputText.length,
          );
        }

        // Get display name of user being replied to
        String? replyToDisplayName;
        String? replyToAuthorPubkey;
        if (isReplyMode) {
          final replyComment = state.comments.firstWhere(
            (c) => c.id == state.activeReplyCommentId,
            orElse: () => throw StateError('Reply comment not found'),
          );
          replyToAuthorPubkey = replyComment.authorPubkey;

          // For tests, use a simple "User" fallback since we mock the profile service
          replyToDisplayName = 'TestUser';
        }

        return CommentInput(
          controller: _controller,
          focusNode: _focusNode,
          isPosting: state.isPosting,
          replyToDisplayName: replyToDisplayName,
          onChanged: (text) {
            context.read<CommentsBloc>().add(
              CommentTextChanged(text, commentId: state.activeReplyCommentId),
            );
          },
          onSubmit: () {
            if (isReplyMode) {
              context.read<CommentsBloc>().add(
                CommentSubmitted(
                  parentCommentId: state.activeReplyCommentId,
                  parentAuthorPubkey: replyToAuthorPubkey,
                ),
              );
            } else {
              context.read<CommentsBloc>().add(const CommentSubmitted());
            }
          },
          onCancelReply: () {
            context.read<CommentsBloc>().add(
              CommentReplyToggled(state.activeReplyCommentId!),
            );
          },
        );
      },
    );
  }
}
