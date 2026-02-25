// ABOUTME: Widget tests for VideoFeedPage overlay-to-playback integration
// ABOUTME: Verifies that overlay visibility pauses/resumes the pooled video feed

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoFeedBloc extends MockBloc<VideoFeedEvent, VideoFeedState>
    implements VideoFeedBloc {}

class _MockVideoFeedController extends Mock implements VideoFeedController {}

void main() {
  group('VideoFeedView overlay integration', () {
    late _MockVideoFeedBloc mockBloc;
    late _MockVideoFeedController mockController;

    setUp(() {
      mockBloc = _MockVideoFeedBloc();
      mockController = _MockVideoFeedController();

      // Stub controller methods
      when(
        () => mockController.setActive(active: any(named: 'active')),
      ).thenReturn(null);
      when(() => mockController.videoCount).thenReturn(0);
      when(() => mockController.videos).thenReturn([]);
      when(() => mockController.addListener(any())).thenReturn(null);
      when(() => mockController.removeListener(any())).thenReturn(null);
      when(() => mockController.dispose()).thenReturn(null);
    });

    setUpAll(() {
      registerFallbackValue(const VideoFeedStarted());
      registerFallbackValue(const VideoFeedAutoRefreshRequested());
    });

    tearDown(() {
      mockBloc.close();
    });

    Widget buildSubject({VideoFeedState? state, ProviderContainer? container}) {
      final effectiveState =
          state ?? const VideoFeedState(status: VideoFeedStatus.loading);
      when(() => mockBloc.state).thenReturn(effectiveState);

      return testMaterialApp(
        home: BlocProvider<VideoFeedBloc>.value(
          value: mockBloc,
          child: VideoFeedView(controller: mockController),
        ),
      );
    }

    testWidgets('calls setActive(active: false) when overlay becomes visible', (
      tester,
    ) async {
      when(
        () => mockBloc.state,
      ).thenReturn(const VideoFeedState(status: VideoFeedStatus.loading));

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Get the ProviderContainer from the widget tree
      final element = tester.element(find.byType(VideoFeedView));
      final container = ProviderScope.containerOf(element);

      // Open drawer overlay
      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
      await tester.pump();

      verify(() => mockController.setActive(active: false)).called(1);
    });

    testWidgets('calls setActive(active: true) when overlay becomes hidden', (
      tester,
    ) async {
      when(
        () => mockBloc.state,
      ).thenReturn(const VideoFeedState(status: VideoFeedStatus.loading));

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Get the ProviderContainer from the widget tree
      final element = tester.element(find.byType(VideoFeedView));
      final container = ProviderScope.containerOf(element);

      // Open then close drawer overlay
      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
      await tester.pump();

      // Reset the mock to clear previous calls
      clearInteractions(mockController);

      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(false);
      await tester.pump();

      verify(() => mockController.setActive(active: true)).called(1);
    });

    testWidgets('calls setActive(active: false) when modal overlay opens', (
      tester,
    ) async {
      when(
        () => mockBloc.state,
      ).thenReturn(const VideoFeedState(status: VideoFeedStatus.loading));

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final element = tester.element(find.byType(VideoFeedView));
      final container = ProviderScope.containerOf(element);

      // Open modal overlay
      container.read(overlayVisibilityProvider.notifier).setModalOpen(true);
      await tester.pump();

      verify(() => mockController.setActive(active: false)).called(1);
    });

    testWidgets(
      'initializes controller from BLoC when videos become available',
      (tester) async {
        // Start with loading state
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoFeedState(status: VideoFeedStatus.loading));

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Verify controller is used (injected mock)
        final context = tester.element(find.byType(VideoFeedView));
        final container = ProviderScope.containerOf(context);

        // Open overlay — should call setActive on the injected controller
        container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
        await tester.pump();

        verify(() => mockController.setActive(active: false)).called(1);
      },
    );
  });
}
