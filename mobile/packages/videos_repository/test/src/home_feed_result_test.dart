import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

void main() {
  group(HomeFeedResult, () {
    VideoEvent createVideo({required String id, int createdAt = 1000}) {
      return VideoEvent(
        id: id,
        pubkey: 'pubkey',
        createdAt: createdAt,
        content: '',
        timestamp: DateTime(2025),
      );
    }

    test('can be instantiated with required fields only', () {
      final result = HomeFeedResult(videos: [createVideo(id: 'v1')]);

      expect(result.videos, hasLength(1));
      expect(result.videoListSources, isEmpty);
      expect(result.listOnlyVideoIds, isEmpty);
    });

    test('can be instantiated with all fields', () {
      final result = HomeFeedResult(
        videos: [createVideo(id: 'v1')],
        videoListSources: const {
          'v1': {'list-a'},
        },
        listOnlyVideoIds: const {'v1'},
      );

      expect(result.videos, hasLength(1));
      expect(result.videoListSources, hasLength(1));
      expect(result.listOnlyVideoIds, contains('v1'));
    });

    test('empty constructor defaults', () {
      const result = HomeFeedResult(videos: []);

      expect(result.videos, isEmpty);
      expect(result.videoListSources, isEmpty);
      expect(result.listOnlyVideoIds, isEmpty);
    });

    test('supports equality via Equatable', () {
      final video = createVideo(id: 'v1');

      final result1 = HomeFeedResult(
        videos: [video],
        videoListSources: const {
          'v1': {'list-a'},
        },
        listOnlyVideoIds: const {'v1'},
      );

      final result2 = HomeFeedResult(
        videos: [video],
        videoListSources: const {
          'v1': {'list-a'},
        },
        listOnlyVideoIds: const {'v1'},
      );

      expect(result1, equals(result2));
    });

    test('inequality when videos differ', () {
      final result1 = HomeFeedResult(videos: [createVideo(id: 'v1')]);
      final result2 = HomeFeedResult(videos: [createVideo(id: 'v2')]);

      expect(result1, isNot(equals(result2)));
    });

    test('inequality when videoListSources differ', () {
      final video = createVideo(id: 'v1');

      final result1 = HomeFeedResult(
        videos: [video],
        videoListSources: const {
          'v1': {'list-a'},
        },
      );

      final result2 = HomeFeedResult(
        videos: [video],
        videoListSources: const {
          'v1': {'list-b'},
        },
      );

      expect(result1, isNot(equals(result2)));
    });

    test('inequality when listOnlyVideoIds differ', () {
      final video = createVideo(id: 'v1');

      final result1 = HomeFeedResult(
        videos: [video],
        listOnlyVideoIds: const {'v1'},
      );

      final result2 = HomeFeedResult(videos: [video]);

      expect(result1, isNot(equals(result2)));
    });

    test('props includes all fields', () {
      final video = createVideo(id: 'v1');
      const sources = {
        'v1': {'list-a'},
      };
      const listOnly = {'v1'};

      final result = HomeFeedResult(
        videos: [video],
        videoListSources: sources,
        listOnlyVideoIds: listOnly,
      );

      expect(result.props, hasLength(3));
      expect(result.props[0], equals([video]));
      expect(result.props[1], equals(sources));
      expect(result.props[2], equals(listOnly));
    });
  });
}
