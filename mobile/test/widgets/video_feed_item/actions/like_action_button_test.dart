// ABOUTME: Tests for LikeActionButton widget.
// ABOUTME: Verifies rendering in preview mode without VideoInteractionsBloc.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/widgets/video_feed_item/actions/like_action_button.dart';
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
      originalLikes: 42,
    );
  });

  Widget buildSubject({
    required VideoEvent video,
    bool isPreviewMode = false,
    VideoInteractionsBloc? bloc,
  }) {
    final widget = MaterialApp(
      home: Scaffold(
        body: LikeActionButton(video: video, isPreviewMode: isPreviewMode),
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

  group(LikeActionButton, () {
    group('preview mode', () {
      testWidgets(
        'renders without VideoInteractionsBloc when isPreviewMode is true',
        (tester) async {
          // This test ensures the widget can render in preview mode
          // WITHOUT a VideoInteractionsBloc in the widget tree.
          // This is critical for the video metadata preview screen.
          await tester.pumpWidget(
            buildSubject(video: testVideo, isPreviewMode: true),
          );

          // Should render successfully without throwing ProviderNotFoundError
          expect(find.byType(LikeActionButton), findsOneWidget);
          expect(find.byType(VideoActionButton), findsOneWidget);
        },
      );

      testWidgets('displays default like count of 1 in preview mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(video: testVideo, isPreviewMode: true),
        );

        // The default _ActionButton shows totalLikes = 1
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
            (w) => w is Semantics && w.properties.identifier == 'like_button',
          ),
        );
        expect(semantics.properties.label, equals('Like video'));
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
          ).thenReturn(const VideoInteractionsState(likeCount: 10));

          await tester.pumpWidget(
            buildSubject(video: testVideo, bloc: mockBloc),
          );

          expect(find.byType(LikeActionButton), findsOneWidget);
          expect(find.byType(VideoActionButton), findsOneWidget);
        },
      );

      testWidgets(
        'displays state.likeCount when loaded, not video.totalLikes',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const VideoInteractionsState(
              status: VideoInteractionsStatus.success,
              likeCount: 50,
            ),
          );

          await tester.pumpWidget(
            buildSubject(video: testVideo, bloc: mockBloc),
          );

          expect(find.text('50'), findsOneWidget);
          expect(find.text('42'), findsNothing);
        },
      );

      testWidgets(
        'hides like count when nostrLikeCount is null and before BLoC has loaded',
        (tester) async {
          when(() => mockBloc.state).thenReturn(const VideoInteractionsState());

          await tester.pumpWidget(
            buildSubject(video: testVideo, bloc: mockBloc),
          );

          expect(find.text('42'), findsNothing);
          expect(find.byType(VideoActionButton), findsOneWidget);
        },
      );

      testWidgets('hides count when both sources are 0', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 0,
          ),
        );

        await tester.pumpWidget(buildSubject(video: testVideo, bloc: mockBloc));

        expect(find.text('0'), findsNothing);
      });
    });
  });
}
