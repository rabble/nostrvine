// ABOUTME: Tests for RiverpodFeedRepository source resolution and replay.

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/new_videos_feed_provider.dart';
import 'package:openvine/state/video_feed_state.dart';

VideoEvent _video(String id, {String pubkey = 'author'}) => VideoEvent(
  id: id,
  pubkey: pubkey,
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
  videoUrl: 'https://media.divine.video/$id.mp4',
);

class _TestNewVideosFeed extends NewVideosFeed {
  @override
  Future<VideoFeedState> build() async {
    return const VideoFeedState(videos: [], hasMoreContent: true);
  }

  void emit(List<VideoEvent> videos, {required bool hasMore}) {
    state = AsyncValue.data(
      VideoFeedState(videos: videos, hasMoreContent: hasMore),
    );
  }
}

void main() {
  group('RiverpodFeedRepository', () {
    late ProviderContainer container;
    late FeedRepository repository;

    setUp(() {
      container = ProviderContainer();
      repository = container.read(feedRepositoryProvider);
    });

    tearDown(() => container.dispose());

    test('resolves SingleVideoViewSource to the single video', () {
      final source = SingleVideoViewSource(_video('1'));

      expect(
        repository.watchView(source),
        emits(isA<List<VideoEvent>>().having((l) => l.single.id, 'id', '1')),
      );
    });

    test('resolves VideoListViewSource to the provided list', () {
      final source = VideoListViewSource([_video('1'), _video('2')]);

      expect(
        repository.watchView(source),
        emits(isA<List<VideoEvent>>().having((l) => l.length, 'length', 2)),
      );
    });

    test('static sources never paginate', () async {
      final source = VideoListViewSource([_video('1')]);

      expect(repository.watchHasMore(source), emits(false));
      await expectLater(repository.loadMore(source), completes);
    });

    test(
      'global feed bridge replays latest state and re-emits updates',
      () async {
        container.dispose();
        container = ProviderContainer(
          overrides: [
            newVideosFeedProvider.overrideWith(_TestNewVideosFeed.new),
          ],
        );
        repository = container.read(feedRepositoryProvider);

        final feed =
            container.read(newVideosFeedProvider.notifier)
                as _TestNewVideosFeed;
        await container.read(newVideosFeedProvider.future);
        feed.emit([_video('1')], hasMore: true);

        final videosExpectation = expectLater(
          repository.watchView(const NewVideosViewSource()),
          emitsInOrder([
            isA<List<VideoEvent>>().having((l) => l.single.id, 'id', '1'),
            isA<List<VideoEvent>>().having((l) => l.last.id, 'last id', '2'),
          ]),
        );
        await expectLater(
          repository.watchHasMore(const NewVideosViewSource()),
          emits(true),
        );

        feed.emit([_video('1'), _video('2')], hasMore: false);
        await videosExpectation;
      },
    );

    test('throws for scoped sources that are not globally resolvable', () {
      expect(
        () => repository.watchView(const ProfileViewSource('x')),
        throwsUnsupportedError,
      );
      expect(
        () => repository.watchView(const SearchViewSource('cats')),
        throwsUnsupportedError,
      );
      expect(
        () => repository.watchView(const CategoryViewSource('animals')),
        throwsUnsupportedError,
      );
    });
  });
}
