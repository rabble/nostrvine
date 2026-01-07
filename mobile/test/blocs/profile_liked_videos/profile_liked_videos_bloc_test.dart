// ABOUTME: Tests for ProfileLikedVideosBloc - fetching liked videos
// ABOUTME: Tests loading from cache, relay fetching, and state management

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
  });

  group('ProfileLikedVideosBloc', () {
    late _MockVideoEventService mockVideoEventService;
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockVideoEventService = _MockVideoEventService();
      mockNostrClient = _MockNostrClient();
    });

    ProfileLikedVideosBloc createBloc() => ProfileLikedVideosBloc(
      videoEventService: mockVideoEventService,
      nostrClient: mockNostrClient,
    );

    VideoEvent createTestVideo(String id) {
      // Create a minimal VideoEvent for testing
      final now = DateTime.now();
      return VideoEvent(
        id: id,
        pubkey: '0' * 64,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        content: '',
        timestamp: now,
        title: 'Test Video $id',
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
    }

    test('initial state is initial with empty collections', () {
      final bloc = createBloc();
      expect(bloc.state.status, ProfileLikedVideosStatus.initial);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.likedEventIds, isEmpty);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    group('ProfileLikedVideosState', () {
      test('isLoaded returns true when status is success', () {
        const initialState = ProfileLikedVideosState();
        const successState = ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
        );

        expect(initialState.isLoaded, isFalse);
        expect(successState.isLoaded, isTrue);
      });

      test('isLoading returns true when status is loading', () {
        const initialState = ProfileLikedVideosState();
        const loadingState = ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.loading,
        );

        expect(initialState.isLoading, isFalse);
        expect(loadingState.isLoading, isTrue);
      });

      test('copyWith creates copy with updated values', () {
        const state = ProfileLikedVideosState();

        final updated = state.copyWith(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: ['event1'],
        );

        expect(updated.status, ProfileLikedVideosStatus.success);
        expect(updated.likedEventIds, ['event1']);
      });

      test('copyWith preserves values when not specified', () {
        const state = ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: ['event1'],
        );

        final updated = state.copyWith();

        expect(updated.status, ProfileLikedVideosStatus.success);
        expect(updated.likedEventIds, ['event1']);
      });

      test('copyWith clearError removes error', () {
        const state = ProfileLikedVideosState(
          error: ProfileLikedVideosError.loadFailed,
        );

        final updated = state.copyWith(clearError: true);

        expect(updated.error, isNull);
      });
    });

    group('ProfileLikedVideosLoadRequested', () {
      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'emits [success] with empty videos when liked IDs list is empty',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ProfileLikedVideosLoadRequested(likedEventIds: [])),
        expect: () => [
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
            videos: [],
            likedEventIds: [],
          ),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'emits [loading, success] when all videos found in cache',
        setUp: () {
          final video1 = createTestVideo('event1');
          final video2 = createTestVideo('event2');

          when(
            () => mockVideoEventService.getVideoById('event1'),
          ).thenReturn(video1);
          when(
            () => mockVideoEventService.getVideoById('event2'),
          ).thenReturn(video2);
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ProfileLikedVideosLoadRequested(
            likedEventIds: ['event1', 'event2'],
          ),
        ),
        expect: () => [
          isA<ProfileLikedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileLikedVideosStatus.loading,
              )
              .having((s) => s.likedEventIds, 'likedEventIds', [
                'event1',
                'event2',
              ]),
          isA<ProfileLikedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileLikedVideosStatus.success,
              )
              .having((s) => s.videos.length, 'videos count', 2),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'preserves order of liked event IDs in result',
        setUp: () {
          final video1 = createTestVideo('event1');
          final video2 = createTestVideo('event2');
          final video3 = createTestVideo('event3');

          when(
            () => mockVideoEventService.getVideoById('event1'),
          ).thenReturn(video1);
          when(
            () => mockVideoEventService.getVideoById('event2'),
          ).thenReturn(video2);
          when(
            () => mockVideoEventService.getVideoById('event3'),
          ).thenReturn(video3);
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ProfileLikedVideosLoadRequested(
            likedEventIds: ['event3', 'event1', 'event2'],
          ),
        ),
        expect: () => [
          isA<ProfileLikedVideosState>().having(
            (s) => s.status,
            'status',
            ProfileLikedVideosStatus.loading,
          ),
          isA<ProfileLikedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileLikedVideosStatus.success,
              )
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'video IDs order',
                ['event3', 'event1', 'event2'],
              ),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'fetches missing videos from relay when not in cache',
        setUp: () {
          final video1 = createTestVideo('event1');

          // event1 in cache, event2 missing
          when(
            () => mockVideoEventService.getVideoById('event1'),
          ).thenReturn(video1);
          when(
            () => mockVideoEventService.getVideoById('event2'),
          ).thenReturn(null);

          // Mock relay subscription - return empty stream (timeout will complete)
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => const Stream<Event>.empty());

          when(
            () => mockNostrClient.unsubscribe(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ProfileLikedVideosLoadRequested(
            likedEventIds: ['event1', 'event2'],
          ),
        ),
        wait: const Duration(seconds: 6), // Wait for relay timeout
        expect: () => [
          isA<ProfileLikedVideosState>().having(
            (s) => s.status,
            'status',
            ProfileLikedVideosStatus.loading,
          ),
          isA<ProfileLikedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileLikedVideosStatus.success,
              )
              // Only event1 found (event2 not fetched from relay in test)
              .having((s) => s.videos.length, 'videos count', 1),
        ],
        verify: (_) {
          // Verify relay was called to fetch missing video
          verify(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).called(1);
        },
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'handles cache returning no videos gracefully',
        setUp: () {
          when(
            () => mockVideoEventService.getVideoById(any()),
          ).thenReturn(null);

          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => const Stream<Event>.empty());

          when(
            () => mockNostrClient.unsubscribe(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ProfileLikedVideosLoadRequested(likedEventIds: ['event1']),
        ),
        wait: const Duration(seconds: 6),
        expect: () => [
          isA<ProfileLikedVideosState>().having(
            (s) => s.status,
            'status',
            ProfileLikedVideosStatus.loading,
          ),
          isA<ProfileLikedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileLikedVideosStatus.success,
              )
              .having((s) => s.videos, 'videos', isEmpty),
        ],
      );
    });

    group('ProfileLikedVideosRefreshRequested', () {
      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'does nothing when likedEventIds is empty',
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosRefreshRequested()),
        expect: () => <ProfileLikedVideosState>[],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'reloads videos using stored likedEventIds',
        setUp: () {
          final video1 = createTestVideo('event1');
          when(
            () => mockVideoEventService.getVideoById('event1'),
          ).thenReturn(video1);
        },
        build: createBloc,
        seed: () => const ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: ['event1'],
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosRefreshRequested()),
        expect: () => [
          isA<ProfileLikedVideosState>().having(
            (s) => s.status,
            'status',
            ProfileLikedVideosStatus.loading,
          ),
          isA<ProfileLikedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileLikedVideosStatus.success,
              )
              .having((s) => s.videos.length, 'videos count', 1),
        ],
      );
    });
  });
}
