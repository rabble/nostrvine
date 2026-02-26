// ABOUTME: Widget tests for FeedModeSwitch
// ABOUTME: Tests all feed modes display, tap interactions, and bottom sheet selection

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';

class _MockVideoFeedBloc extends MockBloc<VideoFeedEvent, VideoFeedState>
    implements VideoFeedBloc {}

void main() {
  group('FeedModeSwitch', () {
    late _MockVideoFeedBloc mockBloc;

    setUp(() {
      mockBloc = _MockVideoFeedBloc();
    });

    setUpAll(() {
      registerFallbackValue(const VideoFeedModeChanged(FeedMode.latest));
    });

    tearDown(() {
      mockBloc.close();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              BlocProvider<VideoFeedBloc>.value(
                value: mockBloc,
                child: const FeedModeSwitch(),
              ),
            ],
          ),
        ),
      );
    }

    group('Feed Mode Labels', () {
      testWidgets('displays "New" label for latest mode', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedState(
            status: VideoFeedStatus.success,
            mode: FeedMode.latest,
          ),
        );
        await tester.pumpWidget(createTestWidget());

        expect(find.text('New'), findsOneWidget);
      });

      testWidgets('displays "Popular" label for popular mode', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedState(
            status: VideoFeedStatus.success,
            mode: FeedMode.popular,
          ),
        );
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Popular'), findsOneWidget);
      });

      testWidgets('displays "Following" label for home mode', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedState(
            status: VideoFeedStatus.success,
          ),
        );
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Following'), findsOneWidget);
      });
    });

    group('Tap Interaction', () {
      testWidgets('opens VineBottomSheet on tap', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedState(
            status: VideoFeedStatus.success,
            mode: FeedMode.latest,
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.byType(FeedModeSwitch));
        await tester.pumpAndSettle();

        expect(find.byType(VineBottomSheet), findsOneWidget);
      });

      testWidgets('adds VideoFeedModeChanged when popular selected', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedState(
            status: VideoFeedStatus.success,
            mode: FeedMode.latest,
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.byType(FeedModeSwitch));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Popular'));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const VideoFeedModeChanged(FeedMode.popular)),
        ).called(1);
      });

      testWidgets('dispatches VideoFeedModeChanged when following selected', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedState(
            status: VideoFeedStatus.success,
            mode: FeedMode.latest,
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.byType(FeedModeSwitch));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Following'));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const VideoFeedModeChanged(FeedMode.home)),
        ).called(1);
      });

      testWidgets('dispatches VideoFeedModeChanged when new selected', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedState(
            status: VideoFeedStatus.success,
            mode: FeedMode.popular,
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.byType(FeedModeSwitch));
        await tester.pumpAndSettle();

        await tester.tap(find.text('New'));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const VideoFeedModeChanged(FeedMode.latest)),
        ).called(1);
      });

      testWidgets('does not dispatch event when bottom sheet dismissed', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedState(
            status: VideoFeedStatus.success,
            mode: FeedMode.latest,
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.byType(FeedModeSwitch));
        await tester.pumpAndSettle();

        // Dismiss by tapping outside (on the barrier)
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        verifyNever(() => mockBloc.add(any()));
      });
    });

    testWidgets('label gets updated when mode changes', (tester) async {
      whenListen(
        mockBloc,
        Stream.fromIterable([
          const VideoFeedState(
            status: VideoFeedStatus.success,
            mode: FeedMode.popular,
          ),
        ]),
        initialState: const VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.latest,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Popular'), findsOneWidget);
    });
  });
}
