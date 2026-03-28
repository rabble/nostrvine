import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/providers/feed_refresh_helpers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('staleWhileRevalidate', () {
    VideoEvent video(String id) {
      return VideoEvent(
        id: id,
        pubkey: 'author-$id',
        createdAt: DateTime(2026, 3, 17).millisecondsSinceEpoch ~/ 1000,
        content: 'video $id',
        timestamp: DateTime(2026, 3, 17),
        videoUrl: 'https://example.com/$id.mp4',
        thumbnailUrl: 'https://example.com/$id.jpg',
        rawTags: const {'d': 'seed'},
        originalLoops: AppConstants.paginationBatchSize,
      );
    }

    test('emits refreshing state then fresh state on success', () async {
      final oldVideos = [video('old')];
      final freshVideos = [video('fresh')];

      final oldState = VideoFeedState(
        videos: oldVideos,
        hasMoreContent: true,
      );

      final states = <AsyncValue<VideoFeedState>>[];

      await staleWhileRevalidate(
        getCurrentState: () => AsyncData(oldState),
        isMounted: () => true,
        setState: states.add,
        fetchFresh: () async => VideoFeedState(
          videos: freshVideos,
          hasMoreContent: false,
        ),
      );

      expect(states, hasLength(2));

      // First emit: old state with isRefreshing: true
      final refreshingState = states[0].asData!.value;
      expect(refreshingState.videos.map((v) => v.id), ['old']);
      expect(refreshingState.isRefreshing, isTrue);
      expect(refreshingState.isInitialLoad, isFalse);
      expect(refreshingState.error, isNull);

      // Second emit: fresh state with isRefreshing: false
      final finalState = states[1].asData!.value;
      expect(finalState.videos.map((v) => v.id), ['fresh']);
      expect(finalState.isRefreshing, isFalse);
      expect(finalState.isInitialLoad, isFalse);
      expect(finalState.error, isNull);
    });

    test(
      'preserves existing state with error message on fetch failure',
      () async {
        final oldVideos = [video('existing')];
        final oldState = VideoFeedState(
          videos: oldVideos,
          hasMoreContent: true,
        );

        final states = <AsyncValue<VideoFeedState>>[];

        await staleWhileRevalidate(
          getCurrentState: () => AsyncData(oldState),
          isMounted: () => true,
          setState: states.add,
          fetchFresh: () async => throw Exception('network error'),
        );

        expect(states, hasLength(2));

        // First emit: refreshing indicator
        expect(states[0].asData!.value.isRefreshing, isTrue);

        // Second emit: old state preserved with error
        final errorState = states[1].asData!.value;
        expect(errorState.videos.map((v) => v.id), ['existing']);
        expect(errorState.isRefreshing, isFalse);
        expect(errorState.error, contains('network error'));
      },
    );

    test(
      'emits empty state with error when no existing state on failure',
      () async {
        final states = <AsyncValue<VideoFeedState>>[];

        await staleWhileRevalidate(
          getCurrentState: () => const AsyncLoading<VideoFeedState>(),
          isMounted: () => true,
          setState: states.add,
          fetchFresh: () async => throw Exception('network error'),
        );

        // No refreshing emit (no current state), just the error state
        expect(states, hasLength(1));

        final errorState = states[0].asData!.value;
        expect(errorState.videos, isEmpty);
        expect(errorState.hasMoreContent, isFalse);
        expect(errorState.error, contains('network error'));
      },
    );

    test('does not emit after fetch if unmounted', () async {
      final oldState = VideoFeedState(
        videos: [video('old')],
        hasMoreContent: true,
      );

      final states = <AsyncValue<VideoFeedState>>[];
      var mounted = true;

      await staleWhileRevalidate(
        getCurrentState: () => AsyncData(oldState),
        isMounted: () => mounted,
        setState: (state) {
          states.add(state);
          // Simulate unmount after the refreshing emit
          mounted = false;
        },
        fetchFresh: () async => VideoFeedState(
          videos: [video('fresh')],
          hasMoreContent: false,
        ),
      );

      // Only the refreshing emit should occur; the fresh state is skipped
      expect(states, hasLength(1));
      expect(states[0].asData!.value.isRefreshing, isTrue);
    });

    test('does not emit after error if unmounted', () async {
      final states = <AsyncValue<VideoFeedState>>[];
      var mounted = true;

      await staleWhileRevalidate(
        getCurrentState: () => AsyncData(
          VideoFeedState(
            videos: [video('old')],
            hasMoreContent: true,
          ),
        ),
        isMounted: () => mounted,
        setState: (state) {
          states.add(state);
          // Simulate unmount after the refreshing emit
          mounted = false;
        },
        fetchFresh: () async => throw Exception('fail'),
      );

      // Only the refreshing emit; error recovery skipped
      expect(states, hasLength(1));
      expect(states[0].asData!.value.isRefreshing, isTrue);
    });
  });

  group('mergeEnrichedVideos', () {
    VideoEvent video(String id, {String? title}) {
      return VideoEvent(
        id: id,
        pubkey: 'author',
        createdAt: 1000,
        content: '',
        timestamp: DateTime(2026),
        title: title,
        originalLoops: AppConstants.paginationBatchSize,
      );
    }

    test('replaces matching videos with enriched versions', () {
      final existing = [video('a', title: 'old'), video('b', title: 'old')];
      final enriched = [video('A', title: 'enriched')]; // case-insensitive

      final result = mergeEnrichedVideos(
        existing: existing,
        enriched: enriched,
      );

      expect(result[0].title, 'enriched');
      expect(result[1].title, 'old'); // no match for 'b'
    });

    test('preserves order of existing list', () {
      final existing = [video('c'), video('a'), video('b')];
      final enriched = [video('b', title: 'B'), video('c', title: 'C')];

      final result = mergeEnrichedVideos(
        existing: existing,
        enriched: enriched,
      );

      expect(result.map((v) => v.id), ['c', 'a', 'b']);
      expect(result[0].title, 'C');
      expect(result[1].title, isNull); // 'a' not enriched
      expect(result[2].title, 'B');
    });

    test('returns unchanged list when enriched is empty', () {
      final existing = [video('a'), video('b')];

      final result = mergeEnrichedVideos(
        existing: existing,
        enriched: [],
      );

      expect(result, existing);
    });
  });

  group('videoListsEqual', () {
    VideoEvent video(String id) {
      return VideoEvent(
        id: id,
        pubkey: 'author',
        createdAt: 1000,
        content: '',
        timestamp: DateTime(2026),
        originalLoops: AppConstants.paginationBatchSize,
      );
    }

    test('returns true for identical references', () {
      final list = [video('a')];
      expect(videoListsEqual(list, list), isTrue);
    });

    test('returns false for different lengths', () {
      expect(videoListsEqual([video('a')], [video('a'), video('b')]), isFalse);
    });

    test('returns true for equal elements', () {
      final a = video('a');
      final b = video('b');
      expect(videoListsEqual([a, b], [a, b]), isTrue);
    });

    test('returns false for different elements', () {
      expect(videoListsEqual([video('a')], [video('b')]), isFalse);
    });

    test('returns true for two empty lists', () {
      expect(videoListsEqual([], []), isTrue);
    });
  });

  group('getOldestTimestamp', () {
    VideoEvent videoAt(int createdAt) {
      return VideoEvent(
        id: 'v$createdAt',
        pubkey: 'author',
        createdAt: createdAt,
        content: '',
        timestamp: DateTime(2026),
        originalLoops: AppConstants.paginationBatchSize,
      );
    }

    test('returns null for empty list', () {
      expect(getOldestTimestamp([]), isNull);
    });

    test('returns the smallest createdAt', () {
      final videos = [videoAt(300), videoAt(100), videoAt(200)];
      expect(getOldestTimestamp(videos), 100);
    });

    test('returns the value for single-element list', () {
      expect(getOldestTimestamp([videoAt(42)]), 42);
    });
  });
}
