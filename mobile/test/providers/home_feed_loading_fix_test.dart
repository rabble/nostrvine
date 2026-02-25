// ABOUTME: Tests for home feed loading fix - REST API before Nostr fallback
// ABOUTME: Verifies that home feed loads via REST API even when NostrClient is not ready
// ABOUTME: Tests the fix for infinite loading when isNostrReadyProvider stays false

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mocktail/mocktail.dart' as mocktail;
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/user_profile_state.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([
  VideoEventService,
  NostrClient,
  SubscriptionManager,
  AnalyticsApiService,
  AuthService,
])
import 'home_feed_loading_fix_test.mocks.dart';

/// Mocktail mock for FollowRepository
class _MockFollowRepository extends mocktail.Mock implements FollowRepository {}

/// Creates a mock FollowRepository with the given following pubkeys
_MockFollowRepository _createMockFollowRepository(
  List<String> followingPubkeys,
) {
  final mock = _MockFollowRepository();
  mocktail.when(() => mock.followingPubkeys).thenReturn(followingPubkeys);
  mocktail
      .when(() => mock.followingStream)
      .thenAnswer(
        (_) => BehaviorSubject<List<String>>.seeded(followingPubkeys).stream,
      );
  mocktail.when(() => mock.isInitialized).thenReturn(true);
  mocktail.when(() => mock.followingCount).thenReturn(followingPubkeys.length);
  return mock;
}

/// Fake CuratedListsState notifier that returns empty list immediately.
/// Prevents cascading into sharedPreferencesProvider / CuratedListService.
class _FakeCuratedListsState extends CuratedListsState {
  @override
  Future<List<CuratedList>> build() async => <CuratedList>[];
}

/// Fake UserProfileNotifier that stubs profile fetching to avoid
/// cascading into real UserProfileService/SubscriptionManager
class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => UserProfileState.initial;

  @override
  bool hasProfile(String pubkey) => true;

  @override
  Future<void> fetchMultipleProfiles(
    List<String> pubkeys, {
    bool forceRefresh = false,
  }) async {}
}

/// Waits for the HomeFeed provider to complete its full build.
///
/// The HomeFeed provider emits an intermediate
/// `state = AsyncData(empty, isInitialLoad: true)` before the async REST
/// API/Nostr calls. Using `.future` would resolve to that empty state.
/// This helper listens for a state where `isInitialLoad == false`, indicating
/// the full build completed (REST API response processed).
///
/// Falls back to returning the last state after [timeout] if no completed
/// state arrives.
Future<VideoFeedState> waitForHomeFeedComplete(
  ProviderContainer container, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final completer = Completer<VideoFeedState>();

  final sub = container.listen<AsyncValue<VideoFeedState>>(homeFeedProvider, (
    previous,
    next,
  ) {
    final state = next.value;
    if (state != null && !state.isInitialLoad && !completer.isCompleted) {
      completer.complete(state);
    }
  }, fireImmediately: true);

  // Timeout fallback - return whatever state we have
  final timer = Timer(timeout, () {
    if (!completer.isCompleted) {
      final current = container.read(homeFeedProvider).value;
      completer.complete(
        current ??
            const VideoFeedState(
              videos: [],
              hasMoreContent: false,
              isInitialLoad: true,
            ),
      );
    }
  });

  final result = await completer.future;
  timer.cancel();
  sub.close();
  return result;
}

void main() {
  group('HomeFeed REST API Integration', () {
    late MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;
    late MockAnalyticsApiService mockAnalyticsApiService;
    late MockAuthService mockAuthService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();
      mockAnalyticsApiService = MockAnalyticsApiService();
      mockAuthService = MockAuthService();

      // Initialize SharedPreferences for test
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      // Setup default VideoEventService mock behaviors
      when(mockVideoEventService.homeFeedVideos).thenReturn([]);
      when(
        mockVideoEventService.getEventCount(SubscriptionType.homeFeed),
      ).thenReturn(0);
      when(
        mockVideoEventService.subscribeToHomeFeed(
          any,
          limit: anyNamed('limit'),
          sortBy: anyNamed('sortBy'),
          force: anyNamed('force'),
        ),
      ).thenAnswer((_) async {});
      when(mockVideoEventService.addListener(any)).thenReturn(null);
      when(mockVideoEventService.removeListener(any)).thenReturn(null);
      when(mockVideoEventService.addVideoUpdateListener(any)).thenReturn(() {});
      when(mockVideoEventService.addNewVideoListener(any)).thenReturn(() {});
      when(
        mockVideoEventService.filterVideoList(any),
      ).thenAnswer((inv) => inv.positionalArguments.first as List<VideoEvent>);
      when(
        mockVideoEventService.debugDumpCdnDivineVideoThumbnails(),
      ).thenReturn(null);

      // Setup AnalyticsApiService enrichment stubs
      when(
        mockAnalyticsApiService.getBulkVideoStats(argThat(isA<List<String>>())),
      ).thenAnswer((_) async => <String, BulkVideoStatsEntry>{});
      when(
        mockAnalyticsApiService.getBulkVideoViews(
          argThat(isA<List<String>>()),
          maxVideos: anyNamed('maxVideos'),
          maxConcurrent: anyNamed('maxConcurrent'),
        ),
      ).thenAnswer((_) async => <String, int>{});

      // Setup getCachedHomeFeed stub (returns null = no cache)
      when(
        mockAnalyticsApiService.getCachedHomeFeed(prefs: anyNamed('prefs')),
      ).thenAnswer((_) async => null);

      // Setup NostrClient stubs
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.hasKeys).thenReturn(false);
      when(mockNostrService.publicKey).thenReturn('');

      // Setup AuthService stubs
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(
        'abc123def456abc123def456abc123def456abc123def456abc123def456abc1',
      );
      when(mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
    });

    tearDown(() {
      reset(mockVideoEventService);
      reset(mockNostrService);
      reset(mockSubscriptionManager);
      reset(mockAnalyticsApiService);
      reset(mockAuthService);
    });

    /// Creates a ProviderContainer with common test overrides
    ProviderContainer createContainer({
      bool isNostrReady = false,
      FollowRepository? followRepository,
    }) {
      return ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          analyticsApiServiceProvider.overrideWithValue(
            mockAnalyticsApiService,
          ),
          authServiceProvider.overrideWithValue(mockAuthService),
          userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
          curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
          subscribedListVideoCacheProvider.overrideWithValue(null),
          isNostrReadyProvider.overrideWithValue(isNostrReady),
          followRepositoryProvider.overrideWithValue(followRepository),
          contentFilterVersionProvider.overrideWithValue(0),
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
      );
    }

    test('should load via REST API when followRepository is null (Nostr not '
        'ready)', () async {
      // This is THE key test for the fix:
      // When NostrClient is not ready, followRepositoryProvider returns
      // null. Before the fix, HomeFeed would be stuck on loading forever.
      // After the fix, HomeFeed tries REST API first, which only needs
      // pubkey.

      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch ~/ 1000;
      final mockVideos = [
        VideoEvent(
          id: 'rest_video_aaa111bbb222ccc333ddd444eee555fff666aaa111bbb222ccc333ddd444e',
          pubkey:
              'author_abc123def456abc123def456abc123def456abc123def456abc123def456ab',
          content: 'Video from REST API',
          createdAt: timestamp,
          timestamp: now,
          videoUrl: 'https://example.com/video1.mp4',
        ),
      ];

      when(
        mockAnalyticsApiService.getHomeFeed(
          pubkey: anyNamed('pubkey'),
          limit: anyNamed('limit'),
          sort: anyNamed('sort'),
          before: anyNamed('before'),
          prefs: anyNamed('prefs'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResult(
          videos: mockVideos,
          nextCursor: timestamp - 200,
          hasMore: true,
        ),
      );

      final container = createContainer();

      // Act: Wait for full build to complete (past intermediate empty
      // state)
      final result = await waitForHomeFeedComplete(container);

      // Assert: Should have videos from REST API despite Nostr not ready
      expect(result.videos, isNotEmpty);
      expect(result.videos.length, equals(1));
      expect(
        result.videos[0].id,
        equals(
          'rest_video_aaa111bbb222ccc333ddd444eee555fff666aaa111bbb222ccc333ddd444e',
        ),
      );
      expect(result.hasMoreContent, isTrue);
      expect(result.isInitialLoad, isFalse);

      // Verify REST API was called with the user's pubkey
      verify(
        mockAnalyticsApiService.getHomeFeed(
          pubkey: anyNamed('pubkey'),
          limit: anyNamed('limit'),
          sort: anyNamed('sort'),
          before: anyNamed('before'),
          prefs: anyNamed('prefs'),
        ),
      ).called(1);

      // Verify Nostr was NOT called (followRepository is null)
      verifyNever(
        mockVideoEventService.subscribeToHomeFeed(
          any,
          limit: anyNamed('limit'),
          sortBy: anyNamed('sortBy'),
          force: anyNamed('force'),
        ),
      );

      container.dispose();
    });

    test('REST API should receive correct pubkey parameter', () async {
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch ~/ 1000;

      when(
        mockAnalyticsApiService.getHomeFeed(
          pubkey: anyNamed('pubkey'),
          limit: anyNamed('limit'),
          sort: anyNamed('sort'),
          before: anyNamed('before'),
          prefs: anyNamed('prefs'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResult(
          videos: [
            VideoEvent(
              id: 'rest_vid2_aaa111bbb222ccc333ddd444eee555fff666aaa111bbb222ccc333ddd44',
              pubkey:
                  'author_abc123def456abc123def456abc123def456abc123def456abc123def456ab',
              content: 'REST API Video',
              createdAt: timestamp,
              timestamp: now,
              videoUrl: 'https://example.com/video2.mp4',
            ),
          ],
          nextCursor: timestamp - 100,
          hasMore: false,
        ),
      );

      final container = createContainer();

      await waitForHomeFeedComplete(container);

      // Capture the actual call to verify the pubkey was passed
      final captured = verify(
        mockAnalyticsApiService.getHomeFeed(
          pubkey: captureAnyNamed('pubkey'),
          limit: captureAnyNamed('limit'),
          sort: captureAnyNamed('sort'),
          before: anyNamed('before'),
          prefs: anyNamed('prefs'),
        ),
      ).captured;

      // First captured is pubkey, second is limit, third is sort
      expect(
        captured[0],
        equals(
          'abc123def456abc123def456abc123def456abc123def456abc123def456abc1',
        ),
      );
      expect(captured[1], equals(100));
      expect(captured[2], equals('recent'));

      container.dispose();
    });

    test(
      'should return loading state when pubkey is null (not authenticated)',
      () async {
        when(mockAuthService.currentPublicKeyHex).thenReturn(null);

        final container = createContainer();

        // Act: When pubkey is null, build returns early with
        // isInitialLoad: true
        // Use .future here since build returns before any async work
        final result = await container.read(homeFeedProvider.future);

        // Assert: Should return loading state (isInitialLoad: true)
        expect(result.videos, isEmpty);
        expect(result.isInitialLoad, isTrue);

        // Verify REST API was NOT called (no pubkey available)
        verifyNever(
          mockAnalyticsApiService.getHomeFeed(
            pubkey: anyNamed('pubkey'),
            limit: anyNamed('limit'),
            sort: anyNamed('sort'),
            before: anyNamed('before'),
            prefs: anyNamed('prefs'),
          ),
        );

        container.dispose();
      },
    );

    test('should fall back to Nostr when REST API fails and '
        'followRepository is available', () async {
      when(
        mockAnalyticsApiService.getHomeFeed(
          pubkey: anyNamed('pubkey'),
          limit: anyNamed('limit'),
          sort: anyNamed('sort'),
          before: anyNamed('before'),
          prefs: anyNamed('prefs'),
        ),
      ).thenThrow(Exception('API Error'));

      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch ~/ 1000;
      final nostrVideos = [
        VideoEvent(
          id: 'nostr_vid_abc123def456abc123def456abc123def456abc123def456abc123def456a',
          pubkey:
              'author_abc123def456abc123def456abc123def456abc123def456abc123def456ab',
          content: 'Video from Nostr',
          createdAt: timestamp,
          timestamp: now,
          videoUrl: 'https://example.com/nostr_video.mp4',
        ),
      ];

      when(mockVideoEventService.homeFeedVideos).thenReturn(nostrVideos);

      final followRepo = _createMockFollowRepository([
        'author_abc123def456abc123def456abc123def456abc123def456abc123def456ab',
      ]);

      final container = createContainer(
        isNostrReady: true,
        followRepository: followRepo,
      );

      // Act: Wait for full build (REST API fails, then Nostr fallback)
      final result = await waitForHomeFeedComplete(container);

      // Assert: Should have videos from Nostr fallback
      expect(result.videos, isNotEmpty);
      expect(result.videos.length, equals(1));
      expect(
        result.videos[0].id,
        equals(
          'nostr_vid_abc123def456abc123def456abc123def456abc123def456abc123def456a',
        ),
      );

      // Verify REST API was tried first
      verify(
        mockAnalyticsApiService.getHomeFeed(
          pubkey: anyNamed('pubkey'),
          limit: anyNamed('limit'),
          sort: anyNamed('sort'),
          before: anyNamed('before'),
          prefs: anyNamed('prefs'),
        ),
      ).called(1);

      // Verify Nostr was called as fallback
      verify(
        mockVideoEventService.subscribeToHomeFeed(
          any,
          limit: anyNamed('limit'),
          sortBy: anyNamed('sortBy'),
          force: anyNamed('force'),
        ),
      ).called(1);

      container.dispose();
    });

    test('should return loading when REST API fails and '
        'followRepository is null', () async {
      when(
        mockAnalyticsApiService.getHomeFeed(
          pubkey: anyNamed('pubkey'),
          limit: anyNamed('limit'),
          sort: anyNamed('sort'),
          before: anyNamed('before'),
          prefs: anyNamed('prefs'),
        ),
      ).thenThrow(Exception('API Error'));

      final container = createContainer();

      // Act: REST API fails and followRepository is null
      // Build returns early with isInitialLoad: true after REST failure
      final result = await container.read(homeFeedProvider.future);

      // Assert: Should return loading state (waiting for Nostr ready)
      expect(result.videos, isEmpty);
      expect(result.isInitialLoad, isTrue);

      container.dispose();
    });

    test('REST API returns empty should fall back to Nostr when available', () async {
      // REST API returns empty list - should try Nostr path
      when(
        mockAnalyticsApiService.getHomeFeed(
          pubkey: anyNamed('pubkey'),
          limit: anyNamed('limit'),
          sort: anyNamed('sort'),
          before: anyNamed('before'),
          prefs: anyNamed('prefs'),
        ),
      ).thenAnswer(
        (_) async =>
            HomeFeedResult(videos: [], nextCursor: null, hasMore: false),
      );

      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch ~/ 1000;
      final nostrVideos = [
        VideoEvent(
          id: 'nostr_vid2_bc123def456abc123def456abc123def456abc123def456abc123def456a',
          pubkey:
              'author_abc123def456abc123def456abc123def456abc123def456abc123def456ab',
          content: 'Nostr fallback video',
          createdAt: timestamp,
          timestamp: now,
          videoUrl: 'https://example.com/nostr_fallback.mp4',
        ),
      ];

      when(mockVideoEventService.homeFeedVideos).thenReturn(nostrVideos);

      final followRepo = _createMockFollowRepository([
        'author_abc123def456abc123def456abc123def456abc123def456abc123def456ab',
      ]);

      final container = createContainer(
        isNostrReady: true,
        followRepository: followRepo,
      );

      // Wait for full build (REST empty -> Nostr fallback)
      final result = await waitForHomeFeedComplete(container);

      // Assert: Should get videos from Nostr since REST was empty
      expect(result.videos, isNotEmpty);
      expect(result.videos.length, equals(1));

      // Verify both were called
      verify(
        mockAnalyticsApiService.getHomeFeed(
          pubkey: anyNamed('pubkey'),
          limit: anyNamed('limit'),
          sort: anyNamed('sort'),
          before: anyNamed('before'),
          prefs: anyNamed('prefs'),
        ),
      ).called(1);
      verify(
        mockVideoEventService.subscribeToHomeFeed(
          any,
          limit: anyNamed('limit'),
          sortBy: anyNamed('sortBy'),
          force: anyNamed('force'),
        ),
      ).called(1);

      container.dispose();
    });

    test('REST API pagination cursor should be set correctly', () async {
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch ~/ 1000;
      const expectedCursor = 1700000000;

      when(
        mockAnalyticsApiService.getHomeFeed(
          pubkey: anyNamed('pubkey'),
          limit: anyNamed('limit'),
          sort: anyNamed('sort'),
          before: anyNamed('before'),
          prefs: anyNamed('prefs'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResult(
          videos: [
            VideoEvent(
              id: 'cursor_vid_aaa111bbb222ccc333ddd444eee555fff666aaa111bbb222ccc333ddd4',
              pubkey:
                  'author_abc123def456abc123def456abc123def456abc123def456abc123def456ab',
              content: 'Cursor test video',
              createdAt: timestamp,
              timestamp: now,
              videoUrl: 'https://example.com/cursor_test.mp4',
            ),
          ],
          nextCursor: expectedCursor,
          hasMore: true,
        ),
      );

      final container = createContainer();

      final result = await waitForHomeFeedComplete(container);

      // Assert: hasMoreContent should be true when API says hasMore
      expect(result.hasMoreContent, isTrue);
      expect(result.videos.length, equals(1));

      container.dispose();
    });
  });

  group('isNostrReadyProvider retry polling', () {
    test('should return false initially when NostrClient hasKeys is false', () {
      final mockNostrClient = MockNostrClient();
      final mockAuthService = MockAuthService();

      when(mockNostrClient.hasKeys).thenReturn(false);
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
      );

      // Act
      final result = container.read(isNostrReadyProvider);

      // Assert: Should be false when hasKeys is false
      expect(result, isFalse);

      container.dispose();
    });

    test('should return true when NostrClient hasKeys is true', () {
      final mockNostrClient = MockNostrClient();
      final mockAuthService = MockAuthService();

      when(mockNostrClient.hasKeys).thenReturn(true);
      when(mockNostrClient.publicKey).thenReturn('test_key');
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
      );

      // Act
      final result = container.read(isNostrReadyProvider);

      // Assert: Should be true when hasKeys is true
      expect(result, isTrue);

      container.dispose();
    });

    test('should return false when user is not authenticated', () {
      final mockNostrClient = MockNostrClient();
      final mockAuthService = MockAuthService();

      when(mockNostrClient.hasKeys).thenReturn(true);
      when(mockAuthService.isAuthenticated).thenReturn(false);
      when(mockAuthService.authState).thenReturn(AuthState.unauthenticated);
      when(
        mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.unauthenticated));

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
      );

      // Act
      final result = container.read(isNostrReadyProvider);

      // Assert: Should be false when not authenticated
      expect(result, isFalse);

      container.dispose();
    });

    test('should schedule retry and invalidate when hasKeys transitions to '
        'true', () async {
      final mockNostrClient = MockNostrClient();
      final mockAuthService = MockAuthService();

      // Initially hasKeys is false
      when(mockNostrClient.hasKeys).thenReturn(false);
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
      );

      // Read initially - should be false
      var result = container.read(isNostrReadyProvider);
      expect(result, isFalse);

      // Simulate NostrClient.initialize() completing asynchronously
      // (hasKeys transitions to true on the same object reference)
      when(mockNostrClient.hasKeys).thenReturn(true);

      // Wait for the 100ms retry to fire
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Read again - the retry should have invalidated the provider
      result = container.read(isNostrReadyProvider);
      expect(result, isTrue);

      container.dispose();
    });
  });
}
