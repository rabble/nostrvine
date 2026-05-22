// ABOUTME: Widget tests for CommentsScreen with the split three-bloc topology.
// ABOUTME: Mocks CommentsListBloc + CommentComposerBloc + CommentReactionsBloc
// ABOUTME: via MultiBlocProvider and exercises a content widget that mirrors
// ABOUTME: the production screen.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/social_service.dart';

import '../../builders/comment_builder.dart';
import '../../helpers/test_helpers.dart';

class MockSocialService extends Mock implements SocialService {}

class MockAuthService extends Mock implements AuthService {}

class MockNostrClient extends Mock implements NostrClient {}

class MockCommentsListBloc
    extends MockBloc<CommentsListEvent, CommentsListState>
    implements CommentsListBloc {}

class MockCommentComposerBloc
    extends MockBloc<CommentComposerEvent, CommentComposerState>
    implements CommentComposerBloc {}

class MockCommentReactionsBloc
    extends MockBloc<CommentReactionsEvent, CommentReactionsState>
    implements CommentReactionsBloc {}

// Full 64-character test IDs.
const testVideoEventId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const testVideoAuthorPubkey =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';

void main() {
  group('CommentsScreen', () {
    late MockSocialService mockSocialService;
    late MockAuthService mockAuthService;
    late MockNostrClient mockNostrClient;
    late MockCommentsListBloc mockListBloc;
    late MockCommentComposerBloc mockComposerBloc;
    late MockCommentReactionsBloc mockReactionsBloc;
    late ScrollController scrollController;
    late VideoEvent testVideoEvent;

    setUpAll(() {
      registerFallbackValue(const CommentsLoadRequested());
      registerFallbackValue(const CommentReplyToggled(''));
    });

    setUp(() {
      mockSocialService = MockSocialService();
      mockAuthService = MockAuthService();
      mockNostrClient = MockNostrClient();
      mockListBloc = MockCommentsListBloc();
      mockComposerBloc = MockCommentComposerBloc();
      mockReactionsBloc = MockCommentReactionsBloc();
      scrollController = ScrollController();

      testVideoEvent = TestHelpers.createVideoEvent(
        id: testVideoEventId,
        pubkey: testVideoAuthorPubkey,
      );

      when(() => mockNostrClient.publicKey).thenReturn('');

      when(() => mockListBloc.state).thenReturn(
        const CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
        ),
      );
      when(() => mockComposerBloc.state).thenReturn(
        const CommentComposerState(),
      );
      when(() => mockReactionsBloc.state).thenReturn(
        const CommentReactionsState(),
      );
    });

    tearDown(() {
      scrollController.dispose();
    });

    Widget buildTestWidget({
      CommentsListState? listState,
      CommentComposerState? composerState,
      VideoEvent? videoEvent,
      int? initialCommentCount,
    }) {
      if (listState != null) {
        when(() => mockListBloc.state).thenReturn(listState);
      }
      if (composerState != null) {
        when(() => mockComposerBloc.state).thenReturn(composerState);
      }

      return ProviderScope(
        overrides: [
          socialServiceProvider.overrideWithValue(mockSocialService),
          authServiceProvider.overrideWithValue(mockAuthService),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<CommentsListBloc>.value(value: mockListBloc),
                BlocProvider<CommentComposerBloc>.value(
                  value: mockComposerBloc,
                ),
                BlocProvider<CommentReactionsBloc>.value(
                  value: mockReactionsBloc,
                ),
              ],
              child: _CommentsScreenTestContent(
                videoEvent: videoEvent ?? testVideoEvent,
                sheetScrollController: scrollController,
                initialCommentCount: initialCommentCount ?? 0,
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
            verify(() => mockComposerBloc.add(captureAny())).captured.last
                as CommentTextChanged;
        expect(captured.text, 'Test comment');
      });
    });

    group('reply toggling', () {
      testWidgets('tapping Reply adds CommentReplyToggled to composer', (
        tester,
      ) async {
        final comment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withContent('Test comment')
            .build();

        final state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {comment.id: comment},
        );

        await tester.pumpWidget(buildTestWidget(listState: state));
        await tester.pump();

        await tester.tap(find.text('Reply'));
        await tester.pump();

        final captured =
            verify(() => mockComposerBloc.add(captureAny())).captured.last
                as CommentReplyToggled;
        expect(captured.commentId, TestCommentIds.comment1Id);
      });

      testWidgets('shows reply indicator when replying', (tester) async {
        final comment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withAuthorPubkey(TestCommentIds.author1Pubkey)
            .withContent('Test comment')
            .build();

        final listState = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {comment.id: comment},
        );
        const composerState = CommentComposerState(
          activeReplyCommentId: TestCommentIds.comment1Id,
        );

        await tester.pumpWidget(
          buildTestWidget(listState: listState, composerState: composerState),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text('${l10n.commentReplyToPrefix} TestUser'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.close), findsWidgets);
      });
    });

    group('title count', () {
      testWidgets('shows initial count during loading', (tester) async {
        const state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.loading,
        );

        await tester.pumpWidget(
          buildTestWidget(listState: state, initialCommentCount: 5),
        );
        await tester.pump();

        expect(find.text('5 Comments'), findsOneWidget);
      });

      testWidgets('shows loaded count after success', (tester) async {
        final c1 = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withContent('Comment 1')
            .build();
        final c2 = CommentBuilder()
            .withId(TestCommentIds.comment2Id)
            .withContent('Comment 2')
            .build();

        final state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {c1.id: c1, c2.id: c2},
        );

        await tester.pumpWidget(
          buildTestWidget(listState: state, initialCommentCount: 5),
        );
        await tester.pump();

        expect(find.text('2 Comments'), findsOneWidget);
      });

      testWidgets('shows singular "Comment" for count of 1', (tester) async {
        const state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.loading,
        );

        await tester.pumpWidget(
          buildTestWidget(listState: state, initialCommentCount: 1),
        );
        await tester.pump();

        expect(find.text('1 Comment'), findsOneWidget);
      });
    });

    group('threaded comments', () {
      testWidgets('renders nested reply with indentation', (tester) async {
        final parent = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withAuthorPubkey(TestCommentIds.author1Pubkey)
            .withContent('Parent comment')
            .build();
        final reply = CommentBuilder()
            .withId(TestCommentIds.comment2Id)
            .withAuthorPubkey(TestCommentIds.author2Pubkey)
            .withContent('Reply comment')
            .asReplyTo(
              parentEventId: TestCommentIds.comment1Id,
              parentAuthorPubkey: TestCommentIds.author1Pubkey,
            )
            .build();

        final state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {parent.id: parent, reply.id: reply},
        );

        await tester.pumpWidget(buildTestWidget(listState: state));
        await tester.pump();

        expect(find.text('Parent comment'), findsOneWidget);
        expect(find.text('Reply comment'), findsOneWidget);
        expect(find.byType(CommentItem), findsNWidgets(2));
      });
    });

    group('loading states', () {
      testWidgets('shows loading indicator in list when loading', (
        tester,
      ) async {
        const state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.loading,
        );

        await tester.pumpWidget(buildTestWidget(listState: state));
        await tester.pump();

        expect(find.byType(CommentsSkeletonLoader), findsOneWidget);
      });

      testWidgets('shows empty state when no comments', (tester) async {
        const state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
        );

        await tester.pumpWidget(buildTestWidget(listState: state));
        await tester.pump();

        expect(find.text('No comments yet'), findsOneWidget);
        expect(find.text('Get the party started!'), findsOneWidget);
      });

      testWidgets(
        'does not show archive notice for recent videos with loop stats',
        (tester) async {
          const state = CommentsListState(
            rootEventId: testVideoEventId,
            rootAuthorPubkey: testVideoAuthorPubkey,
            status: CommentsStatus.success,
          );

          final recentVideoWithLoops = VideoEvent(
            id: testVideoEventId,
            pubkey: testVideoAuthorPubkey,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            content: 'recent video',
            timestamp: DateTime.now(),
            originalLoops: 13565,
          );

          await tester.pumpWidget(
            buildTestWidget(
              listState: state,
              videoEvent: recentVideoWithLoops,
            ),
          );
          await tester.pump();

          expect(find.text('Classic Vine'), findsNothing);
        },
      );

      testWidgets('shows archive notice for vintage recovered vines', (
        tester,
      ) async {
        const state = CommentsListState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
        );

        final vintageRecoveredVine = VideoEvent(
          id: testVideoEventId,
          pubkey: testVideoAuthorPubkey,
          createdAt: 1473050841,
          content: 'classic vine',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1473050841 * 1000),
          rawTags: const {'platform': 'vine'},
          originalLoops: 3169386,
        );

        await tester.pumpWidget(
          buildTestWidget(
            listState: state,
            videoEvent: vintageRecoveredVine,
          ),
        );
        await tester.pump();

        expect(find.text('Classic Vine'), findsOneWidget);
      });
    });

    group('error handling', () {
      testWidgets('renders without snackbar when no error', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        expect(find.byType(CommentsDragHandle), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      });
    });
  });
}

/// Test content widget that mirrors the CommentsScreen body structure
/// but accepts mocked blocs from parent widget.
class _CommentsScreenTestContent extends StatelessWidget {
  const _CommentsScreenTestContent({
    required this.videoEvent,
    required this.sheetScrollController,
    required this.initialCommentCount,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;
  final int initialCommentCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CommentsDragHandle(),
        _TestCommentsTitle(initialCount: initialCommentCount),
        CommentsHeader(onClose: () => Navigator.pop(context)),
        const Divider(color: Colors.white24, height: 1),
        Expanded(
          child: CommentsList(
            showClassicVineNotice: videoEvent.isVintageRecoveredVine,
            scrollController: sheetScrollController,
          ),
        ),
        _MainCommentInputTest(),
      ],
    );
  }
}

/// Test version of main comment input that reads from the composer bloc.
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
    final state = context.read<CommentComposerBloc>().state;
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
    return BlocConsumer<CommentComposerBloc, CommentComposerState>(
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
          prev.activeReplyCommentId != next.activeReplyCommentId,
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

        String? replyToDisplayName;
        String? replyToAuthorPubkey;
        if (isReplyMode) {
          final listState = context.read<CommentsListBloc>().state;
          final replyComment =
              listState.commentsById[state.activeReplyCommentId];
          if (replyComment != null) {
            replyToAuthorPubkey = replyComment.authorPubkey;
            replyToDisplayName = 'TestUser';
          }
        }

        return CommentInput(
          controller: _controller,
          focusNode: _focusNode,
          replyToDisplayName: replyToDisplayName,
          onChanged: (text) {
            context.read<CommentComposerBloc>().add(
              CommentTextChanged(text, commentId: state.activeReplyCommentId),
            );
          },
          onSubmit: () {
            if (isReplyMode) {
              context.read<CommentComposerBloc>().add(
                CommentSubmitted(
                  parentCommentId: state.activeReplyCommentId,
                  parentAuthorPubkey: replyToAuthorPubkey,
                ),
              );
            } else {
              context.read<CommentComposerBloc>().add(const CommentSubmitted());
            }
          },
          onCancelReply: () {
            context.read<CommentComposerBloc>().add(
              CommentReplyToggled(state.activeReplyCommentId!),
            );
          },
        );
      },
    );
  }
}

/// Test replica of `_CommentsTitle` from comments_screen.dart.
class _TestCommentsTitle extends StatelessWidget {
  const _TestCommentsTitle({required this.initialCount});

  final int initialCount;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsListBloc, CommentsListState>(
      buildWhen: (prev, next) =>
          prev.commentsById.length != next.commentsById.length ||
          prev.status != next.status,
      builder: (context, state) {
        final count = state.status == CommentsStatus.success
            ? state.commentsById.length
            : initialCount;

        return Text('$count ${count == 1 ? 'Comment' : 'Comments'}');
      },
    );
  }
}
