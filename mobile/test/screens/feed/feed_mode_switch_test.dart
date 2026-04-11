// ABOUTME: Widget tests for FeedModeSwitch
// ABOUTME: Tests all feed modes display, tap interactions, and bottom sheet selection

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';

class _MockVideoFeedBloc extends MockBloc<VideoFeedEvent, VideoFeedState>
    implements VideoFeedBloc {}

void main() {
  group(FeedModeSwitch, () {
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

    Widget createTestWidget({bool newSearchEnabled = false}) {
      return ProviderScope(
        overrides: [
          isFeatureEnabledProvider(
            FeatureFlag.newSearch,
          ).overrideWith((ref) => newSearchEnabled),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

      testWidgets('displays "For You" label for the default home mode', (
        tester,
      ) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoFeedState(status: VideoFeedStatus.success));
        await tester.pumpWidget(createTestWidget());

        expect(find.text('For You'), findsOneWidget);
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

        await tester.tap(find.text('New'));
        await tester.pumpAndSettle();

        expect(find.byType(VineBottomSheet), findsOneWidget);
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

        await tester.tap(find.text('New'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Following'));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const VideoFeedModeChanged(FeedMode.following)),
        ).called(1);
      });

      testWidgets('dispatches VideoFeedModeChanged when new selected', (
        tester,
      ) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoFeedState(status: VideoFeedStatus.success));
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text('For You'));
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

        await tester.tap(find.text('New'));
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
          const VideoFeedState(status: VideoFeedStatus.success),
        ]),
        initialState: const VideoFeedState(
          status: VideoFeedStatus.success,
          mode: FeedMode.latest,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('For You'), findsOneWidget);
    });

    group('newSearch feature flag', () {
      testWidgets('hides search button when flag is enabled', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoFeedState(status: VideoFeedStatus.success));
        await tester.pumpWidget(createTestWidget(newSearchEnabled: true));

        expect(find.byType(DiVineAppBarIconButton), findsNothing);
      });

      testWidgets('shows search button when flag is disabled', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoFeedState(status: VideoFeedStatus.success));
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(DiVineAppBarIconButton), findsOneWidget);
      });
    });
  });
}
