// ABOUTME: Tests for FullscreenFeedBloc - fullscreen video playback state
// ABOUTME: Tests stream subscription, index changes, pagination, and state management

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';

void main() {
  group('FullscreenFeedBloc', () {
    late StreamController<List<VideoEvent>> videosController;

    setUp(() {
      videosController = StreamController<List<VideoEvent>>.broadcast();
    });

    tearDown(() {
      videosController.close();
    });

    VideoEvent createTestVideo(String id) {
      final now = DateTime.now();
      return VideoEvent(
        id: id,
        pubkey: '0' * 64,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        content: '',
        timestamp: now,
        title: 'Test Video $id',
        videoUrl: 'https://example.com/video_$id.mp4',
        thumbnailUrl: 'https://example.com/thumb_$id.jpg',
      );
    }

    FullscreenFeedBloc createBloc({
      int initialIndex = 0,
      void Function()? onLoadMore,
    }) => FullscreenFeedBloc(
      videosStream: videosController.stream,
      initialIndex: initialIndex,
      onLoadMore: onLoadMore,
    );

    test('initial state has correct values', () {
      final bloc = createBloc(initialIndex: 2);
      expect(bloc.state.status, FullscreenFeedStatus.initial);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.currentIndex, 2);
      expect(bloc.state.isLoadingMore, isFalse);
      bloc.close();
    });

    group('FullscreenFeedState', () {
      test('currentVideo returns video at currentIndex', () {
        final video1 = createTestVideo('video1');
        final video2 = createTestVideo('video2');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video1, video2],
          currentIndex: 1,
        );

        expect(state.currentVideo, video2);
      });

      test('currentVideo returns null when index out of range', () {
        final video = createTestVideo('video1');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
          currentIndex: 5,
        );

        expect(state.currentVideo, isNull);
      });

      test('currentVideo returns null when videos empty', () {
        const state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          currentIndex: 0,
        );

        expect(state.currentVideo, isNull);
      });

      test('hasVideos returns true when videos not empty', () {
        final video = createTestVideo('video1');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
        );

        expect(state.hasVideos, isTrue);
      });

      test('hasVideos returns false when videos empty', () {
        const state = FullscreenFeedState(status: FullscreenFeedStatus.ready);

        expect(state.hasVideos, isFalse);
      });

      test('copyWith creates copy with updated values', () {
        const state = FullscreenFeedState();
        final video = createTestVideo('video1');

        final updated = state.copyWith(
          status: FullscreenFeedStatus.ready,
          videos: [video],
          currentIndex: 5,
          isLoadingMore: true,
        );

        expect(updated.status, FullscreenFeedStatus.ready);
        expect(updated.videos, [video]);
        expect(updated.currentIndex, 5);
        expect(updated.isLoadingMore, isTrue);
      });

      test('copyWith preserves values when not specified', () {
        final video = createTestVideo('video1');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
          currentIndex: 3,
          isLoadingMore: true,
        );

        final updated = state.copyWith();

        expect(updated.status, FullscreenFeedStatus.ready);
        expect(updated.videos, [video]);
        expect(updated.currentIndex, 3);
        expect(updated.isLoadingMore, isTrue);
      });

      test('props contains all fields for Equatable', () {
        final video = createTestVideo('video1');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
          currentIndex: 2,
          isLoadingMore: true,
        );

        expect(state.props, [
          FullscreenFeedStatus.ready,
          [video],
          2,
          true,
        ]);
      });
    });

    group('FullscreenFeedStarted', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'subscribes to videos stream and emits ready when videos arrive',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.status, 'status', FullscreenFeedStatus.ready)
              .having((s) => s.videos.length, 'videos count', 1)
              .having((s) => s.videos.first.id, 'first video id', 'video1'),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'emits multiple times when stream emits multiple values',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('video1'),
            createTestVideo('video2'),
          ]);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.length,
            'videos count',
            1,
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.videos.length,
            'videos count',
            2,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'cancels previous subscription when started again',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.length,
            'videos count',
            1,
          ),
        ],
      );
    });

    group('FullscreenFeedLoadMoreRequested', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'sets isLoadingMore and calls onLoadMore callback',
        build: () {
          var callCount = 0;
          return createBloc(onLoadMore: () => callCount++);
        },
        act: (bloc) => bloc.add(const FullscreenFeedLoadMoreRequested()),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
        ],
      );

      test('calls onLoadMore callback when triggered', () async {
        var called = false;
        final bloc = FullscreenFeedBloc(
          videosStream: videosController.stream,
          initialIndex: 0,
          onLoadMore: () => called = true,
        );

        bloc.add(const FullscreenFeedLoadMoreRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(called, isTrue);
        await bloc.close();
      });

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does nothing when onLoadMore is null',
        build: () => createBloc(onLoadMore: null),
        act: (bloc) => bloc.add(const FullscreenFeedLoadMoreRequested()),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does nothing when already loading more',
        build: () => createBloc(onLoadMore: () {}),
        seed: () => const FullscreenFeedState(isLoadingMore: true),
        act: (bloc) => bloc.add(const FullscreenFeedLoadMoreRequested()),
        expect: () => <FullscreenFeedState>[],
      );
    });

    group('FullscreenFeedIndexChanged', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'updates currentIndex',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('video1'),
            createTestVideo('video2'),
            createTestVideo('video3'),
          ],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(2)),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.currentIndex,
            'currentIndex',
            2,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'clamps index to valid range',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1'), createTestVideo('video2')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(10)),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.currentIndex,
            'currentIndex',
            1,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'clamps negative index to 0',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
          currentIndex: 0,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(-5)),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does nothing when index unchanged',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
          currentIndex: 0,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(0)),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'sets index to 0 when videos are empty',
        build: createBloc,
        seed: () => const FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          currentIndex: 5,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(10)),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.currentIndex,
            'currentIndex',
            0,
          ),
        ],
      );
    });

    group('close', () {
      test('cancels videos subscription', () async {
        final bloc = createBloc();
        bloc.add(const FullscreenFeedStarted());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await bloc.close();

        // After closing, stream events should not cause errors
        expect(
          () => videosController.add([createTestVideo('video1')]),
          returnsNormally,
        );
      });
    });

    group('FullscreenFeedEvent props', () {
      test('FullscreenFeedStarted props is empty', () {
        const event = FullscreenFeedStarted();
        expect(event.props, isEmpty);
      });

      test('FullscreenFeedLoadMoreRequested props is empty', () {
        const event = FullscreenFeedLoadMoreRequested();
        expect(event.props, isEmpty);
      });

      test('FullscreenFeedIndexChanged props contains index', () {
        const event = FullscreenFeedIndexChanged(5);
        expect(event.props, [5]);
      });
    });
  });
}
