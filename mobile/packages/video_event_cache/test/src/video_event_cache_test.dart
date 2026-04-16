// ABOUTME: Unit tests for the VideoEventCache interface.
// ABOUTME: Verifies the contract via a concrete implementation and a mock.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:video_event_cache/video_event_cache.dart';

class _MockVideoEventCache extends Mock implements VideoEventCache {}

class _TestVideoEventCache implements VideoEventCache {
  final List<VideoEvent> _videos = [];

  @override
  List<VideoEvent> get discoveryVideos => List.unmodifiable(_videos);

  @override
  void addVideoEvent(VideoEvent event) {
    _videos.add(event);
  }
}

VideoEvent _createVideo({
  required String id,
  String pubkey =
      '0000000000000000000000000000000000000000000000000000000000000001',
  int createdAt = 1700000000,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
  );
}

void main() {
  group(VideoEventCache, () {
    group('concrete implementation', () {
      late VideoEventCache cache;

      setUp(() {
        cache = _TestVideoEventCache();
      });

      group('discoveryVideos', () {
        test('returns empty list initially', () {
          expect(cache.discoveryVideos, isEmpty);
        });

        test('returns added videos in order', () {
          final video1 = _createVideo(
            id:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                'aaaaaaaaaaaaaaaaaaaaaaaa',
          );
          final video2 = _createVideo(
            id:
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
                'bbbbbbbbbbbbbbbbbbbbbbbb',
            createdAt: 1700000001,
          );

          cache
            ..addVideoEvent(video1)
            ..addVideoEvent(video2);

          expect(cache.discoveryVideos, orderedEquals([video1, video2]));
        });
      });

      group('addVideoEvent', () {
        test('adds a single video', () {
          final video = _createVideo(
            id:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                'aaaaaaaaaaaaaaaaaaaaaaaa',
          );

          cache.addVideoEvent(video);

          expect(cache.discoveryVideos, hasLength(1));
          expect(cache.discoveryVideos.first, equals(video));
        });

        test('adds multiple videos', () {
          for (var i = 0; i < 5; i++) {
            cache.addVideoEvent(
              _createVideo(
                id: i.toRadixString(16).padLeft(64, '0'),
                createdAt: 1700000000 + i,
              ),
            );
          }

          expect(cache.discoveryVideos, hasLength(5));
        });
      });
    });

    group('mock implementation', () {
      late _MockVideoEventCache mock;

      setUp(() {
        mock = _MockVideoEventCache();
      });

      test('can stub discoveryVideos', () {
        final video = _createVideo(
          id:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaa',
        );

        when(() => mock.discoveryVideos).thenReturn([video]);

        expect(mock.discoveryVideos, hasLength(1));
        expect(mock.discoveryVideos.first.id, equals(video.id));
      });

      test('can verify addVideoEvent calls', () {
        final video = _createVideo(
          id:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaa',
        );

        mock.addVideoEvent(video);

        verify(() => mock.addVideoEvent(video)).called(1);
      });

      test('can stub discoveryVideos as empty', () {
        when(() => mock.discoveryVideos).thenReturn([]);

        expect(mock.discoveryVideos, isEmpty);
      });
    });
  });
}
