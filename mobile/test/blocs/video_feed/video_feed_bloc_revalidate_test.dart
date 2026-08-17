// ABOUTME: Tests that a cold start revalidates instead of trusting the cache
// ABOUTME: Pins the #7719 fix: serve cached content, then fetch fresh

import 'package:bloc_test/bloc_test.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockFeedTuningRepository extends Mock implements FeedTuningRepository {}

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: '0000000000000000000000000000000000000000000000000000000000000000',
  createdAt: 1755300000,
  content: 'c',
  timestamp: DateTime.utc(2026, 8, 16),
  videoUrl: 'https://example.com/$id.mp4',
);

void main() {
  group(VideoFeedBloc, () {
    group('VideoFeedStarted', () {
      late _MockVideosRepository videosRepository;
      late _MockFollowRepository followRepository;
      late _MockCuratedListRepository curatedListRepository;
      late _MockFeedTuningRepository feedTuningRepository;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        videosRepository = _MockVideosRepository();
        followRepository = _MockFollowRepository();
        curatedListRepository = _MockCuratedListRepository();
        feedTuningRepository = _MockFeedTuningRepository();

        when(() => followRepository.followingPubkeys).thenReturn([]);
        when(
          () => followRepository.followingStream,
        ).thenAnswer((_) => BehaviorSubject<List<String>>.seeded([]));
        when(() => curatedListRepository.getSubscribedLists()).thenReturn([]);
        when(
          () => curatedListRepository.subscribedListsStream,
        ).thenAnswer((_) => const Stream.empty());
      });

      VideoFeedBloc buildBloc() => VideoFeedBloc(
        videosRepository: videosRepository,
        followRepository: followRepository,
        curatedListRepository: curatedListRepository,
        feedTuningRepository: feedTuningRepository,
      );

      // The regression this pins (#7719): `_onStarted` used to call
      // `_loadVideos` with the default `skipCache: false`, so the fetch that
      // exists to refresh the feed was itself answered from the repository's
      // in-memory cache — which carries no TTL. Reopening the app served
      // hours-old videos until the user pulled to refresh.
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'fetches past the cache on start so a reopen is not stale',
        setUp: () {
          when(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: [_video('fresh')]));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted(mode: FeedMode.latest)),
        wait: const Duration(milliseconds: 50),
        verify: (_) {
          verify(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: true,
            ),
          ).called(1);
          // Any additional call would mean the cache-answerable variant also
          // ran; exactly one fetch, and it skipped the cache.
          verifyNoMoreInteractions(videosRepository);
        },
      );

      // Switching *to* a mode mid-session reaches the feed through
      // `_selectSource`, a second route to the same stale page: the cache it
      // reads has no TTL either. Fixing only the cold start left #7719's
      // symptom alive here.
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'fetches past the cache when the user switches modes',
        setUp: () {
          when(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: [_video('fresh')]));
          when(
            () => videosRepository.getClassicVideos(
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: [_video('c')]));
        },
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.classic));
          await Future<void>.delayed(const Duration(milliseconds: 30));
          bloc.add(const VideoFeedModeChanged(FeedMode.latest));
        },
        wait: const Duration(milliseconds: 80),
        verify: (_) {
          verify(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: true,
            ),
          ).called(1);
        },
      );
    });
  });
}
