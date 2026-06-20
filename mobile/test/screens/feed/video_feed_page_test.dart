// ABOUTME: Widget tests for VideoFeedPage overlay-to-playback integration
// ABOUTME: Verifies that overlay visibility and tab switches pause/resume the
// ABOUTME: native video feed

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../test_data/video_test_data.dart';

class _MockGoRouter extends Mock implements GoRouter {}

class _MockVideoFeedBloc extends MockBloc<VideoFeedEvent, VideoFeedBlocState>
    implements VideoFeedBloc {}

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

Widget _buildEmptyFeedSubject(VideoFeedBlocState state, {GoRouter? router}) {
  final child = Scaffold(body: FeedEmptyWidget(state: state));

  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: router == null
        ? child
        : InheritedGoRouter(goRouter: router, child: child),
  );
}

void main() {
  late _MockVideoFeedBloc videoFeedBloc;
  late _MockVideoVolumeCubit videoVolumeCubit;

  setUpAll(() {
    // This test suite validates native-feed behavior; pin the runtime branch
    // so host platform support changes do not flip widget paths.
    InfiniteVideoFeed.debugIsSupportedOverride = true;
  });

  setUp(() {
    videoFeedBloc = _MockVideoFeedBloc();
    videoVolumeCubit = _MockVideoVolumeCubit();
    when(() => videoVolumeCubit.state).thenReturn(const VideoVolumeState());
    whenListen(videoVolumeCubit, const Stream<VideoVolumeState>.empty());
  });

  tearDownAll(() {
    InfiniteVideoFeed.debugIsSupportedOverride = null;
  });

  group(FeedEmptyWidget, () {
    testWidgets('uses no-follow guidance for an empty For You feed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildEmptyFeedSubject(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            error: VideoFeedError.noFollowedUsers,
          ),
        ),
      );

      expect(
        find.text(
          'No followed users.\nFollow someone to see their videos here.',
        ),
        findsOneWidget,
      );
      expect(find.text('Explore Videos'), findsOneWidget);
      expect(find.textContaining('forYou'), findsNothing);
      expect(find.textContaining('ForYou'), findsNothing);
    });

    testWidgets(
      'uses localized Following copy for an empty Following no-follow feed',
      (tester) async {
        await tester.pumpWidget(
          _buildEmptyFeedSubject(
            const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              mode: FeedMode.following,
              error: VideoFeedError.noFollowedUsers,
            ),
          ),
        );

        expect(
          find.text(
            'No videos from people you follow yet.\n'
            'Find creators you like and follow them.',
          ),
          findsOneWidget,
        );
        expect(find.text('Explore Videos'), findsOneWidget);
      },
    );

    testWidgets('uses For You copy instead of the raw enum name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildEmptyFeedSubject(
          const VideoFeedBlocState(status: VideoFeedStatus.success),
        ),
      );

      expect(
        find.text(
          'Your For You feed is empty.\n'
          'Explore videos and follow creators to shape it.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('forYou'), findsNothing);
      expect(find.textContaining('ForYou'), findsNothing);
    });

    testWidgets('uses localized Following copy for an empty Following feed', (
      tester,
    ) async {
      final router = _MockGoRouter();
      when(() => router.go(any())).thenReturn(null);

      await tester.pumpWidget(
        _buildEmptyFeedSubject(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            mode: FeedMode.following,
          ),
          router: router,
        ),
      );

      expect(
        find.text(
          'No videos from people you follow yet.\n'
          'Find creators you like and follow them.',
        ),
        findsOneWidget,
      );
      expect(find.text('Explore Videos'), findsOneWidget);
      expect(find.byType(DivineButton), findsOneWidget);
      expect(find.textContaining('following feed'), findsNothing);

      await tester.tap(find.text('Explore Videos'));

      verify(() => router.go(ExploreScreen.pathForTab('popular'))).called(1);
    });

    testWidgets('uses the design-system arrow on the Following empty CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildEmptyFeedSubject(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            mode: FeedMode.following,
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(DivineButton),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon &&
                widget.icon == DivineIconName.arrowRight,
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group(VideoFeedView, () {
    testWidgets('passes home traffic attribution to FeedVideos', (
      tester,
    ) async {
      final video = createTestVideoEvent();
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: [video],
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(),
          ),
        ),
      );
      await tester.pump();

      final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
      expect(feedVideos.trafficSource, ViewTrafficSource.home);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('requests auto-refresh when app returns from background', (
      tester,
    ) async {
      final video = createTestVideoEvent();
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: [video],
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(),
          ),
        ),
      );
      await tester.pump();

      // A genuine background → foreground transition: background first, then
      // resume. Only then should an auto-refresh be requested.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verify(
        () => videoFeedBloc.add(const VideoFeedAutoRefreshRequested()),
      ).called(1);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'does not auto-refresh on cold-start resume (no prior background)',
      (tester) async {
        final video = createTestVideoEvent();
        final state = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [video],
        );
        when(() => videoFeedBloc.state).thenReturn(state);
        whenListen(
          videoFeedBloc,
          const Stream<VideoFeedBlocState>.empty(),
          initialState: state,
        );

        await tester.pumpWidget(
          testMaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
                BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              ],
              child: const VideoFeedView(),
            ),
          ),
        );
        await tester.pump();

        // The launch `resumed` event with no preceding background must not
        // trigger an auto-refresh — it would wipe the just-served cached feed.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        verifyNever(
          () => videoFeedBloc.add(const VideoFeedAutoRefreshRequested()),
        );

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('passes restored home index to FeedVideos', (tester) async {
      final videos = [
        createTestVideoEvent(id: 'video-0'),
        createTestVideoEvent(id: 'video-1'),
        createTestVideoEvent(id: 'video-2'),
      ];
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: videos,
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(initialIndex: 2),
          ),
        ),
      );
      await tester.pump();

      final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
      expect(feedVideos.currentIndex, 2);

      // Drain the player-window preload grace timer before the tree is
      // disposed so no timer is pending at test teardown.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('clamps restored home index to loaded videos', (tester) async {
      final videos = [
        createTestVideoEvent(id: 'video-0'),
        createTestVideoEvent(id: 'video-1'),
        createTestVideoEvent(id: 'video-2'),
      ];
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: videos,
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(initialIndex: 99),
          ),
        ),
      );
      await tester.pump();

      final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
      expect(feedVideos.currentIndex, 2);

      // Drain the player-window preload grace timer before the tree is
      // disposed so no timer is pending at test teardown.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('records active video index for home tab restoration', (
      tester,
    ) async {
      final videos = [
        createTestVideoEvent(id: 'video-0'),
        createTestVideoEvent(id: 'video-1'),
      ];
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: videos,
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(),
          ),
        ),
      );
      await tester.pump();

      final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
      feedVideos.onActiveVideoChanged!(videos[1], 1);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoFeedView)),
      );
      expect(
        container.read(lastTabPositionProvider)[RouteType.home],
        equals(1),
      );

      // Drain the player-window preload grace timer before the tree is
      // disposed so no timer is pending at test teardown.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('home route emissions do not clobber recorded home index', (
      tester,
    ) async {
      const bodyKey = Key('home-position-provider-body');
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            routerLocationStreamProvider.overrideWith(
              (_) => Stream.value('/home/0'),
            ),
          ],
          home: const SizedBox.shrink(key: bodyKey),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(bodyKey)),
      );
      final positions = container.read(lastTabPositionProvider.notifier);
      positions.recordPosition(RouteType.home, 12);

      await tester.pump();

      expect(
        container.read(lastTabPositionProvider)[RouteType.home],
        equals(12),
      );
    });

    testWidgets('retry resets home index before refreshing failed feed', (
      tester,
    ) async {
      const state = VideoFeedBlocState(
        status: VideoFeedStatus.failure,
        error: VideoFeedError.loadFailed,
      );
      when(() => videoFeedBloc.state).thenReturn(state);
      whenListen(
        videoFeedBloc,
        const Stream<VideoFeedBlocState>.empty(),
        initialState: state,
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: const VideoFeedView(initialIndex: 4),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoFeedView)),
      );
      container
          .read(lastTabPositionProvider.notifier)
          .recordPosition(RouteType.home, 4);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(
        container.read(lastTabPositionProvider)[RouteType.home],
        equals(0),
      );
      verify(
        () => videoFeedBloc.add(const VideoFeedRefreshRequested()),
      ).called(1);
    });

    group('home feed playback follows the visible route', () {
      FeedVideos feedVideos(WidgetTester tester) => tester.widget<FeedVideos>(
        find.byType(FeedVideos, skipOffstage: false),
      );

      Future<StreamController<String>> pumpFeed(WidgetTester tester) async {
        final controller = StreamController<String>.broadcast();
        addTearDown(controller.close);

        final video = createTestVideoEvent();
        final state = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [video],
        );
        when(() => videoFeedBloc.state).thenReturn(state);
        whenListen(
          videoFeedBloc,
          const Stream<VideoFeedBlocState>.empty(),
          initialState: state,
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              routerLocationStreamProvider.overrideWith(
                (_) => controller.stream,
              ),
            ],
            home: MultiBlocProvider(
              providers: [
                BlocProvider<VideoFeedBloc>.value(value: videoFeedBloc),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
                BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              ],
              child: const VideoFeedView(),
            ),
          ),
        );
        await tester.pump();
        return controller;
      }

      Future<void> drainAndDispose(WidgetTester tester) async {
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }

      ProviderContainer containerOf(WidgetTester tester) =>
          ProviderScope.containerOf(
            tester.element(find.byType(VideoFeedView, skipOffstage: false)),
          );

      void setObscured(WidgetTester tester, {required bool obscured}) {
        containerOf(
          tester,
        ).read(shellObscuredProvider.notifier).setObscured(obscured: obscured);
      }

      // Drives the authoritative active tab (0 = Home) the home feed pauses on.
      void setBranchIndex(WidgetTester tester, int index) {
        containerOf(tester).read(activeBranchIndexProvider.notifier).state =
            index;
      }

      void setBottomSheetOpen(WidgetTester tester, {required bool open}) {
        containerOf(
          tester,
        ).read(overlayVisibilityProvider.notifier).setBottomSheetOpen(open);
      }

      void setPageOpen(WidgetTester tester, {required bool open}) {
        containerOf(
          tester,
        ).read(overlayVisibilityProvider.notifier).setPageOpen(open);
      }

      testWidgets(
        'stays paused while a route covers the shell, even on the home tab',
        (tester) async {
          await pumpFeed(tester);

          // Feed starts active on the home tab.
          await tester.pump();
          expect(feedVideos(tester).isActive, isTrue);

          // A full-screen route covers the shell: feed pauses.
          setObscured(tester, obscured: true);
          await tester.pump();
          expect(feedVideos(tester).isActive, isFalse);

          // Home is still the active branch (e.g. a fullscreen video opened
          // from the profile is popped back to the still-covering profile), but
          // the shell stays covered, so the feed must NOT resume.
          setBranchIndex(tester, 0);
          await tester.pump();
          expect(feedVideos(tester).isActive, isFalse);

          await drainAndDispose(tester);
        },
      );

      testWidgets('resumes only once the shell is no longer covered', (
        tester,
      ) async {
        await pumpFeed(tester);
        await tester.pump();
        expect(feedVideos(tester).isActive, isTrue);

        // Profile pushed over the shell pauses the feed.
        setObscured(tester, obscured: true);
        await tester.pump();
        expect(feedVideos(tester).isActive, isFalse);

        // Profile closed (shell revealed) while home is still the active
        // branch: the feed resumes.
        setObscured(tester, obscured: false);
        await tester.pump();
        expect(feedVideos(tester).isActive, isTrue);

        await drainAndDispose(tester);
      });

      testWidgets('pauses on a non-home tab and resumes back on home', (
        tester,
      ) async {
        await pumpFeed(tester);
        await tester.pump();
        expect(feedVideos(tester).isActive, isTrue);

        setBranchIndex(tester, 1); // Explore
        await tester.pump();
        expect(feedVideos(tester).isActive, isFalse);

        setBranchIndex(tester, 0); // back to Home
        await tester.pump();
        expect(feedVideos(tester).isActive, isTrue);

        await drainAndDispose(tester);
      });

      testWidgets(
        'a comments/share bottom sheet pauses but keeps neighbours warm',
        (tester) async {
          await pumpFeed(tester);
          await tester.pump();

          // Active home feed releases neighbours when it backgrounds.
          expect(feedVideos(tester).isActive, isTrue);
          expect(feedVideos(tester).releaseNeighboursWhenInactive, isTrue);

          // A bottom sheet (comments/share) pauses the current player but must
          // NOT tear down the off-screen neighbours or prefetch.
          setBottomSheetOpen(tester, open: true);
          await tester.pump();
          expect(feedVideos(tester).isActive, isFalse);
          expect(feedVideos(tester).releaseNeighboursWhenInactive, isFalse);

          // Closing the sheet restores the release-on-background behaviour.
          setBottomSheetOpen(tester, open: false);
          await tester.pump();
          expect(feedVideos(tester).isActive, isTrue);
          expect(feedVideos(tester).releaseNeighboursWhenInactive, isTrue);

          await drainAndDispose(tester);
        },
      );

      testWidgets('a full-screen page overlay still releases neighbours', (
        tester,
      ) async {
        await pumpFeed(tester);
        await tester.pump();

        // A full-screen page (settings, recorder, dialog) is the heavy case:
        // pause AND release, unlike a lightweight bottom sheet.
        setPageOpen(tester, open: true);
        await tester.pump();
        expect(feedVideos(tester).isActive, isFalse);
        expect(feedVideos(tester).releaseNeighboursWhenInactive, isTrue);

        await drainAndDispose(tester);
      });

      testWidgets(
        'a full-screen page overlay releases after a bottom sheet paused home',
        (tester) async {
          await pumpFeed(tester);
          await tester.pump();

          setBottomSheetOpen(tester, open: true);
          await tester.pump();
          expect(feedVideos(tester).isActive, isFalse);
          expect(feedVideos(tester).releaseNeighboursWhenInactive, isFalse);

          setPageOpen(tester, open: true);
          await tester.pump();
          expect(feedVideos(tester).isActive, isFalse);
          expect(feedVideos(tester).releaseNeighboursWhenInactive, isTrue);

          await drainAndDispose(tester);
        },
      );
    });
  });
}
