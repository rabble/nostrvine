// ABOUTME: Tests for RiverpodFeedRepository static + unsupported-source paths.
// ABOUTME: Global feed delegation is covered via the home-tab widget tests.

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/feed_repository_provider.dart';

VideoEvent _video(String id, {String pubkey = 'author'}) => VideoEvent(
  id: id,
  pubkey: pubkey,
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
  videoUrl: 'https://media.divine.video/$id.mp4',
);

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
