// ABOUTME: Tests for profile grid → fullscreen video navigation
// ABOUTME: Verifies tapping grid item navigates to correct video index and autoplays

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/widgets/profile/profile_videos_grid.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_provider_overrides.dart';

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _TestProfileFeed extends ProfileFeed {
  _TestProfileFeed(this._initialState);

  final VideoFeedState _initialState;
  int loadMoreCallCount = 0;

  @override
  Future<VideoFeedState> build(String userId) async => _initialState;

  @override
  Future<void> loadMore() async {
    loadMoreCallCount++;
    final currentState = state.asData?.value ?? _initialState;
    state = AsyncData(currentState.copyWith(isLoadingMore: true));
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  MockAuthService createTestAuthService(String? pubkey) {
    final mockAuth = createMockAuthService();
    when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkey);
    when(() => mockAuth.isAuthenticated).thenReturn(pubkey != null);
    final authState = pubkey != null
        ? AuthState.authenticated
        : AuthState.unauthenticated;
    when(() => mockAuth.authState).thenReturn(authState);
    when(
      () => mockAuth.authStateStream,
    ).thenAnswer((_) => Stream.value(authState));
    return mockAuth;
  }

  Widget shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: c.read(goRouterProvider),
    ),
  );

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  const testUserHex =
      '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
  const testUserNpub =
      'npub10zjuyx63vmwpga9kfh0hg49l08ntt4455ac5skfm785xddeuyuuqt7gxpj';

  final mockVideos = [
    VideoEvent(
      id: 'video0',
      pubkey: testUserHex,
      createdAt: nowUnix,
      content: 'Video 0',
      timestamp: now,
      title: 'Test Video 0',
      videoUrl: 'https://example.com/v0.mp4',
    ),
    VideoEvent(
      id: 'video1',
      pubkey: testUserHex,
      createdAt: nowUnix - 1,
      content: 'Video 1',
      timestamp: now.subtract(const Duration(seconds: 1)),
      title: 'Test Video 1',
      videoUrl: 'https://example.com/v1.mp4',
    ),
    VideoEvent(
      id: 'video2',
      pubkey: testUserHex,
      createdAt: nowUnix - 2,
      content: 'Video 2',
      timestamp: now.subtract(const Duration(seconds: 2)),
      title: 'Test Video 2',
      videoUrl: 'https://example.com/v2.mp4',
    ),
    VideoEvent(
      id: 'video3',
      pubkey: testUserHex,
      createdAt: nowUnix - 3,
      content: 'Video 3',
      timestamp: now.subtract(const Duration(seconds: 3)),
      title: 'Test Video 3',
      videoUrl: 'https://example.com/v3.mp4',
    ),
  ];

  final mockProfile = UserProfile(
    pubkey: testUserHex,
    displayName: 'Test User',
    name: 'testuser',
    about: 'Test profile',
    picture: 'https://example.com/avatar.jpg',
    createdAt: now,
    eventId: 'profile_event_id',
    rawData: const {
      'name': 'testuser',
      'display_name': 'Test User',
      'about': 'Test profile',
      'picture': 'https://example.com/avatar.jpg',
    },
  );

  group('Profile Grid Navigation', () {
    testWidgets('Tapping grid item at index 2 navigates to video at index 2', (
      tester,
    ) async {
      final c = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          videosForProfileRouteProvider.overrideWith((ref) {
            return AsyncValue.data(
              VideoFeedState(videos: mockVideos, hasMoreContent: false),
            );
          }),
          fetchUserProfileProvider(testUserHex).overrideWith((ref) async {
            return mockProfile;
          }),
          authServiceProvider.overrideWithValue(
            createTestAuthService(testUserHex),
          ),
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      // Start at profile grid view (videoIndex=0)
      c
          .read(goRouterProvider)
          .go(ProfileScreenRouter.pathForIndex(testUserNpub, 0));
      await tester.pumpAndSettle();

      // Verify we're on the grid view
      expect(find.byType(ProfileScreenRouter), findsOneWidget);

      // Debug: check what's visible
      expect(find.byIcon(Icons.grid_on), findsOneWidget); // Grid tab icon

      // Ensure the first tab (grid) is selected - it should be by default but let's be explicit
      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pumpAndSettle();

      // Now find grid items - they use GestureDetector wrapping DecoratedBox with play icon
      final gridItems = find.ancestor(
        of: find.byIcon(Icons.play_circle_filled),
        matching: find.byType(GestureDetector),
      );

      // If no items found, dump the widget tree for debugging
      if (gridItems.evaluate().isEmpty) {
        debugDumpApp();
        fail('No grid items found with play icons');
      }

      // Tap the third grid item (index 2)
      await tester.tap(gridItems.at(2));
      await tester.pumpAndSettle();

      // Verify route changed to /profile/:npub/3 (URL is 1-based: gridIndex 2 → urlIndex 3)
      final router = c.read(goRouterProvider);
      expect(
        router.routeInformationProvider.value.uri.path,
        ProfileScreenRouter.pathForIndex(testUserNpub, 3),
      );

      // Verify active video is now video at list index 2 (urlIndex 3 - 1 = 2)
      expect(c.read(activeVideoIdProvider), 'video2');

      // Verify VideoFeedItem for video2 is now rendered
      final videoItem = tester.widget<VideoFeedItem>(
        find.byType(VideoFeedItem).first,
      );
      expect(videoItem.video.id, 'video2');
      expect(videoItem.index, 2); // List index should be 2
    });

    testWidgets('Own profile video shows author name (not "Loading...")', (
      tester,
    ) async {
      final c = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          videosForProfileRouteProvider.overrideWith((ref) {
            return AsyncValue.data(
              VideoFeedState(videos: mockVideos, hasMoreContent: false),
            );
          }),
          fetchUserProfileProvider(testUserHex).overrideWith((ref) async {
            return mockProfile;
          }),
          authServiceProvider.overrideWithValue(
            createTestAuthService(testUserHex),
          ), // Own profile
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      // Navigate to video at index 1
      c
          .read(goRouterProvider)
          .go(ProfileScreenRouter.pathForIndex(testUserNpub, 1));
      await tester.pumpAndSettle();

      // Verify profile name is shown (not "Loading...")
      expect(find.text('Loading...'), findsNothing);
      expect(find.textContaining('Test User'), findsOneWidget);
    });

    testWidgets(
      'Own profile video shows edit/delete buttons when forceShowOverlay=true',
      (tester) async {
        final c = ProviderContainer(
          overrides: [
            appForegroundProvider.overrideWithValue(
              const AsyncValue.data(true),
            ),
            videosForProfileRouteProvider.overrideWith((ref) {
              return AsyncValue.data(
                VideoFeedState(videos: mockVideos, hasMoreContent: false),
              );
            }),
            fetchUserProfileProvider(testUserHex).overrideWith((ref) async {
              return mockProfile;
            }),
            authServiceProvider.overrideWithValue(
              createTestAuthService(testUserHex),
            ), // Own profile
          ],
        );
        addTearDown(c.dispose);

        await tester.pumpWidget(shell(c));

        // Navigate to own video
        c
            .read(goRouterProvider)
            .go(ProfileScreenRouter.pathForIndex(testUserNpub, 1));
        await tester.pumpAndSettle();

        // Verify VideoFeedItem has forceShowOverlay=true for own profile
        final videoItem = tester.widget<VideoFeedItem>(
          find.byType(VideoFeedItem).first,
        );
        expect(videoItem.forceShowOverlay, isTrue);

        // Verify share menu button is visible (overlay is shown)
        // Note: The actual edit/delete functionality is in ShareVideoMenu widget
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      },
    );

    testWidgets('Video autoplays when navigating from grid to fullscreen', (
      tester,
    ) async {
      final c = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          videosForProfileRouteProvider.overrideWith((ref) {
            return AsyncValue.data(
              VideoFeedState(videos: mockVideos, hasMoreContent: false),
            );
          }),
          fetchUserProfileProvider(testUserHex).overrideWith((ref) async {
            return mockProfile;
          }),
          authServiceProvider.overrideWithValue(
            createTestAuthService(testUserHex),
          ),
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      // Start at grid
      c
          .read(goRouterProvider)
          .go(ProfileScreenRouter.pathForIndex(testUserNpub, 0));
      await tester.pumpAndSettle();

      // Tap grid item - find gesture detectors with play icons (grid items)
      final gridGestureDetectors = find.ancestor(
        of: find.byIcon(Icons.play_circle_filled),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(gridGestureDetectors.at(1)); // Tap second video
      await tester.pumpAndSettle();

      // Verify active video is set (which triggers autoplay)
      expect(c.read(activeVideoIdProvider), 'video1');

      // Verify isVideoActiveProvider returns true for the active video
      expect(c.read(isVideoActiveProvider('video1')), isTrue);
      expect(c.read(isVideoActiveProvider('video0')), isFalse);
    });
    // TODO(any): Fix and re-enable tests
  }, skip: true);

  group('Profile grid pagination', () {
    late _MockBackgroundPublishBloc backgroundPublishBloc;

    setUp(() {
      backgroundPublishBloc = _MockBackgroundPublishBloc();
      when(() => backgroundPublishBloc.state).thenReturn(
        const BackgroundPublishState(),
      );
      whenListen(
        backgroundPublishBloc,
        const Stream<BackgroundPublishState>.empty(),
        initialState: const BackgroundPublishState(),
      );
    });

    testWidgets('scrolling profile grid near bottom requests more videos', (
      tester,
    ) async {
      final videos = List.generate(60, (index) {
        final createdAt = nowUnix - index;
        return VideoEvent(
          id: 'grid-video-$index',
          pubkey: testUserHex,
          createdAt: createdAt,
          content: 'Video $index',
          timestamp: now.subtract(Duration(seconds: index)),
          title: 'Grid Video $index',
          videoUrl: 'https://example.com/v$index.mp4',
        );
      });

      late _TestProfileFeed profileFeed;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              createTestAuthService('someone-else'),
            ),
            profileFeedProvider(testUserHex).overrideWith(() {
              profileFeed = _TestProfileFeed(
                VideoFeedState(
                  videos: videos,
                  hasMoreContent: true,
                ),
              );
              return profileFeed;
            }),
          ],
          child: BlocProvider<BackgroundPublishBloc>.value(
            value: backgroundPublishBloc,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ProfileVideosGrid(
                  videos: videos,
                  userIdHex:
                      '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(profileFeed.loadMoreCallCount, 0);

      await tester.scrollUntilVisible(
        find.bySemanticsLabel('Video thumbnail 60'),
        800,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(profileFeed.loadMoreCallCount, 1);
    });

    testWidgets(
      'nested scroll profile grid triggers loadMore near bottom',
      (tester) async {
        final videos = List.generate(60, (index) {
          final createdAt = nowUnix - index;
          return VideoEvent(
            id: 'nested-video-$index',
            pubkey: testUserHex,
            createdAt: createdAt,
            content: 'Video $index',
            timestamp: now.subtract(Duration(seconds: index)),
            title: 'Nested Video $index',
            videoUrl: 'https://example.com/v$index.mp4',
          );
        });

        late _TestProfileFeed profileFeed;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(
                createTestAuthService('someone-else'),
              ),
              profileFeedProvider(testUserHex).overrideWith(() {
                profileFeed = _TestProfileFeed(
                  VideoFeedState(
                    videos: videos,
                    hasMoreContent: true,
                  ),
                );
                return profileFeed;
              }),
            ],
            child: BlocProvider<BackgroundPublishBloc>.value(
              value: backgroundPublishBloc,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 200, child: Placeholder()),
                      ),
                    ],
                    body: ProfileVideosGrid(
                      videos: videos,
                      userIdHex: testUserHex,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(profileFeed.loadMoreCallCount, 0);

        await tester.scrollUntilVisible(
          find.bySemanticsLabel('Video thumbnail 60'),
          800,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();

        expect(profileFeed.loadMoreCallCount, greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'nested scroll profile grid does not trigger loadMore when hasMoreContent is false',
      (tester) async {
        final videos = List.generate(12, (index) {
          final createdAt = nowUnix - index;
          return VideoEvent(
            id: 'short-video-$index',
            pubkey: testUserHex,
            createdAt: createdAt,
            content: 'Video $index',
            timestamp: now.subtract(Duration(seconds: index)),
            title: 'Short Video $index',
            videoUrl: 'https://example.com/v$index.mp4',
          );
        });

        late _TestProfileFeed profileFeed;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(
                createTestAuthService('someone-else'),
              ),
              profileFeedProvider(testUserHex).overrideWith(() {
                profileFeed = _TestProfileFeed(
                  VideoFeedState(
                    videos: videos,
                    hasMoreContent: false,
                  ),
                );
                return profileFeed;
              }),
            ],
            child: BlocProvider<BackgroundPublishBloc>.value(
              value: backgroundPublishBloc,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 200, child: Placeholder()),
                      ),
                    ],
                    body: ProfileVideosGrid(
                      videos: videos,
                      userIdHex: testUserHex,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Scroll to the end
        final scrollable = find.byType(Scrollable).last;
        await tester.drag(scrollable, const Offset(0, -3000));
        await tester.pump();

        expect(profileFeed.loadMoreCallCount, 0);
      },
    );
  });

  group('Profile grid fullscreen args', () {
    late _MockBackgroundPublishBloc backgroundPublishBloc;

    setUp(() {
      backgroundPublishBloc = _MockBackgroundPublishBloc();
      when(() => backgroundPublishBloc.state).thenReturn(
        const BackgroundPublishState(),
      );
      whenListen(
        backgroundPublishBloc,
        const Stream<BackgroundPublishState>.empty(),
        initialState: const BackgroundPublishState(),
      );
    });

    testWidgets('passes a live hasMoreStream to fullscreen navigation', (
      tester,
    ) async {
      PooledFullscreenVideoFeedArgs? capturedArgs;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: ProfileVideosGrid(
                videos: mockVideos,
                userIdHex: testUserHex,
              ),
            ),
          ),
          GoRoute(
            path: PooledFullscreenVideoFeedScreen.path,
            builder: (context, state) {
              capturedArgs = state.extra! as PooledFullscreenVideoFeedArgs;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              createTestAuthService('someone-else'),
            ),
            profileFeedProvider(testUserHex).overrideWith(
              () => _TestProfileFeed(
                VideoFeedState(videos: mockVideos, hasMoreContent: true),
              ),
            ),
          ],
          child: BlocProvider<BackgroundPublishBloc>.value(
            value: backgroundPublishBloc,
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Video thumbnail 1'));
      await tester.pumpAndSettle();

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.hasMoreStream, isNotNull);
    });
  });
}
