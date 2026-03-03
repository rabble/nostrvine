// ABOUTME: Widget tests for VideoFeedPage overlay-to-playback integration
// ABOUTME: Verifies that overlay visibility and tab switches pause/resume the
// ABOUTME: pooled video feed

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoFeedBloc extends MockBloc<VideoFeedEvent, VideoFeedState>
    implements VideoFeedBloc {}

class _MockVideoFeedController extends Mock implements VideoFeedController {}

void main() {
  group('VideoFeedView overlay integration', () {
    late VideoFeedBloc videoFeedBloc;
    late VideoFeedController videoFeedController;

    setUp(() {
      videoFeedBloc = _MockVideoFeedBloc();
      videoFeedController = _MockVideoFeedController();

      when(
        () => videoFeedController.setActive(active: any(named: 'active')),
      ).thenReturn(null);
      when(() => videoFeedController.videoCount).thenReturn(0);
      when(() => videoFeedController.videos).thenReturn([]);
      when(() => videoFeedController.addListener(any())).thenReturn(null);
      when(() => videoFeedController.removeListener(any())).thenReturn(null);
      when(() => videoFeedController.dispose()).thenReturn(null);
    });

    setUpAll(() {
      registerFallbackValue(const VideoFeedStarted());
      registerFallbackValue(const VideoFeedAutoRefreshRequested());
    });

    Widget buildSubject({
      VideoFeedState? state,
      List<dynamic>? additionalOverrides,
    }) {
      when(
        () => videoFeedBloc.state,
      ).thenReturn(state ?? const VideoFeedState());

      return testMaterialApp(
        additionalOverrides: additionalOverrides,
        home: BlocProvider<VideoFeedBloc>.value(
          value: videoFeedBloc,
          child: VideoFeedView(controller: videoFeedController),
        ),
      );
    }

    testWidgets('calls setActive(active: false) when overlay becomes visible', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final element = tester.element(find.byType(VideoFeedView));
      final container = ProviderScope.containerOf(element);

      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
      await tester.pump();

      verify(() => videoFeedController.setActive(active: false)).called(1);
    });

    testWidgets('calls setActive(active: false) when modal overlay opens', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final element = tester.element(find.byType(VideoFeedView));
      final container = ProviderScope.containerOf(element);

      container.read(overlayVisibilityProvider.notifier).setModalOpen(true);
      await tester.pump();

      verify(() => videoFeedController.setActive(active: false)).called(1);
    });

    testWidgets('calls setActive(active: true) when overlay becomes hidden', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final element = tester.element(find.byType(VideoFeedView));
      final container = ProviderScope.containerOf(element);

      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
      await tester.pump();

      // Reset the mock to clear previous calls
      clearInteractions(videoFeedController);

      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(false);
      await tester.pump();

      verify(() => videoFeedController.setActive(active: true)).called(1);
    });
  });

  group('VideoFeedView tab switch integration', () {
    late VideoFeedBloc videoFeedBloc;
    late VideoFeedController videoFeedController;
    late StreamController<String> locationController;

    setUp(() {
      videoFeedBloc = _MockVideoFeedBloc();
      videoFeedController = _MockVideoFeedController();
      locationController = StreamController<String>();

      when(
        () => videoFeedController.setActive(active: any(named: 'active')),
      ).thenReturn(null);
      when(() => videoFeedController.videoCount).thenReturn(0);
      when(() => videoFeedController.videos).thenReturn([]);
      when(() => videoFeedController.addListener(any())).thenReturn(null);
      when(() => videoFeedController.removeListener(any())).thenReturn(null);
      when(() => videoFeedController.dispose()).thenReturn(null);
    });

    tearDown(() {
      locationController.close();
    });

    setUpAll(() {
      registerFallbackValue(const VideoFeedStarted());
      registerFallbackValue(const VideoFeedAutoRefreshRequested());
    });

    Widget buildSubject() {
      when(
        () => videoFeedBloc.state,
      ).thenReturn(const VideoFeedState());

      return testMaterialApp(
        additionalOverrides: [
          routerLocationStreamProvider.overrideWith(
            (ref) => locationController.stream,
          ),
        ],
        home: BlocProvider<VideoFeedBloc>.value(
          value: videoFeedBloc,
          child: VideoFeedView(controller: videoFeedController),
        ),
      );
    }

    testWidgets(
      'calls setActive(active: false) when navigating away from home',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Start on home tab
        locationController.add('/home/0');
        await tester.pump();

        clearInteractions(videoFeedController);

        // Navigate to search tab
        locationController.add('/search');
        await tester.pump();

        verify(
          () => videoFeedController.setActive(active: false),
        ).called(1);
      },
    );

    testWidgets(
      'calls setActive(active: true) when returning to home',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Start on home, navigate away
        locationController.add('/home/0');
        await tester.pump();
        locationController.add('/search');
        await tester.pump();

        clearInteractions(videoFeedController);

        // Return to home
        locationController.add('/home/0');
        await tester.pump();

        verify(
          () => videoFeedController.setActive(active: true),
        ).called(1);
      },
    );

    testWidgets(
      'does not resume when overlay closes while on non-home tab',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final element = tester.element(find.byType(VideoFeedView));
        final container = ProviderScope.containerOf(element);

        // Start on home, navigate away
        locationController.add('/home/0');
        await tester.pump();
        locationController.add('/search');
        await tester.pump();

        clearInteractions(videoFeedController);

        // Open and close overlay while on search tab
        container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
        await tester.pump();
        container.read(overlayVisibilityProvider.notifier).setDrawerOpen(false);
        await tester.pump();

        // setActive(active: true) should NOT have been called
        verifyNever(
          () => videoFeedController.setActive(active: true),
        );
      },
    );
  });
}
