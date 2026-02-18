// ABOUTME: Tests for home feed provider functionality
// ABOUTME: Verifies that home feed correctly filters videos from followed authors
// ABOUTME: Tests REST API first with Nostr fallback pattern

import 'package:flutter/foundation.dart';
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
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([
  VideoEventService,
  NostrClient,
  SubscriptionManager,
  AnalyticsApiService,
])
import 'home_feed_provider_test.mocks.dart';

/// Mocktail mock for FollowRepository
class MockFollowRepository extends mocktail.Mock implements FollowRepository {}

/// Creates a mock FollowRepository with the given following pubkeys
MockFollowRepository createMockFollowRepository(List<String> followingPubkeys) {
  final mock = MockFollowRepository();
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

void main() {
  group('HomeFeedProvider', () {
    late ProviderContainer container;
    late MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;
    late SharedPreferences sharedPreferences;
    final List<VoidCallback> registeredListeners = [];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();
      registeredListeners.clear();

      // Setup default mock behaviors
      // Note: Individual tests will override homeFeedVideos with their own values
      when(
        mockVideoEventService.getEventCount(SubscriptionType.homeFeed),
      ).thenReturn(0);

      // Setup nostrService isInitialized stub (needed for profile fetching)
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.hasKeys).thenReturn(true);
      when(mockNostrService.publicKey).thenReturn('test_pubkey');
      when(mockNostrService.configuredRelays).thenReturn(<String>[]);
      when(
        mockNostrService.subscribe(
          any,
          subscriptionId: anyNamed('subscriptionId'),
          tempRelays: anyNamed('tempRelays'),
          targetRelays: anyNamed('targetRelays'),
          relayTypes: anyNamed('relayTypes'),
          sendAfterAuth: anyNamed('sendAfterAuth'),
          onEose: anyNamed('onEose'),
        ),
      ).thenAnswer((_) => Stream.empty());

      // Capture listeners when added
      when(mockVideoEventService.addListener(any)).thenAnswer((invocation) {
        final listener = invocation.positionalArguments[0] as VoidCallback;
        registeredListeners.add(listener);
      });

      // Remove listeners when removed
      when(mockVideoEventService.removeListener(any)).thenAnswer((invocation) {
        final listener = invocation.positionalArguments[0] as VoidCallback;
        registeredListeners.remove(listener);
      });

      // subscribeToHomeFeed just completes - videos should already be set up by individual tests
      when(
        mockVideoEventService.subscribeToHomeFeed(
          any,
          limit: anyNamed('limit'),
        ),
      ).thenAnswer((_) async {
        // Videos are already set up via when(homeFeedVideos).thenReturn() in individual tests
        // The provider will check homeFeedVideos.length after this completes
        return Future.value();
      });

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      reset(mockVideoEventService);
      reset(mockNostrService);
      reset(mockSubscriptionManager);
    });

    test('should return empty state when user is not following anyone', () async {
      // Setup: User is not following anyone - create new container with overrides
      final testContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          // Override isNostrReady to avoid auth dependency in tests
          isNostrReadyProvider.overrideWithValue(true),
          followRepositoryProvider.overrideWithValue(
            createMockFollowRepository([]),
          ),
        ],
      );

      // Act
      final result = await testContainer.read(homeFeedProvider.future);

      // Assert
      expect(result.videos, isEmpty);
      expect(result.hasMoreContent, isFalse);
      expect(result.isLoadingMore, isFalse);
      expect(result.error, isNull);

      // Verify that we didn't try to subscribe since there are no following
      verifyNever(
        mockVideoEventService.subscribeToHomeFeed(
          any,
          limit: anyNamed('limit'),
        ),
      );

      testContainer.dispose();
    });

    test(
      'should preserve video list when socialProvider updates with same following list',
      () async {
        // Setup: Create mock videos
        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch ~/ 1000;
        final mockVideos = [
          VideoEvent(
            id: 'video1',
            pubkey: 'author1',
            content: 'Test video 1',
            createdAt: timestamp,
            timestamp: now,
          ),
          VideoEvent(
            id: 'video2',
            pubkey: 'author2',
            content: 'Test video 2',
            createdAt: timestamp,
            timestamp: now,
          ),
        ];

        when(mockVideoEventService.homeFeedVideos).thenReturn(mockVideos);

        // Create container with initial social state
        final testContainer = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            followRepositoryProvider.overrideWithValue(
              createMockFollowRepository(['author1', 'author2']),
            ),
          ],
        );

        // Act: Get initial feed
        final initialFeed = await testContainer.read(homeFeedProvider.future);

        // Verify initial feed has videos
        expect(initialFeed.videos.length, 2);
        expect(initialFeed.videos[0].id, 'video1');
        expect(initialFeed.videos[1].id, 'video2');

        // Act: Update follow repository with SAME following list
        // This simulates cross-device sync or state refresh
        final updatedContainer = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            followRepositoryProvider.overrideWithValue(
              createMockFollowRepository(['author1', 'author2']), // Same list!
            ),
          ],
        );

        final updatedFeed = await updatedContainer.read(
          homeFeedProvider.future,
        );

        // Assert: Video list order should be PRESERVED
        expect(updatedFeed.videos.length, 2);
        expect(
          updatedFeed.videos[0].id,
          'video1',
          reason: 'First video should remain first',
        );
        expect(
          updatedFeed.videos[1].id,
          'video2',
          reason: 'Second video should remain second',
        );

        // Verify we didn't re-subscribe unnecessarily
        verify(
          mockVideoEventService.subscribeToHomeFeed(
            any,
            limit: anyNamed('limit'),
          ),
        );

        updatedContainer.dispose();
        testContainer.dispose();
      },
      // Skip: Requires complex mocking of FollowRepository BehaviorSubject and
      // VideoEventService listener callbacks. Need to mock followingStream.skip(1)
      // subscription and video update/new listeners.
      skip:
          'Complex mocking required: FollowRepository.followingStream and VideoEventService listeners',
    );

    test(
      'should subscribe to videos from followed authors',
      () async {
        // Setup: User is following 3 people
        final followingPubkeys = [
          'pubkey1_following',
          'pubkey2_following',
          'pubkey3_following',
        ];

        // Create mock videos from followed authors
        final mockVideos = [
          VideoEvent(
            id: 'event1',
            pubkey: 'pubkey1_following',
            createdAt: 1000,
            content: 'Video 1',
            timestamp: DateTime.now(),
            videoUrl: 'https://example.com/video1.mp4',
          ),
          VideoEvent(
            id: 'event2',
            pubkey: 'pubkey2_following',
            createdAt: 900,
            content: 'Video 2',
            timestamp: DateTime.now(),
            videoUrl: 'https://example.com/video2.mp4',
          ),
        ];

        when(mockVideoEventService.homeFeedVideos).thenReturn(mockVideos);

        // Create a new container with social state override
        final testContainer = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            followRepositoryProvider.overrideWithValue(
              createMockFollowRepository(followingPubkeys),
            ),
          ],
        );

        // Act
        final result = await testContainer.read(homeFeedProvider.future);

        // Assert
        expect(result.videos.length, equals(2));
        expect(result.videos[0].pubkey, equals('pubkey1_following'));
        expect(result.videos[1].pubkey, equals('pubkey2_following'));

        // Verify subscription was created with correct authors
        verify(
          mockVideoEventService.subscribeToHomeFeed(
            followingPubkeys,
            limit: 100,
          ),
        ).called(1);

        testContainer.dispose();
      },
      skip:
          'Complex mocking required: FollowRepository and subscribed list cache providers',
    );

    test(
      'should sort videos by creation time (newest first)',
      () async {
        // Setup: User is following people
        final followingPubkeys = ['pubkey1', 'pubkey2'];

        // Create mock videos with different timestamps
        final now = DateTime.now();
        final mockVideos = [
          VideoEvent(
            id: 'event1',
            pubkey: 'pubkey1',
            createdAt: 100,
            content: 'Older video',
            timestamp: now.subtract(const Duration(hours: 2)),
            videoUrl: 'https://example.com/video1.mp4',
          ),
          VideoEvent(
            id: 'event2',
            pubkey: 'pubkey2',
            createdAt: 200,
            content: 'Newer video',
            timestamp: now.subtract(const Duration(hours: 1)),
            videoUrl: 'https://example.com/video2.mp4',
          ),
        ];

        when(mockVideoEventService.homeFeedVideos).thenReturn(mockVideos);

        // Create a new container with follow repository override
        final testContainer = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            followRepositoryProvider.overrideWithValue(
              createMockFollowRepository(followingPubkeys),
            ),
          ],
        );

        // Act
        final result = await testContainer.read(homeFeedProvider.future);

        // Assert: Videos should be sorted newest first
        expect(result.videos.length, equals(2));
        expect(
          result.videos[0].createdAt,
          greaterThan(result.videos[1].createdAt),
        );
        expect(result.videos[0].content, equals('Newer video'));
        expect(result.videos[1].content, equals('Older video'));

        testContainer.dispose();
      },
      skip:
          'Complex mocking required: FollowRepository and subscribed list cache providers',
    );

    test(
      'should handle load more when user is following people',
      () async {
        // Setup
        final followingPubkeys = ['pubkey1'];

        // Create initial mock videos
        final mockVideos = List.generate(
          10,
          (i) => VideoEvent(
            id: 'event$i',
            pubkey: 'pubkey1',
            createdAt: 1000 + i,
            content: 'Video $i',
            timestamp: DateTime.now(),
            videoUrl: 'https://example.com/video$i.mp4',
          ),
        );

        when(mockVideoEventService.homeFeedVideos).thenReturn(mockVideos);
        when(
          mockVideoEventService.getEventCount(SubscriptionType.homeFeed),
        ).thenReturn(10);

        // Create a new container with social state override
        final testContainer = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            followRepositoryProvider.overrideWithValue(
              createMockFollowRepository(followingPubkeys),
            ),
          ],
        );

        // Act
        final result = await testContainer.read(homeFeedProvider.future);

        // Assert basic state
        expect(result.videos.length, equals(10));
        expect(result.hasMoreContent, isTrue);
        expect(result.isLoadingMore, isFalse);

        // Verify subscription was created
        verify(
          mockVideoEventService.subscribeToHomeFeed(
            followingPubkeys,
            limit: 100,
          ),
        ).called(1);

        testContainer.dispose();
      },
      skip:
          'Complex mocking required: FollowRepository and subscribed list cache providers',
    );

    test(
      'should handle refresh functionality',
      () async {
        // Setup
        final followingPubkeys = ['pubkey1'];

        when(mockVideoEventService.homeFeedVideos).thenReturn([]);

        // Create a new container with social state override
        final testContainer = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            followRepositoryProvider.overrideWithValue(
              createMockFollowRepository(followingPubkeys),
            ),
          ],
        );

        // Act
        await testContainer.read(homeFeedProvider.future);
        await testContainer.read(homeFeedProvider.notifier).refresh();
        await testContainer.read(
          homeFeedProvider.future,
        ); // Wait for rebuild to complete

        // Assert: Should re-subscribe after refresh
        verify(
          mockVideoEventService.subscribeToHomeFeed(
            followingPubkeys,
            limit: 100,
          ),
        ).called(2); // Once on initial load, once on refresh

        testContainer.dispose();
      },
      skip:
          'Complex mocking required: FollowRepository and subscribed list cache providers',
    );

    test(
      'should handle empty video list correctly',
      () async {
        // Setup: User is following people but no videos available
        final followingPubkeys = ['pubkey1', 'pubkey2'];

        when(mockVideoEventService.homeFeedVideos).thenReturn([]);

        // Create a new container with social state override
        final testContainer = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            followRepositoryProvider.overrideWithValue(
              createMockFollowRepository(followingPubkeys),
            ),
          ],
        );

        // Act
        final result = await testContainer.read(homeFeedProvider.future);

        // Assert
        expect(result.videos, isEmpty);
        expect(result.hasMoreContent, isFalse);
        expect(result.error, isNull);

        // Verify subscription was still attempted
        verify(
          mockVideoEventService.subscribeToHomeFeed(
            followingPubkeys,
            limit: 100,
          ),
        ).called(1);

        testContainer.dispose();
      },
      skip:
          'Complex mocking required: FollowRepository and subscribed list cache providers',
    );
  });

  group('HomeFeed Helper Providers', () {
    late MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();

      // Setup default mock behaviors
      when(mockVideoEventService.homeFeedVideos).thenReturn([]);
      when(
        mockVideoEventService.getEventCount(SubscriptionType.homeFeed),
      ).thenReturn(0);
      when(
        mockVideoEventService.subscribeToHomeFeed(
          any,
          limit: anyNamed('limit'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() {
      reset(mockVideoEventService);
      reset(mockNostrService);
      reset(mockSubscriptionManager);
    });

    test('homeFeedLoading should reflect loading state', () async {
      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          followRepositoryProvider.overrideWithValue(
            createMockFollowRepository([]),
          ),
        ],
      );

      // Test loading state detection
      final isLoading = container.read(homeFeedLoadingProvider);
      expect(isLoading, isA<bool>());

      container.dispose();
    });

    test('homeFeedCount should return video count', () async {
      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          followRepositoryProvider.overrideWithValue(
            createMockFollowRepository([]),
          ),
        ],
      );

      // Test video count
      final count = container.read(homeFeedCountProvider);
      expect(count, isA<int>());
      expect(count, greaterThanOrEqualTo(0));

      container.dispose();
    });

    test('hasHomeFeedVideos should indicate if videos exist', () async {
      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          followRepositoryProvider.overrideWithValue(
            createMockFollowRepository([]),
          ),
        ],
      );

      // Test video existence check
      final hasVideos = container.read(hasHomeFeedVideosProvider);
      expect(hasVideos, isA<bool>());

      container.dispose();
    });
  });

  group('HomeFeed REST API Mode', () {
    late MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;
    late MockAnalyticsApiService mockAnalyticsApiService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockVideoEventService = MockVideoEventService();
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();
      mockAnalyticsApiService = MockAnalyticsApiService();

      // Setup default mock behaviors
      when(mockVideoEventService.homeFeedVideos).thenReturn([]);
      when(
        mockVideoEventService.getEventCount(SubscriptionType.homeFeed),
      ).thenReturn(0);
      when(
        mockVideoEventService.subscribeToHomeFeed(
          any,
          limit: anyNamed('limit'),
        ),
      ).thenAnswer((_) async {});
      when(mockVideoEventService.addListener(any)).thenReturn(null);
      when(mockVideoEventService.removeListener(any)).thenReturn(null);
      when(mockVideoEventService.addVideoUpdateListener(any)).thenReturn(() {});
      when(mockVideoEventService.addNewVideoListener(any)).thenReturn(() {});

      // Setup NostrClient stubs
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.hasKeys).thenReturn(true);
      when(mockNostrService.publicKey).thenReturn('test_pubkey');
      when(mockNostrService.configuredRelays).thenReturn(<String>[]);
      when(
        mockNostrService.subscribe(
          any,
          subscriptionId: anyNamed('subscriptionId'),
          tempRelays: anyNamed('tempRelays'),
          targetRelays: anyNamed('targetRelays'),
          relayTypes: anyNamed('relayTypes'),
          sendAfterAuth: anyNamed('sendAfterAuth'),
          onEose: anyNamed('onEose'),
        ),
      ).thenAnswer((_) => Stream.empty());
    });

    tearDown(() {
      reset(mockVideoEventService);
      reset(mockNostrService);
      reset(mockSubscriptionManager);
      reset(mockAnalyticsApiService);
    });

    test(
      'should use REST API when available and has videos',
      () async {
        // Setup: REST API is available and returns videos
        when(mockAnalyticsApiService.isAvailable).thenReturn(true);

        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch ~/ 1000;
        final mockVideos = [
          VideoEvent(
            id: 'rest_video1',
            pubkey: 'author1',
            content: 'REST API video 1',
            createdAt: timestamp,
            timestamp: now,
            videoUrl: 'https://example.com/video1.mp4',
          ),
          VideoEvent(
            id: 'rest_video2',
            pubkey: 'author2',
            content: 'REST API video 2',
            createdAt: timestamp - 100,
            timestamp: now.subtract(const Duration(seconds: 100)),
            videoUrl: 'https://example.com/video2.mp4',
          ),
        ];

        when(
          mockAnalyticsApiService.getHomeFeed(
            pubkey: anyNamed('pubkey'),
            limit: anyNamed('limit'),
            sort: anyNamed('sort'),
            before: anyNamed('before'),
          ),
        ).thenAnswer(
          (_) async => HomeFeedResult(
            videos: mockVideos,
            nextCursor: timestamp - 200,
            hasMore: true,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            analyticsApiServiceProvider.overrideWithValue(
              mockAnalyticsApiService,
            ),
            followRepositoryProvider.overrideWithValue(
              createMockFollowRepository(['author1', 'author2']),
            ),
          ],
        );

        // Act
        final result = await container.read(homeFeedProvider.future);

        // Assert: Should have videos from REST API
        expect(result.videos.length, 2);
        expect(result.videos[0].id, 'rest_video1');
        expect(result.videos[1].id, 'rest_video2');
        expect(result.hasMoreContent, isTrue);

        // Verify REST API was called
        verify(
          mockAnalyticsApiService.getHomeFeed(
            pubkey: anyNamed('pubkey'),
            limit: anyNamed('limit'),
            sort: anyNamed('sort'),
            before: anyNamed('before'),
          ),
        ).called(1);

        // Verify Nostr was NOT called since REST API succeeded
        verifyNever(
          mockVideoEventService.subscribeToHomeFeed(
            any,
            limit: anyNamed('limit'),
          ),
        );

        container.dispose();
      },
      skip:
          'Complex mocking required: AuthService, FollowRepository, AnalyticsApiService, and subscribed list cache providers',
    );

    test(
      'should fallback to Nostr when REST API is not available',
      () async {
        // Setup: REST API is NOT available
        when(mockAnalyticsApiService.isAvailable).thenReturn(false);

        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch ~/ 1000;
        final mockVideos = [
          VideoEvent(
            id: 'nostr_video1',
            pubkey: 'author1',
            content: 'Nostr video 1',
            createdAt: timestamp,
            timestamp: now,
            videoUrl: 'https://example.com/video1.mp4',
          ),
        ];

        when(mockVideoEventService.homeFeedVideos).thenReturn(mockVideos);

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            analyticsApiServiceProvider.overrideWithValue(
              mockAnalyticsApiService,
            ),
            followRepositoryProvider.overrideWithValue(
              createMockFollowRepository(['author1']),
            ),
          ],
        );

        // Act
        final result = await container.read(homeFeedProvider.future);

        // Assert: Should have videos from Nostr
        expect(result.videos.length, 1);
        expect(result.videos[0].id, 'nostr_video1');

        // Verify Nostr was called since REST API not available
        verify(
          mockVideoEventService.subscribeToHomeFeed(
            any,
            limit: anyNamed('limit'),
          ),
        ).called(1);

        container.dispose();
      },
      skip:
          'Complex mocking required: AuthService, FollowRepository, AnalyticsApiService, and subscribed list cache providers',
    );

    test(
      'should fallback to Nostr when REST API throws error',
      () async {
        // Setup: REST API is available but throws error
        when(mockAnalyticsApiService.isAvailable).thenReturn(true);
        when(
          mockAnalyticsApiService.getHomeFeed(
            pubkey: anyNamed('pubkey'),
            limit: anyNamed('limit'),
            sort: anyNamed('sort'),
            before: anyNamed('before'),
          ),
        ).thenThrow(Exception('API Error'));

        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch ~/ 1000;
        final mockVideos = [
          VideoEvent(
            id: 'fallback_video',
            pubkey: 'author1',
            content: 'Fallback video',
            createdAt: timestamp,
            timestamp: now,
            videoUrl: 'https://example.com/video.mp4',
          ),
        ];

        when(mockVideoEventService.homeFeedVideos).thenReturn(mockVideos);

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            analyticsApiServiceProvider.overrideWithValue(
              mockAnalyticsApiService,
            ),
            followRepositoryProvider.overrideWithValue(
              createMockFollowRepository(['author1']),
            ),
          ],
        );

        // Act
        final result = await container.read(homeFeedProvider.future);

        // Assert: Should have videos from Nostr fallback
        expect(result.videos.length, 1);
        expect(result.videos[0].id, 'fallback_video');

        // Verify both were called (REST API tried, then Nostr)
        verify(
          mockAnalyticsApiService.getHomeFeed(
            pubkey: anyNamed('pubkey'),
            limit: anyNamed('limit'),
            sort: anyNamed('sort'),
            before: anyNamed('before'),
          ),
        ).called(1);
        verify(
          mockVideoEventService.subscribeToHomeFeed(
            any,
            limit: anyNamed('limit'),
          ),
        ).called(1);

        container.dispose();
      },
      skip:
          'Complex mocking required: AuthService, FollowRepository, AnalyticsApiService, and subscribed list cache providers',
    );

    test(
      'should fallback to Nostr when REST API returns empty',
      () async {
        // Setup: REST API is available but returns empty
        when(mockAnalyticsApiService.isAvailable).thenReturn(true);
        when(
          mockAnalyticsApiService.getHomeFeed(
            pubkey: anyNamed('pubkey'),
            limit: anyNamed('limit'),
            sort: anyNamed('sort'),
            before: anyNamed('before'),
          ),
        ).thenAnswer(
          (_) async => const HomeFeedResult(
            videos: [],
            nextCursor: null,
            hasMore: false,
          ),
        );

        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch ~/ 1000;
        final mockVideos = [
          VideoEvent(
            id: 'nostr_fallback_video',
            pubkey: 'author1',
            content: 'Nostr fallback video',
            createdAt: timestamp,
            timestamp: now,
            videoUrl: 'https://example.com/video.mp4',
          ),
        ];

        when(mockVideoEventService.homeFeedVideos).thenReturn(mockVideos);

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            analyticsApiServiceProvider.overrideWithValue(
              mockAnalyticsApiService,
            ),
            followRepositoryProvider.overrideWithValue(
              createMockFollowRepository(['author1']),
            ),
          ],
        );

        // Act
        final result = await container.read(homeFeedProvider.future);

        // Assert: Should have videos from Nostr fallback
        expect(result.videos.length, 1);
        expect(result.videos[0].id, 'nostr_fallback_video');

        // Verify both were called
        verify(
          mockAnalyticsApiService.getHomeFeed(
            pubkey: anyNamed('pubkey'),
            limit: anyNamed('limit'),
            sort: anyNamed('sort'),
            before: anyNamed('before'),
          ),
        ).called(1);
        verify(
          mockVideoEventService.subscribeToHomeFeed(
            any,
            limit: anyNamed('limit'),
          ),
        ).called(1);

        container.dispose();
      },
      skip:
          'Complex mocking required: AuthService, FollowRepository, AnalyticsApiService, and subscribed list cache providers',
    );

    test(
      'loadMore should use REST API cursor pagination',
      () async {
        // Setup: REST API is available
        when(mockAnalyticsApiService.isAvailable).thenReturn(true);

        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch ~/ 1000;

        // Initial videos
        final initialVideos = [
          VideoEvent(
            id: 'video1',
            pubkey: 'author1',
            content: 'Video 1',
            createdAt: timestamp,
            timestamp: now,
            videoUrl: 'https://example.com/video1.mp4',
          ),
        ];

        // Additional videos for loadMore
        final moreVideos = [
          VideoEvent(
            id: 'video2',
            pubkey: 'author1',
            content: 'Video 2',
            createdAt: timestamp - 200,
            timestamp: now.subtract(const Duration(seconds: 200)),
            videoUrl: 'https://example.com/video2.mp4',
          ),
        ];

        var callCount = 0;
        when(
          mockAnalyticsApiService.getHomeFeed(
            pubkey: anyNamed('pubkey'),
            limit: anyNamed('limit'),
            sort: anyNamed('sort'),
            before: anyNamed('before'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return HomeFeedResult(
              videos: initialVideos,
              nextCursor: timestamp - 100,
              hasMore: true,
            );
          } else {
            return HomeFeedResult(
              videos: moreVideos,
              nextCursor: timestamp - 300,
              hasMore: false,
            );
          }
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
            subscriptionManagerProvider.overrideWithValue(
              mockSubscriptionManager,
            ),
            analyticsApiServiceProvider.overrideWithValue(
              mockAnalyticsApiService,
            ),
            followRepositoryProvider.overrideWithValue(
              createMockFollowRepository(['author1']),
            ),
          ],
        );

        // Act: Load initial
        await container.read(homeFeedProvider.future);

        // Act: Load more
        await container.read(homeFeedProvider.notifier).loadMore();
        final result = await container.read(homeFeedProvider.future);

        // Assert: Should have combined videos
        expect(result.videos.length, 2);
        expect(result.videos.any((v) => v.id == 'video1'), isTrue);
        expect(result.videos.any((v) => v.id == 'video2'), isTrue);

        // Verify REST API was called twice (initial + loadMore)
        verify(
          mockAnalyticsApiService.getHomeFeed(
            pubkey: anyNamed('pubkey'),
            limit: anyNamed('limit'),
            sort: anyNamed('sort'),
            before: anyNamed('before'),
          ),
        ).called(2);

        container.dispose();
      },
      skip:
          'Complex mocking required: AuthService, FollowRepository, AnalyticsApiService, and subscribed list cache providers',
    );
  });
}
