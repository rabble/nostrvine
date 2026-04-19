// ABOUTME: Tests for CommentActionButton widget.
// ABOUTME: Verifies rendering in preview mode and normal mode with
// ABOUTME: VideoInteractionsBloc.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/actions/comment_action_button.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

void main() {
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  late VideoEvent testVideo;

  setUp(() {
    testVideo = VideoEvent(
      id: 'test-video-0123456789abcdef0123456789abcdef0123456789abcdef0123',
      pubkey: testPubkey,
      createdAt: 1757385263,
      content: 'Test video',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      originalComments: 7,
    );
  });

  Widget buildSubject({
    required VideoEvent video,
    bool isPreviewMode = false,
    VideoInteractionsBloc? bloc,
    VoidCallback? onInteracted,
  }) {
    final widget = ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CommentActionButton(
            video: video,
            isPreviewMode: isPreviewMode,
            onInteracted: onInteracted,
          ),
        ),
      ),
    );

    if (bloc != null) {
      return BlocProvider<VideoInteractionsBloc>.value(
        value: bloc,
        child: widget,
      );
    }

    return widget;
  }

  group(CommentActionButton, () {
    group('preview mode', () {
      testWidgets(
        'renders without VideoInteractionsBloc when isPreviewMode is true',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(video: testVideo, isPreviewMode: true),
          );

          expect(find.byType(CommentActionButton), findsOneWidget);
          expect(find.byType(VideoActionButton), findsOneWidget);
        },
      );

      testWidgets('displays default comment count of 1 in preview mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(video: testVideo, isPreviewMode: true),
        );

        expect(find.text('1'), findsOneWidget);
      });

      testWidgets('has correct semantics label in preview mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(video: testVideo, isPreviewMode: true),
        );

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics && w.properties.identifier == 'comments_button',
          ),
        );
        expect(semantics.properties.label, equals('View comments'));
      });
    });

    group('normal mode with bloc', () {
      late _MockVideoInteractionsBloc mockBloc;

      setUp(() {
        mockBloc = _MockVideoInteractionsBloc();
        when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
      });

      testWidgets(
        'renders with VideoInteractionsBloc when isPreviewMode is false',
        (tester) async {
          when(
            () => mockBloc.state,
          ).thenReturn(const VideoInteractionsState(commentCount: 3));

          await tester.pumpWidget(
            buildSubject(video: testVideo, bloc: mockBloc),
          );

          expect(find.byType(CommentActionButton), findsOneWidget);
          expect(find.byType(VideoActionButton), findsOneWidget);
        },
      );

      testWidgets('displays commentCount from bloc state', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoInteractionsState(commentCount: 25));

        await tester.pumpWidget(
          buildSubject(video: testVideo, bloc: mockBloc),
        );

        expect(find.text('25'), findsOneWidget);
      });

      testWidgets(
        'falls back to video.originalComments when commentCount is null',
        (tester) async {
          when(
            () => mockBloc.state,
          ).thenReturn(const VideoInteractionsState());

          await tester.pumpWidget(
            buildSubject(video: testVideo, bloc: mockBloc),
          );

          expect(find.text('7'), findsOneWidget);
        },
      );

      testWidgets('shows 0 count as empty when both sources are 0', (
        tester,
      ) async {
        final videoNoComments = VideoEvent(
          id: 'test-video-0123456789abcdef0123456789abcdef0123456789abcdef0123',
          pubkey: testPubkey,
          createdAt: 1757385263,
          content: 'Test video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
          originalComments: 0,
        );

        when(
          () => mockBloc.state,
        ).thenReturn(const VideoInteractionsState());

        await tester.pumpWidget(
          buildSubject(video: videoNoComments, bloc: mockBloc),
        );

        expect(find.text('0'), findsNothing);
      });

      testWidgets('shows loading indicator when isCommentsInProgress is true', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoInteractionsState(isCommentsInProgress: true),
        );

        await tester.pumpWidget(
          buildSubject(video: testVideo, bloc: mockBloc),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('calls onInteracted before opening comments', (
        tester,
      ) async {
        var interacted = false;
        when(() => mockBloc.state).thenReturn(const VideoInteractionsState());

        await tester.pumpWidget(
          buildSubject(
            video: testVideo,
            bloc: mockBloc,
            onInteracted: () => interacted = true,
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(interacted, isTrue);
        expect(tester.takeException(), isNotNull);
      });
    });
  });
}
