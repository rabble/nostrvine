// ABOUTME: Widget tests for PooledFullscreenVideoFeedScreen
// ABOUTME: Tests native feed rendering and BLoC event dispatching

// Permanent: installs native MethodChannel handlers for the pooled video
// player; keep isolated until those channel handlers are per-test fixtures.
@Tags(['skip_very_good_optimization'])
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_settings_menu.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_feed_item/actions/actions.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../test_data/video_test_data.dart';

class MockFullscreenFeedBloc
    extends MockBloc<FullscreenFeedEvent, FullscreenFeedState>
    implements FullscreenFeedBloc {}

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

class MockMediaAuthInterceptor extends Mock implements MediaAuthInterceptor {}

class _FakeBuildContext extends Fake implements BuildContext {}

class _NativePlayerHarness {
  _NativePlayerHarness(this.tester);

  final WidgetTester tester;
  final setClipsArguments = <Map<Object?, Object?>>[];
  final _installedPlayerIds = <int>{};

  static const _globalChannel = MethodChannel('divine_video_player');
  static const _codec = StandardMethodCodec();

  void install({Iterable<int> playerIds = const <int>[0, 1, 2, 3]}) {
    DivineVideoPlayerController.resetIdCounterForTesting();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _globalChannel,
      (call) async {
        if (call.method == 'create') return <Object?, Object?>{};
        return null;
      },
    );

    for (final playerId in playerIds) {
      _installedPlayerIds.add(playerId);
      final playerChannel = MethodChannel(
        'divine_video_player/player_$playerId',
      );
      final eventChannelName = 'divine_video_player/player_$playerId/events';

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        playerChannel,
        (call) async {
          if (call.method == 'setClips') {
            setClipsArguments.add(
              (call.arguments as Map).cast<Object?, Object?>(),
            );
          }
          return null;
        },
      );

      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        eventChannelName,
        (message) async {
          final call = _codec.decodeMethodCall(message);
          if (call.method == 'listen') {
            scheduleMicrotask(() async {
              await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
                eventChannelName,
                _codec.encodeSuccessEnvelope(const <Object?, Object?>{
                  'status': 'ready',
                  'videoWidth': 1280,
                  'videoHeight': 720,
                  'isFirstFrameRendered': true,
                }),
                (_) {},
              );
            });
          }
          return _codec.encodeSuccessEnvelope(null);
        },
      );
    }
  }

  Future<void> dispose() async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _globalChannel,
      null,
    );
    for (final playerId in _installedPlayerIds) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel('divine_video_player/player_$playerId'),
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'divine_video_player/player_$playerId/events',
        null,
      );
    }
    _installedPlayerIds.clear();
  }
}

// Full 64-character test IDs.
const testVideoId1 =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const testVideoId2 =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1';
const testVideoId3 =
    'c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1b2';
const testPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';

class _PopCountingObserver extends NavigatorObserver {
  _PopCountingObserver({required this.onPop});

  final VoidCallback onPop;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onPop();
  }
}

void main() {
  group('PooledFullscreenVideoFeedScreen', () {
    group('fullscreen video media alignment', () {
      test('centers contained 1 x 1 / landscape videos in the viewport', () {
        expect(
          fullscreenVideoMediaAlignment(isPortrait: false),
          Alignment.center,
        );
      });

      test('keeps portrait videos centered while they cover the viewport', () {
        expect(
          fullscreenVideoMediaAlignment(isPortrait: true),
          Alignment.center,
        );
      });
    });

    late MockFullscreenFeedBloc mockBloc;
    late MockProfileRepository mockProfileRepository;
    late MockNip05VerificationService mockNip05VerificationService;
    late StreamController<FullscreenFeedState> stateController;
    late _MockVideoVolumeCubit videoVolumeCubit;

    setUpAll(() {
      InfiniteVideoFeed.debugIsSupportedOverride = true;

      registerFallbackValue(const FullscreenFeedStarted());
      registerFallbackValue(const FullscreenFeedIndexChanged(0));
      registerFallbackValue(const FullscreenFeedLoadMoreRequested());
      registerFallbackValue(const FullscreenFeedVideoCacheStarted(index: 0));
      registerFallbackValue(const FullscreenFeedVideoUnavailable('fallback'));
      registerFallbackValue(const FullscreenFeedVideoRemoved('fallback'));
      registerFallbackValue(const FullscreenFeedBlocklistChanged());
      registerFallbackValue(const FullscreenFeedSkipAcknowledged());
      registerFallbackValue(Duration.zero);
      registerFallbackValue(_FakeBuildContext());
      registerFallbackValue(<String, String>{});
    });

    setUp(() {
      mockBloc = MockFullscreenFeedBloc();
      mockProfileRepository = createMockProfileRepository();
      mockNip05VerificationService = createMockNip05VerificationService();
      stateController = StreamController<FullscreenFeedState>.broadcast();
      videoVolumeCubit = _MockVideoVolumeCubit();
      when(() => videoVolumeCubit.state).thenReturn(const VideoVolumeState());
      when(() => mockBloc.stream).thenAnswer((_) => stateController.stream);
    });

    tearDown(() async {
      await stateController.close();
    });

    tearDownAll(() {
      InfiniteVideoFeed.debugIsSupportedOverride = null;
    });

    List<VideoEvent> createTestVideos({int count = 3}) {
      return [
        createTestVideoEvent(
          id: testVideoId1,
          pubkey: testPubkey,
          videoUrl: 'https://example.com/video1.mp4',
        ),
        if (count > 1)
          createTestVideoEvent(
            id: testVideoId2,
            pubkey: testPubkey,
            videoUrl: 'https://example.com/video2.mp4',
          ),
        if (count > 2)
          createTestVideoEvent(
            id: testVideoId3,
            pubkey: testPubkey,
            videoUrl: 'https://example.com/video3.mp4',
          ),
      ];
    }

    Widget buildContent({
      String? contextTitle,
      ViewTrafficSource trafficSource = ViewTrafficSource.unknown,
      String? sourceDetail,
    }) {
      return MultiBlocProvider(
        providers: [
          BlocProvider<FullscreenFeedBloc>.value(value: mockBloc),
          BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
          BlocProvider<VideoPlaybackStatusCubit>(
            create: (_) => VideoPlaybackStatusCubit(),
          ),
        ],
        child: FullscreenFeedContent(
          contextTitle: contextTitle,
          trafficSource: trafficSource,
          sourceDetail: sourceDetail,
        ),
      );
    }

    Widget buildSubject({
      FullscreenFeedState? state,
      List<dynamic>? additionalOverrides,
      String? contextTitle,
      ViewTrafficSource trafficSource = ViewTrafficSource.unknown,
      String? sourceDetail,
    }) {
      final effectiveState = state ?? const FullscreenFeedState();
      when(() => mockBloc.state).thenReturn(effectiveState);

      return testMaterialApp(
        additionalOverrides: additionalOverrides,
        mockProfileRepository: mockProfileRepository,
        mockNip05VerificationService: mockNip05VerificationService,
        home: buildContent(
          contextTitle: contextTitle,
          trafficSource: trafficSource,
          sourceDetail: sourceDetail,
        ),
      );
    }

    InfiniteVideoFeed nativeFeed(WidgetTester tester) {
      return tester.widget<InfiniteVideoFeed>(find.byType(InfiniteVideoFeed));
    }

    group('blocklist version listener', () {
      testWidgets(
        'dispatches FullscreenFeedBlocklistChanged when the version increments',
        (tester) async {
          await tester.pumpWidget(buildSubject());

          // The listener registers on first build with previous == null; it
          // must NOT dispatch until the version actually changes.
          verifyNever(
            () => mockBloc.add(const FullscreenFeedBlocklistChanged()),
          );

          final container = ProviderScope.containerOf(
            tester.element(find.byType(FullscreenFeedContent)),
            listen: false,
          );
          container.read(blocklistVersionProvider.notifier).increment();
          await tester.pump();

          verify(
            () => mockBloc.add(const FullscreenFeedBlocklistChanged()),
          ).called(1);
        },
      );
    });

    group('state rendering', () {
      testWidgets('shows loading indicator when status is initial', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(state: const FullscreenFeedState()),
        );

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.byType(FeedVideos), findsNothing);
        expect(find.byType(InfiniteVideoFeed), findsNothing);
      });

      testWidgets('shows loading indicator when videos list is empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
            ),
          ),
        );

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.byType(FeedVideos), findsNothing);
        expect(find.byType(InfiniteVideoFeed), findsNothing);
      });

      testWidgets(
        'renders empty-state when status is emptyAfterRemoval and pop is a '
        'no-op (cold deep-link fallback)',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: const FullscreenFeedState(
                status: FullscreenFeedStatus.emptyAfterRemoval,
              ),
              contextTitle: 'Saved',
            ),
          );

          final removedText = lookupAppLocalizations(
            const Locale('en'),
          ).fullscreenFeedRemovedMessage;
          expect(find.text(removedText), findsOneWidget);
          expect(find.byType(BrandedLoadingIndicator), findsNothing);
          expect(find.byType(FeedVideos), findsNothing);
        },
      );

      testWidgets(
        'empty-state back button falls back to root when route cannot pop',
        (tester) async {
          var sentinelBuilt = false;
          final router = GoRouter(
            initialLocation: '/empty-feed',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) {
                  sentinelBuilt = true;
                  return const Scaffold(body: Text('home-sentinel'));
                },
              ),
              GoRoute(
                path: '/empty-feed',
                builder: (_, _) => Scaffold(
                  appBar: AppBar(
                    leading: Builder(
                      builder: (context) => BackButton(
                        onPressed: () =>
                            context.canPop() ? context.pop() : context.go('/'),
                      ),
                    ),
                  ),
                  body: const Center(child: Text('empty-state-body')),
                ),
              ),
            ],
          );
          addTearDown(router.dispose);

          await tester.pumpWidget(
            MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.text('empty-state-body'), findsOneWidget);

          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();

          expect(sentinelBuilt, isTrue);
          expect(find.text('home-sentinel'), findsOneWidget);
          expect(find.text('empty-state-body'), findsNothing);
        },
      );

      testWidgets('shows native FeedVideos when videos are available', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          ),
        );

        expect(find.byType(FeedVideos), findsOneWidget);
        expect(find.byType(InfiniteVideoFeed), findsOneWidget);
      });

      testWidgets('passes route traffic attribution to FeedVideos', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
            trafficSource: ViewTrafficSource.profile,
            sourceDetail: 'npub-profile',
          ),
        );
        await tester.pump();

        final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
        expect(feedVideos.trafficSource, ViewTrafficSource.profile);
        expect(feedVideos.sourceDetail, 'npub-profile');
      });

      testWidgets(
        'ready-state back button falls back to root when route cannot pop',
        (tester) async {
          final videos = createTestVideos(count: 1);
          final state = FullscreenFeedState(
            status: FullscreenFeedStatus.ready,
            videos: videos,
          );
          when(() => mockBloc.state).thenReturn(state);

          var sentinelBuilt = false;
          late final GoRouter router;

          router = GoRouter(
            initialLocation: '/shared-video',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) {
                  sentinelBuilt = true;
                  return const Scaffold(body: Text('home-sentinel'));
                },
              ),
              GoRoute(
                path: '/shared-video',
                builder: (_, _) => buildContent(contextTitle: 'Shared Video'),
              ),
            ],
          );
          addTearDown(router.dispose);

          await tester.pumpWidget(
            testProviderScope(
              mockProfileRepository: mockProfileRepository,
              mockNip05VerificationService: mockNip05VerificationService,
              child: MaterialApp.router(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.byType(FeedVideos), findsOneWidget);
          expect(sentinelBuilt, isFalse);

          tester
              .widget<DiVineAppBarIconButton>(
                find.byType(DiVineAppBarIconButton).first,
              )
              .onPressed
              ?.call();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(sentinelBuilt, isTrue);
          expect(find.text('home-sentinel'), findsOneWidget);
        },
      );

      testWidgets(
        'shows the category title in the fullscreen app bar when provided',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
              ),
              contextTitle: 'Animals',
            ),
          );

          expect(find.text('Animals'), findsOneWidget);
        },
      );
    });

    group('BLoC event dispatching', () {
      testWidgets('dispatches FullscreenFeedIndexChanged when video changes', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          ),
        );

        final feedVideos = tester.widget<FeedVideos>(find.byType(FeedVideos));
        feedVideos.onActiveVideoChanged?.call(videos[1], 1);

        verify(
          () => mockBloc.add(const FullscreenFeedIndexChanged(1)),
        ).called(1);
      });

      testWidgets('dispatches FullscreenFeedLoadMoreRequested on near end', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
              canLoadMore: true,
            ),
          ),
        );

        nativeFeed(tester).onNearEnd?.call();

        verify(
          () => mockBloc.add(const FullscreenFeedLoadMoreRequested()),
        ).called(1);
      });

      testWidgets(
        'does not dispatch FullscreenFeedLoadMoreRequested when '
        'canLoadMore is false',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
              ),
            ),
          );

          nativeFeed(tester).onNearEnd?.call();

          verifyNever(
            () => mockBloc.add(const FullscreenFeedLoadMoreRequested()),
          );
        },
      );

      testWidgets('passes nearEndThreshold of 10 to InfiniteVideoFeed', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
              canLoadMore: true,
            ),
          ),
        );

        expect(nativeFeed(tester).nearEndThreshold, equals(10));
      });

      testWidgets(
        'shows LoadingMorePill (visible) on last video while loading more',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
                currentIndex: videos.length - 1,
                isLoadingMore: true,
                canLoadMore: true,
              ),
            ),
          );
          await tester.pump();

          final pill = tester.widget<LoadingMorePill>(
            find.byType(LoadingMorePill),
          );
          expect(pill.isVisible, isTrue);
        },
      );

      testWidgets(
        'hides LoadingMorePill when isLoadingMore is false',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
                currentIndex: videos.length - 1,
              ),
            ),
          );
          await tester.pump();

          final pill = tester.widget<LoadingMorePill>(
            find.byType(LoadingMorePill),
          );
          expect(pill.isVisible, isFalse);
        },
      );

      testWidgets(
        'hides LoadingMorePill when not on the last video',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
                isLoadingMore: true,
                canLoadMore: true,
              ),
            ),
          );
          await tester.pump();

          final pill = tester.widget<LoadingMorePill>(
            find.byType(LoadingMorePill),
          );
          expect(pill.isVisible, isFalse);
        },
      );

      testWidgets(
        'LoadingMorePill renders localized feedLoadingMore copy when visible',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
                currentIndex: videos.length - 1,
                isLoadingMore: true,
                canLoadMore: true,
              ),
            ),
          );
          await tester.pump();

          final loadingMoreText = lookupAppLocalizations(
            const Locale('en'),
          ).feedLoadingMore;
          expect(find.text(loadingMoreText), findsOneWidget);
        },
      );

      testWidgets(
        'navigator.maybePop fires when status becomes emptyAfterRemoval',
        (tester) async {
          var popCount = 0;
          final observer = _PopCountingObserver(onPop: () => popCount++);

          final videos = createTestVideos(count: 1);
          final initialState = FullscreenFeedState(
            status: FullscreenFeedStatus.ready,
            videos: videos,
          );
          final emptyState = FullscreenFeedState(
            status: FullscreenFeedStatus.emptyAfterRemoval,
            removedVideoIds: {videos.first.id},
          );
          final controller = StreamController<FullscreenFeedState>();
          addTearDown(controller.close);
          whenListen(mockBloc, controller.stream, initialState: initialState);

          await tester.pumpWidget(
            MaterialApp(
              navigatorObservers: [observer],
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MultiBlocProvider(
                            providers: [
                              BlocProvider<FullscreenFeedBloc>.value(
                                value: mockBloc,
                              ),
                              BlocProvider<VideoVolumeCubit>.value(
                                value: videoVolumeCubit,
                              ),
                              BlocProvider<VideoPlaybackStatusCubit>(
                                create: (_) => VideoPlaybackStatusCubit(),
                              ),
                            ],
                            child:
                                BlocListener<
                                  FullscreenFeedBloc,
                                  FullscreenFeedState
                                >(
                                  listenWhen: (prev, curr) =>
                                      prev.status != curr.status &&
                                      curr.status ==
                                          FullscreenFeedStatus
                                              .emptyAfterRemoval,
                                  listener: (ctx, _) {
                                    Navigator.of(ctx).maybePop();
                                  },
                                  child: const Scaffold(body: Text('on-feed')),
                                ),
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  );
                },
              ),
            ),
          );

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.text('on-feed'), findsOneWidget);

          controller.add(emptyState);
          await tester.pumpAndSettle();

          expect(popCount, greaterThanOrEqualTo(1));
          expect(find.text('on-feed'), findsNothing);
        },
      );

      testWidgets(
        'dispatches FullscreenFeedVideoUnavailable when playback status '
        'becomes notFound',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
              ),
            ),
          );

          final cubit = BlocProvider.of<VideoPlaybackStatusCubit>(
            tester.element(find.byType(FullscreenFeedContent)),
          );

          cubit.report(videos.first.id, PlaybackStatus.notFound);
          await tester.pump();

          verify(
            () => mockBloc.add(FullscreenFeedVideoUnavailable(videos.first.id)),
          ).called(1);
        },
      );

      testWidgets(
        'does not dispatch unavailable event when video is already removed',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
                removedVideoIds: {videos.first.id},
              ),
            ),
          );

          final cubit = BlocProvider.of<VideoPlaybackStatusCubit>(
            tester.element(find.byType(FullscreenFeedContent)),
          );

          cubit.report(videos.first.id, PlaybackStatus.notFound);
          await tester.pump();

          verifyNever(
            () =>
                mockBloc.add(any(that: isA<FullscreenFeedVideoUnavailable>())),
          );
        },
      );

      testWidgets(
        'does not dispatch unavailable event for non-notFound statuses',
        (tester) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
              ),
            ),
          );

          final cubit = BlocProvider.of<VideoPlaybackStatusCubit>(
            tester.element(find.byType(FullscreenFeedContent)),
          );

          cubit.report(videos.first.id, PlaybackStatus.forbidden);
          await tester.pump();

          verifyNever(
            () =>
                mockBloc.add(any(that: isA<FullscreenFeedVideoUnavailable>())),
          );
        },
      );

      testWidgets(
        'acknowledges pendingSkipTarget when the BLoC signals a skip',
        (tester) async {
          final videos = createTestVideos();
          final initialState = FullscreenFeedState(
            status: FullscreenFeedStatus.ready,
            videos: videos,
          );
          final skipState = FullscreenFeedState(
            status: FullscreenFeedStatus.ready,
            videos: videos,
            removedVideoIds: {videos.first.id},
            pendingSkipTarget: 1,
          );

          whenListen(
            mockBloc,
            Stream.fromIterable([initialState, skipState]),
            initialState: initialState,
          );

          await tester.pumpWidget(buildSubject(state: initialState));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          verify(
            () => mockBloc.add(const FullscreenFeedSkipAcknowledged()),
          ).called(1);
        },
      );

      testWidgets(
        'verify age retries playback with viewer auth headers',
        (tester) async {
          const sha256 =
              'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
          const videoUrl = 'https://media.divine.video/$sha256/720p.mp4';
          const headers = {'Authorization': 'Nostr fullscreen-token'};
          final nativePlayer = _NativePlayerHarness(tester)..install();
          addTearDown(nativePlayer.dispose);
          final mockMediaAuthInterceptor = MockMediaAuthInterceptor();
          final video = createTestVideoEvent(
            id: testVideoId1,
            pubkey: testPubkey,
            videoUrl: videoUrl,
            sha256: sha256,
          );

          when(
            () => mockMediaAuthInterceptor.handleUnauthorizedMedia(
              context: any(named: 'context'),
              sha256Hash: sha256,
              url: videoUrl,
              serverUrl: 'https://media.divine.video',
              category: 'video',
            ),
          ).thenAnswer((_) async => const ViewerAuthAuthorized(headers));

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: [video],
              ),
              additionalOverrides: [
                mediaAuthInterceptorProvider.overrideWithValue(
                  mockMediaAuthInterceptor,
                ),
              ],
            ),
          );
          await tester.pump();

          final cubit = BlocProvider.of<VideoPlaybackStatusCubit>(
            tester.element(find.byType(FullscreenFeedContent)),
          );
          cubit.report(video.id, PlaybackStatus.ageRestricted);
          await tester.pump();

          expect(find.byType(ModeratedContentOverlay), findsOneWidget);
          expect(
            find.text(ModeratedContentOverlayStrings.verifyAgeLabel),
            findsOneWidget,
          );

          await tester.tap(
            find.text(ModeratedContentOverlayStrings.verifyAgeLabel),
          );
          await tester.pump();
          await tester.pump();

          verify(
            () => mockMediaAuthInterceptor.handleUnauthorizedMedia(
              context: any(named: 'context'),
              sha256Hash: sha256,
              url: videoUrl,
              serverUrl: 'https://media.divine.video',
              category: 'video',
            ),
          ).called(1);
          expect(cubit.state.statusFor(video.id), PlaybackStatus.ready);
          expect(
            nativePlayer.setClipsArguments,
            contains(
              predicate<Map<Object?, Object?>>((arguments) {
                final clips = arguments['clips'];
                if (clips is! List || clips.isEmpty) return false;
                final clip = clips.first;
                if (clip is! Map || clip['uri'] != videoUrl) {
                  return false;
                }
                final httpHeaders = clip['httpHeaders'];
                return httpHeaders is Map &&
                    httpHeaders['Authorization'] == headers['Authorization'];
              }),
            ),
          );
        },
      );

      testWidgets(
        'verify age authenticates the optimized source for a bare-hash URL',
        (tester) async {
          const sha256 =
              'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
          // Production events carry the bare blob URL; the pooled feed resolves
          // playback to the optimized .../720p.mp4 variant. The retry must
          // authenticate that resolved source, not just the bare event URL.
          const videoUrl = 'https://media.divine.video/$sha256';
          const optimizedUrl = 'https://media.divine.video/$sha256/720p.mp4';
          const headers = {'Authorization': 'Nostr fullscreen-token'};
          final nativePlayer = _NativePlayerHarness(tester)..install();
          addTearDown(nativePlayer.dispose);
          final mockMediaAuthInterceptor = MockMediaAuthInterceptor();
          final video = createTestVideoEvent(
            id: testVideoId1,
            pubkey: testPubkey,
            videoUrl: videoUrl,
            sha256: sha256,
          );

          when(
            () => mockMediaAuthInterceptor.handleUnauthorizedMedia(
              context: any(named: 'context'),
              sha256Hash: sha256,
              url: videoUrl,
              serverUrl: 'https://media.divine.video',
              category: 'video',
            ),
          ).thenAnswer((_) async => const ViewerAuthAuthorized(headers));

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: [video],
              ),
              additionalOverrides: [
                mediaAuthInterceptorProvider.overrideWithValue(
                  mockMediaAuthInterceptor,
                ),
              ],
            ),
          );
          await tester.pump();

          final cubit = BlocProvider.of<VideoPlaybackStatusCubit>(
            tester.element(find.byType(FullscreenFeedContent)),
          );
          cubit.report(video.id, PlaybackStatus.ageRestricted);
          await tester.pump();

          await tester.tap(
            find.text(ModeratedContentOverlayStrings.verifyAgeLabel),
          );
          await tester.pump();
          await tester.pump();

          expect(cubit.state.statusFor(video.id), PlaybackStatus.ready);
          // The resolved optimized source — not the bare event URL — must carry
          // the viewer auth header on retry.
          expect(
            nativePlayer.setClipsArguments,
            contains(
              predicate<Map<Object?, Object?>>((arguments) {
                final clips = arguments['clips'];
                if (clips is! List || clips.isEmpty) return false;
                final clip = clips.first;
                if (clip is! Map || clip['uri'] != optimizedUrl) {
                  return false;
                }
                final httpHeaders = clip['httpHeaders'];
                return httpHeaders is Map &&
                    httpHeaders['Authorization'] == headers['Authorization'];
              }),
            ),
          );
        },
      );
    });

    group('auto advance', () {
      testWidgets('mounts the playback settings popover trigger', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(FeedSettingsMenu), findsOneWidget);
      });

      testWidgets('requests pagination at the end when more content exists', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
              currentIndex: videos.length - 1,
              canLoadMore: true,
            ),
          ),
        );
        await tester.pump();

        final cubit = BlocProvider.of<FeedAutoAdvanceCubit>(
          tester.element(find.byType(FeedSettingsMenu)),
        );
        cubit.toggle();

        nativeFeed(tester).onVideoLoopCompleted?.call(videos.length - 1);
        await tester.pump();

        verify(
          () => mockBloc.add(const FullscreenFeedLoadMoreRequested()),
        ).called(1);
      });

      testWidgets('non-swipe interactions suppress auto advance', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          ),
        );
        await tester.pump();

        final cubit = BlocProvider.of<FeedAutoAdvanceCubit>(
          tester.element(find.byType(FeedSettingsMenu)),
        );
        cubit.toggle();

        await tester.tap(find.byType(LikeActionButton).first);
        await tester.pump();

        nativeFeed(tester).onVideoLoopCompleted?.call(0);
        await tester.pump();

        verifyNever(
          () => mockBloc.add(const FullscreenFeedIndexChanged(1)),
        );
      });
    });
  });
}
