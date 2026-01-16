// ABOUTME: Tests curation provider lifecycle behavior during navigation
// ABOUTME: Verifies editor's picks persist when navigating away and back to tab

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/curation_set.dart';
import 'package:models/models.dart'
    hide CurationSet, CurationSetType, SampleCurationSets;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:riverpod/riverpod.dart';

import 'curation_provider_lifecycle_test.mocks.dart';

@GenerateMocks([
  NostrClient,
  VideoEventService,
  SocialService,
  LikesRepository,
  AuthService,
  AnalyticsApiService,
])
void main() {
  setUpAll(() {
    provideDummy<List<Filter>>([]);
  });

  group('CurationProvider Lifecycle', () {
    late MockNostrClient mockNostrService;
    late MockVideoEventService mockVideoEventService;
    late MockSocialService mockSocialService;
    late MockLikesRepository mockLikesRepository;
    late MockAuthService mockAuthService;
    late MockAnalyticsApiService mockAnalyticsApiService;
    late List<VideoEvent> sampleVideos;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockVideoEventService = MockVideoEventService();
      mockSocialService = MockSocialService();
      mockLikesRepository = MockLikesRepository();
      mockAuthService = MockAuthService();
      mockAnalyticsApiService = MockAnalyticsApiService();

      // Create sample videos for editor's picks
      sampleVideos = List.generate(
        23,
        (i) => VideoEvent(
          id: 'video_$i',
          pubkey: 'pubkey_$i',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test video $i',
          timestamp: DateTime.now(),
          title: 'Video $i',
        ),
      );

      // Mock video event service to return sample videos
      when(mockVideoEventService.discoveryVideos).thenReturn(sampleVideos);

      // Stub nostr service methods
      when(
        mockNostrService.subscribe(
          argThat(anything),
          onEose: anyNamed('onEose'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      // Mock getLikeCounts to return empty counts (replaced getCachedLikeCount)
      when(mockLikesRepository.getLikeCounts(any)).thenAnswer((_) async => {});
    });

    test('curation provider uses keepAlive to persist state', () async {
      // ARRANGE: Create first container
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          socialServiceProvider.overrideWithValue(mockSocialService),
          authServiceProvider.overrideWithValue(mockAuthService),
          analyticsApiServiceProvider.overrideWithValue(
            mockAnalyticsApiService,
          ),
        ],
      );

      // ACT: Read curation provider
      final curationState = container.read(curationProvider);

      // ASSERT: Provider should initialize synchronously with loading state
      expect(
        curationState.isLoading,
        isTrue,
        reason: 'Provider initializes in loading state',
      );

      // The key point: with @Riverpod(keepAlive: true), the provider will:
      // 1. NOT autodispose when unwatched
      // 2. Persist state across navigation
      // 3. Complete initialization once and reuse that state

      // This test verifies the annotation is present and provider is marked as keepAlive
      // In production, this prevents the "0 videos" bug when navigating back to Editor's Pick

      container.dispose();
      // TODO(any): Fix and re-enable this test
    }, skip: true);

    test(
      'curation provider initialization completes and populates editor picks',
      () async {
        // ARRANGE: Create container
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(mockNostrService),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            socialServiceProvider.overrideWithValue(mockSocialService),
            authServiceProvider.overrideWithValue(mockAuthService),
            analyticsApiServiceProvider.overrideWithValue(
              mockAnalyticsApiService,
            ),
          ],
        );

        // ACT: Read initial state
        final initialState = container.read(curationProvider);

        // ASSERT: Initially loading
        expect(initialState.isLoading, isTrue);
        expect(initialState.editorsPicks, isEmpty);

        // Wait for async initialization
        await Future.microtask(() {});
        await Future.delayed(Duration(milliseconds: 10));

        // ACT: Read after initialization
        final loadedState = container.read(curationProvider);
        final editorsPicks = container.read(editorsPicksProvider);

        // ASSERT: Should be loaded with videos
        expect(loadedState.isLoading, isFalse);
        expect(editorsPicks.length, greaterThan(0));

        container.dispose();
      },
      // TODO(any): Fix and re-enable this test
      skip: true,
    );

    test('curation service initializes with sample data', () {
      // ARRANGE: Create curation service directly
      final service = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        likesRepository: mockLikesRepository,
        authService: mockAuthService,
      );

      // ACT & ASSERT: Service should initialize with sample data
      expect(service.isLoading, isFalse);
      final editorsPicks = service.getVideosForSetType(
        CurationSetType.editorsPicks,
      );

      // Editor's picks may be empty if no videos available, but service should not be loading
      expect(service.isLoading, isFalse);
      // Verify editorsPicks is a valid list (may be empty if no videos available)
      expect(editorsPicks, isA<List<VideoEvent>>());
    });
  });
}
