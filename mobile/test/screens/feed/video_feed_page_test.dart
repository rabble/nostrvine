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
        () => videoFeedController.setActive(
          active: any(named: 'active'),
          retainCurrentPlayer: any(named: 'retainCurrentPlayer'),
        ),
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

    testWidgets(
      'calls setActive(active: false, retainCurrentPlayer: true) when drawer opens',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final element = tester.element(find.byType(VideoFeedView));
        final container = ProviderScope.containerOf(element);

        container
            .read(overlayVisibilityProvider.notifier)
            .setBottomSheetOpen(true);
        await tester.pump();

        // Drawer overlay retains current player for instant resume
        verify(
          () => videoFeedController.setActive(
            active: false,
            retainCurrentPlayer: true,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'calls setActive(active: false, retainCurrentPlayer: false) when page opens',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final element = tester.element(find.byType(VideoFeedView));
        final container = ProviderScope.containerOf(element);

        // Page overlay releases all players to free memory
        container.read(overlayVisibilityProvider.notifier).setPageOpen(true);
        await tester.pump();

        verify(
          () => videoFeedController.setActive(
            active: false,
            // Specify explicitly to verify the expected behavior, despite
            // being the default value.
            // ignore: avoid_redundant_argument_values
            retainCurrentPlayer: false,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'calls setActive(active: false, retainCurrentPlayer: true) when bottom sheet opens',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final element = tester.element(find.byType(VideoFeedView));
        final container = ProviderScope.containerOf(element);

        // Bottom sheet overlay retains current player for instant resume
        container
            .read(overlayVisibilityProvider.notifier)
            .setBottomSheetOpen(true);
        await tester.pump();

        verify(
          () => videoFeedController.setActive(
            active: false,
            retainCurrentPlayer: true,
          ),
        ).called(1);
      },
    );

    testWidgets('calls setActive(active: true) when overlay becomes hidden', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final element = tester.element(find.byType(VideoFeedView));
      final container = ProviderScope.containerOf(element);

      container
          .read(overlayVisibilityProvider.notifier)
          .setBottomSheetOpen(true);
      await tester.pump();

      // Reset the mock to clear previous calls
      clearInteractions(videoFeedController);

      container
          .read(overlayVisibilityProvider.notifier)
          .setBottomSheetOpen(false);
      await tester.pump();

      verify(() => videoFeedController.setActive(active: true)).called(1);
    });

    testWidgets(
      'does not resume when videos load while overlay is open',
      (tester) async {
        // Start with loading state
        whenListen(
          videoFeedBloc,
          Stream<VideoFeedState>.fromIterable([
            const VideoFeedState(
              status: VideoFeedStatus.success,
            ),
          ]),
          initialState: const VideoFeedState(),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final element = tester.element(find.byType(VideoFeedView));
        final container = ProviderScope.containerOf(element);

        // Open overlay while BLoC is still loading
        container.read(overlayVisibilityProvider.notifier).setPageOpen(true);
        await tester.pump();

        clearInteractions(videoFeedController);

        // BLoC transitions to success (videos arrive)
        await tester.pump();

        // Controller must NOT be re-activated — overlay is still open
        verifyNever(
          () => videoFeedController.setActive(active: true),
        );
      },
    );
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
        () => videoFeedController.setActive(
          active: any(named: 'active'),
          retainCurrentPlayer: any(named: 'retainCurrentPlayer'),
        ),
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

    Widget buildSubjectWithInitialLocation(String location) {
      when(
        () => videoFeedBloc.state,
      ).thenReturn(const VideoFeedState());

      return testMaterialApp(
        additionalOverrides: [
          routerLocationStreamProvider.overrideWith(
            (ref) => Stream.value(location),
          ),
        ],
        home: BlocProvider<VideoFeedBloc>.value(
          value: videoFeedBloc,
          child: VideoFeedView(controller: videoFeedController),
        ),
      );
    }

    testWidgets(
      'syncs controller to a non-home route on initial mount',
      (tester) async {
        await tester.pumpWidget(buildSubjectWithInitialLocation('/search'));
        await tester.pump();

        verify(
          () => videoFeedController.setActive(active: false),
        ).called(1);
      },
    );

    testWidgets(
      'syncs controller to an already-open page overlay on initial mount',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(),
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value('/home/0'),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(overlayVisibilityProvider.notifier).setPageOpen(true);

        when(
          () => videoFeedBloc.state,
        ).thenReturn(const VideoFeedState());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: BlocProvider<VideoFeedBloc>.value(
                value: videoFeedBloc,
                child: VideoFeedView(controller: videoFeedController),
              ),
            ),
          ),
        );
        await tester.pump();

        verify(
          () => videoFeedController.setActive(
            active: false,
            // Verify that initial overlay sync uses the full-release path.
            // ignore: avoid_redundant_argument_values
            retainCurrentPlayer: false,
          ),
        ).called(1);
      },
    );

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
        container
            .read(overlayVisibilityProvider.notifier)
            .setBottomSheetOpen(true);
        await tester.pump();
        container
            .read(overlayVisibilityProvider.notifier)
            .setBottomSheetOpen(false);
        await tester.pump();

        // setActive(active: true) should NOT have been called
        verifyNever(
          () => videoFeedController.setActive(active: true),
        );
      },
    );

    testWidgets(
      'does not resume when router reports home while page overlay is open',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final element = tester.element(find.byType(VideoFeedView));
        final container = ProviderScope.containerOf(element);

        // Start on home
        locationController.add('/home/0');
        await tester.pump();

        // Simulate pushing to video recorder (overlay opens, location
        // changes to /video-recorder)
        container.read(overlayVisibilityProvider.notifier).setPageOpen(true);
        locationController.add('/video-recorder');
        await tester.pump();

        clearInteractions(videoFeedController);

        // GoRouter falsely reports home while recorder is still open
        // (happens when popping from editor back to recorder)
        locationController.add('/home/0');
        await tester.pump();

        // setActive(active: true) must NOT be called — the overlay is
        // still open, so the overlay listener handles resume later.
        verifyNever(
          () => videoFeedController.setActive(active: true),
        );
      },
    );

    testWidgets(
      'resumes playback when overlay closes after false home report',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        final element = tester.element(find.byType(VideoFeedView));
        final container = ProviderScope.containerOf(element);

        // Start on home
        locationController.add('/home/0');
        await tester.pump();

        // Open page overlay (e.g. video recorder)
        container.read(overlayVisibilityProvider.notifier).setPageOpen(true);
        locationController.add('/video-recorder');
        await tester.pump();

        // GoRouter falsely reports home
        locationController.add('/home/0');
        await tester.pump();

        clearInteractions(videoFeedController);

        // Recorder actually closes — overlay cleared
        container.read(overlayVisibilityProvider.notifier).setPageOpen(false);
        await tester.pump();

        // Now the overlay listener should resume playback
        verify(
          () => videoFeedController.setActive(active: true),
        ).called(1);
      },
    );
  });
}
