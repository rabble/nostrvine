// ABOUTME: Unit tests for StaticFeedRepository and StreamFeedRepository.

import 'dart:async';

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

VideoEvent _video(String id, {String pubkey = 'author'}) => VideoEvent(
  id: id,
  pubkey: pubkey,
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
);

void main() {
  group('StaticFeedRepository', () {
    test('emits the single video for SingleVideoViewSource', () {
      final repo = StaticFeedRepository();
      final source = SingleVideoViewSource(_video('1'));

      expect(
        repo.watchView(source),
        emits(isA<List<VideoEvent>>().having((l) => l.single.id, 'id', '1')),
      );
    });

    test('emits the list for VideoListViewSource', () {
      final repo = StaticFeedRepository();
      final source = VideoListViewSource([_video('1'), _video('2')]);

      expect(
        repo.watchView(source),
        emits(
          isA<List<VideoEvent>>().having((l) => l.length, 'length', 2),
        ),
      );
    });

    test('applies the boundary filter to emitted videos', () {
      final repo = StaticFeedRepository(
        filter: (videos) =>
            videos.where((v) => v.pubkey != 'blocked').toList(),
      );
      final source = VideoListViewSource([
        _video('1'),
        _video('2', pubkey: 'blocked'),
      ]);

      expect(
        repo.watchView(source),
        emits(
          isA<List<VideoEvent>>()
              .having((l) => l.length, 'length', 1)
              .having((l) => l.single.id, 'id', '1'),
        ),
      );
    });

    test('hasMore is always false and loadMore is a no-op', () async {
      final repo = StaticFeedRepository();
      final source = SingleVideoViewSource(_video('1'));

      expect(repo.watchHasMore(source), emits(false));
      await expectLater(repo.loadMore(source), completes);
    });

    test('throws for unsupported dynamic sources', () {
      final repo = StaticFeedRepository();

      expect(
        () => repo.watchView(const ForYouViewSource()),
        throwsArgumentError,
      );
    });
  });

  group('StreamFeedRepository', () {
    test('forwards the wrapped video stream', () {
      final controller = StreamController<List<VideoEvent>>();
      addTearDown(controller.close);
      final repo = StreamFeedRepository(videos: controller.stream);

      expect(
        repo.watchView(const ProfileViewSource('x')),
        emitsInOrder([
          isA<List<VideoEvent>>().having((l) => l.single.id, 'id', '1'),
          isA<List<VideoEvent>>().having((l) => l.single.id, 'id', '2'),
        ]),
      );

      controller
        ..add([_video('1')])
        ..add([_video('2')]);
    });

    test('applies the boundary filter to every emission', () {
      final controller = StreamController<List<VideoEvent>>();
      addTearDown(controller.close);
      final repo = StreamFeedRepository(
        videos: controller.stream,
        filter: (videos) =>
            videos.where((v) => v.pubkey != 'blocked').toList(),
      );

      expect(
        repo.watchView(const ProfileViewSource('x')),
        emits(isA<List<VideoEvent>>().having((l) => l.length, 'length', 1)),
      );

      controller.add([_video('1'), _video('2', pubkey: 'blocked')]);
    });

    test('loadMore invokes the callback', () async {
      var called = 0;
      final repo = StreamFeedRepository(
        videos: const Stream<List<VideoEvent>>.empty(),
        onLoadMore: () async => called++,
      );

      await repo.loadMore(const ProfileViewSource('x'));
      expect(called, 1);
    });

    test('watchHasMore forwards the wrapped stream', () {
      final repo = StreamFeedRepository(
        videos: const Stream<List<VideoEvent>>.empty(),
        hasMore: Stream<bool>.value(true),
      );

      expect(repo.watchHasMore(const ProfileViewSource('x')), emits(true));
    });

    test('watchHasMore defaults to false when none supplied', () {
      final repo = StreamFeedRepository(
        videos: const Stream<List<VideoEvent>>.empty(),
      );

      expect(repo.watchHasMore(const ProfileViewSource('x')), emits(false));
    });
  });
}
