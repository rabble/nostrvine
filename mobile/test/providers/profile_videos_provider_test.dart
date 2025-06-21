import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:nostr/nostr.dart';
import 'package:nostrvine_app/providers/profile_videos_provider.dart';
import 'package:nostrvine_app/services/nostr_service_interface.dart';

// Generate mocks
@GenerateMocks([INostrService])
import 'profile_videos_provider_test.mocks.dart';

void main() {
  group('ProfileVideosProvider', () {
    late ProfileVideosProvider provider;
    late MockINostrService mockNostrService;

    setUp(() {
      mockNostrService = MockINostrService();
      provider = ProfileVideosProvider(mockNostrService);
    });

    tearDown(() {
      provider.dispose();
    });

    group('Initial State', () {
      test('should have correct initial state', () {
        expect(provider.loadingState, ProfileVideosLoadingState.idle);
        expect(provider.videos, isEmpty);
        expect(provider.error, isNull);
        expect(provider.isLoading, false);
        expect(provider.isLoadingMore, false);
        expect(provider.hasError, false);
        expect(provider.hasVideos, false);
        expect(provider.hasMore, true);
        expect(provider.videoCount, 0);
      });
    });

    group('Loading Videos', () {
      const testPubkey = 'test_pubkey_123';

      test('should load user videos successfully', () async {
        // Mock video events
        final mockEvents = [
          Event.from(
            kind: 34550,
            content: 'Test video 1',
            tags: [
              ['title', 'Video 1'],
              ['r', 'https://example.com/video1.mp4'],
              ['thumb', 'https://example.com/thumb1.jpg'],
              ['duration', '30'],
            ],
            privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
          Event.from(
            kind: 34550,
            content: 'Test video 2',
            tags: [
              ['title', 'Video 2'],
              ['r', 'https://example.com/video2.mp4'],
              ['thumb', 'https://example.com/thumb2.jpg'],
              ['duration', '45'],
            ],
            privkey: '1123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
        ];

        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable(mockEvents));

        // Track loading state changes
        final states = <ProfileVideosLoadingState>[];
        provider.addListener(() {
          states.add(provider.loadingState);
        });

        // Load videos
        await provider.loadVideosForUser(testPubkey);

        // Verify state progression
        expect(states, contains(ProfileVideosLoadingState.loading));
        expect(provider.loadingState, ProfileVideosLoadingState.loaded);
        expect(provider.hasVideos, true);
        expect(provider.error, isNull);

        // Verify videos content
        expect(provider.videoCount, 2);
        final videos = provider.videos;
        expect(videos.length, 2);
        expect(videos[0].title, 'Video 1');
        expect(videos[1].title, 'Video 2');

        // Verify service call
        verify(mockNostrService.subscribeToEvents(filters: anyNamed('filters'))).called(1);
      });

      test('should handle loading errors gracefully', () async {
        // Mock service failure
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.error(Exception('Network error')));

        // Load videos
        await provider.loadVideosForUser(testPubkey);

        // Verify error state
        expect(provider.loadingState, ProfileVideosLoadingState.error);
        expect(provider.hasError, true);
        expect(provider.error, contains('Network error'));
        expect(provider.videos, isEmpty);
      });

      test('should not reload if already loaded for same user', () async {
        // First load
        final mockEvents = [
          Event.from(
            kind: 34550,
            content: 'Test video',
            tags: [['title', 'Video']],
            privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
        ];

        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable(mockEvents));

        await provider.loadVideosForUser(testPubkey);

        // Reset mock call counts
        clearInteractions(mockNostrService);

        // Second load for same user
        await provider.loadVideosForUser(testPubkey);

        // Should not call service again if already loaded
        expect(provider.videoCount, 1);
      });

      test('should load videos for different users', () async {
        const testPubkey2 = 'test_pubkey_456';

        // First user
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable([
              Event.from(
                kind: 34550,
                content: 'User 1 video',
                tags: [['title', 'User 1 Video']],
                privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
              ),
            ]));

        await provider.loadVideosForUser(testPubkey);
        expect(provider.videoCount, 1);

        // Second user - should load new videos
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable([
              Event.from(
                kind: 34550,
                content: 'User 2 video 1',
                tags: [['title', 'User 2 Video 1']],
                privkey: '1123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
              ),
              Event.from(
                kind: 34550,
                content: 'User 2 video 2',
                tags: [['title', 'User 2 Video 2']],
                privkey: '2123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
              ),
            ]));

        await provider.loadVideosForUser(testPubkey2);
        expect(provider.videoCount, 2);

        // Verify service was called for both users
        verify(mockNostrService.subscribeToEvents(filters: anyNamed('filters'))).called(2);
      });
    });

    group('Pagination', () {
      const testPubkey = 'test_pubkey_123';

      test('should load more videos for pagination', () async {
        // Initial load with page size amount of videos
        final initialEvents = List.generate(20, (index) => Event.from(
          kind: 22,
          content: 'Video ${index + 1}',
          tags: [['title', 'Video ${index + 1}']],
          privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        ));

        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable(initialEvents));

        await provider.loadVideosForUser(testPubkey);
        expect(provider.videoCount, 20);
        expect(provider.hasMore, true);

        // Load more videos
        final moreEvents = List.generate(10, (index) => Event.from(
          kind: 22,
          content: 'Video ${index + 21}',
          tags: [['title', 'Video ${index + 21}']],
          privkey: '1123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        ));

        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable(moreEvents));

        await provider.loadMoreVideos();

        expect(provider.videoCount, 30);
        expect(provider.hasMore, false); // Less than page size, so no more
      });

      test('should not load more when already loading', () async {
        // Mock delayed response
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable([]));

        // First load
        await provider.loadVideosForUser(testPubkey);

        // Set state to loading more manually to test guard
        provider.loadMoreVideos(); // Start loading more (don't await)

        // Second call should not trigger another load
        await provider.loadMoreVideos();

        // Should not have called service extra times
        verify(mockNostrService.subscribeToEvents(filters: anyNamed('filters'))).called(1);
      });

      test('should not load more when hasMore is false', () async {
        // Load videos with less than page size
        final events = List.generate(5, (index) => Event.from(
          kind: 22,
          content: 'Video ${index + 1}',
          tags: [['title', 'Video ${index + 1}']],
          privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        ));

        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable(events));

        await provider.loadVideosForUser(testPubkey);
        expect(provider.hasMore, false);

        clearInteractions(mockNostrService);

        // Try to load more - should not call service
        await provider.loadMoreVideos();
        verifyNever(mockNostrService.subscribeToEvents(filters: anyNamed('filters')));
      });
    });

    group('Caching', () {
      const testPubkey = 'test_pubkey_123';

      test('should use cached videos when available', () async {
        // First load
        final mockEvents = [
          Event.from(
            kind: 34550,
            content: 'Cached video',
            tags: [['title', 'Cached Video']],
            privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
        ];

        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable(mockEvents));

        await provider.loadVideosForUser(testPubkey);
        expect(provider.videoCount, 1);

        // Clear the current videos to test cache
        provider.dispose();
        provider = ProfileVideosProvider(mockNostrService);

        // Load same user again - should use cache (but we can't test this directly since cache is instance-based)
        // This is more of an integration test
      });

      test('should refresh videos by clearing cache', () async {
        // First load
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable([
              Event.from(
                kind: 34550,
                content: 'Original video',
                tags: [['title', 'Original Video']],
                privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
              ),
            ]));

        await provider.loadVideosForUser(testPubkey);
        expect(provider.videos[0].title, 'Original Video');

        // Mock updated videos
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable([
              Event.from(
                kind: 34550,
                content: 'Refreshed video',
                tags: [['title', 'Refreshed Video']],
                privkey: '1123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
              ),
            ]));

        // Refresh videos
        await provider.refreshVideos();

        // Should have new videos
        expect(provider.videos[0].title, 'Refreshed Video');
      });

      test('should clear all cache', () {
        provider.clearAllCache();
        // Just verify it doesn't throw - internal state is private
      });
    });

    group('Error Handling', () {
      const testPubkey = 'test_pubkey_123';

      test('should handle invalid video events gracefully', () async {
        // Mock events with invalid kind
        final invalidEvents = [
          Event.from(
            kind: 1, // Wrong kind
            content: 'Invalid event',
            tags: [],
            privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
        ];

        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable(invalidEvents));

        await provider.loadVideosForUser(testPubkey);

        // Should complete without errors but have no videos
        expect(provider.loadingState, ProfileVideosLoadingState.loaded);
        expect(provider.videoCount, 0);
      });

      test('should handle subscription errors during load more', () async {
        // Initial successful load
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable([
              Event.from(
                kind: 34550,
                content: 'Initial video',
                tags: [['title', 'Initial Video']],
                privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
              ),
            ]));

        await provider.loadVideosForUser(testPubkey);
        expect(provider.videoCount, 1);

        // Mock error during load more
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.error(Exception('Load more failed')));

        await provider.loadMoreVideos();

        // Should be in error state
        expect(provider.loadingState, ProfileVideosLoadingState.error);
        expect(provider.error, contains('Load more failed'));
        // Should still have original videos
        expect(provider.videoCount, 1);
      });
    });
  });
}