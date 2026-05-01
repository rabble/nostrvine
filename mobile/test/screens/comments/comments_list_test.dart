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
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/comments/comments.dart';

import '../../builders/comment_builder.dart';

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
    late MockNostrClient mockNostrClient;
    late MockCommentsBloc mockCommentsBloc;

    setUpAll(() {
      registerFallbackValue(const CommentsLoadRequested());
    });

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockCommentsBloc = MockCommentsBloc();

      // Return empty string to indicate user is not the comment author (no 3-dot menu)
      when(() => mockNostrClient.publicKey).thenReturn('');
    });

    Widget buildTestWidget({
      required CommentsState commentsState,
      bool showClassicVineNotice = false,
      ScrollController? scrollController,
    }) {
      final sc = scrollController ?? ScrollController();

      when(() => mockCommentsBloc.state).thenReturn(commentsState);

      return ProviderScope(
        overrides: [nostrServiceProvider.overrideWithValue(mockNostrClient)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<CommentsBloc>.value(
              value: mockCommentsBloc,
              child: CommentsList(
                showClassicVineNotice: showClassicVineNotice,
                scrollController: sc,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows skeleton loader when loading', (tester) async {
      const state = CommentsState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.loading,
      );

      await tester.pumpWidget(buildTestWidget(commentsState: state));
      await tester.pump();

      expect(find.byType(CommentsSkeletonLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows error message when state has error', (tester) async {
      const state = CommentsState(
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
      const state = CommentsState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
      );

      await tester.pumpWidget(buildTestWidget(commentsState: state));
      await tester.pump();

      expect(find.byType(CommentsEmptyState), findsOneWidget);
    });

    testWidgets('shows Classic Vine notice when requested', (tester) async {
      const state = CommentsState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
      );

      await tester.pumpWidget(
        buildTestWidget(commentsState: state, showClassicVineNotice: true),
      );
      await tester.pump();

      expect(find.text('Classic Vine'), findsOneWidget);
    });

    testWidgets('renders CommentThread for each comment', (tester) async {
      final comment1 = CommentBuilder()
          .withId(TestCommentIds.comment1Id)
          .withContent('First comment')
          .build();

      final comment2 = CommentBuilder()
          .withId(TestCommentIds.comment2Id)
          .withContent('Second comment')
          .build();

      final state = CommentsState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
        commentsById: {comment1.id: comment1, comment2.id: comment2},
      );

      await tester.pumpWidget(buildTestWidget(commentsState: state));
      await tester.pump();

      expect(find.byType(CommentItem), findsNWidgets(2));
      expect(find.text('First comment'), findsOneWidget);
      expect(find.text('Second comment'), findsOneWidget);
    });

    testWidgets('uses provided scroll controller', (tester) async {
      final scrollController = ScrollController();
      final comment = CommentBuilder().build();
      final state = CommentsState(
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
        status: CommentsStatus.success,
        commentsById: {comment.id: comment},
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

    testWidgets(
      'tap on a comment dismisses the keyboard (TikTok / Reels parity)',
      (tester) async {
        // When the comment input is focused and the user taps a comment in
        // the list, the keyboard should dismiss so the user can read other
        // comments unobstructed. Draft text in the input is retained
        // (verified by the input retaining its FocusNode and controller
        // separately — this test covers the focus-drop side).
        final comment = CommentBuilder()
            .withId(TestCommentIds.comment1Id)
            .withContent('First comment')
            .build();

        final state = CommentsState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {comment.id: comment},
        );

        when(() => mockCommentsBloc.state).thenReturn(state);

        final focusNode = FocusNode();
        final textController = TextEditingController(text: 'draft comment');
        final scrollController = ScrollController();
        addTearDown(focusNode.dispose);
        addTearDown(textController.dispose);
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nostrServiceProvider.overrideWithValue(mockNostrClient),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: BlocProvider<CommentsBloc>.value(
                  value: mockCommentsBloc,
                  // A focused TextField mimics the production scenario:
                  // CommentInput has the keyboard up while CommentsList
                  // is visible. The Column layout matches the bottom
                  // sheet's scrollable-body / bottom-input split.
                  child: Column(
                    children: [
                      Expanded(
                        child: CommentsList(
                          showClassicVineNotice: false,
                          scrollController: scrollController,
                        ),
                      ),
                      TextField(
                        focusNode: focusNode,
                        controller: textController,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        focusNode.requestFocus();
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);

        await tester.tap(find.text('First comment'));
        await tester.pump();

        expect(
          focusNode.hasFocus,
          isFalse,
          reason:
              'Tapping a comment in the list must dismiss the keyboard '
              'so the user can read other comments without being '
              'blocked. Matches TikTok / Instagram Reels behavior.',
        );
        expect(
          textController.text,
          equals('draft comment'),
          reason:
              'Dismissing the keyboard by tapping the list must not clear '
              'the draft text.',
        );
      },
    );

    testWidgets(
      'ListView declares onDrag keyboard-dismiss behavior',
      (tester) async {
        // Idiomatic Flutter signal: the comments scroll view dismisses
        // the keyboard when the user starts dragging it. Complements the
        // tap-dismiss above for the scroll-to-read case.
        final comment = CommentBuilder().build();
        final state = CommentsState(
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
          status: CommentsStatus.success,
          commentsById: {comment.id: comment},
        );

        await tester.pumpWidget(buildTestWidget(commentsState: state));
        await tester.pump();

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(
          listView.keyboardDismissBehavior,
          ScrollViewKeyboardDismissBehavior.onDrag,
        );
      },
    );
  });
}
