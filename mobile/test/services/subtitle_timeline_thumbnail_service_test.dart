// ABOUTME: Tests for SubtitleTimelineThumbnailService — caching a published
// ABOUTME: video before extracting the timeline's filmstrip.

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/subtitle_timeline_thumbnail_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';

void main() {
  group(SubtitleTimelineThumbnailService, () {
    late Directory temp;
    late File video;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('subtitle_thumbnails');
      video = File('${temp.path}/video.mp4')..writeAsStringSync('not a video');
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('extracts frames from the cached file', () async {
      final requestedPaths = <String>[];
      final service = SubtitleTimelineThumbnailService(
        downloadVideo:
            ({required String url, required String cacheKey}) async => video,
        stripThumbnailStreamFactory:
            ({
              required String videoPath,
              required String clipId,
              required Duration duration,
              required Size outputSize,
              required int thumbsPerSecond,
              List<Duration>? priorityTimestamps,
            }) {
              requestedPaths.add(videoPath);
              return Stream.value([
                StripThumbnail(
                  path: '$videoPath.jpg',
                  timestamp: Duration.zero,
                ),
              ]);
            },
      );

      final batches = await service
          .thumbnailsFor(
            videoUrl: 'https://example.com/video.mp4',
            videoId: 'v',
            duration: const Duration(seconds: 6),
            devicePixelRatio: 2,
          )
          .toList();

      expect(requestedPaths, [video.path]);
      expect(batches.single.single.path, '${video.path}.jpg');
    });

    test('yields nothing when the video cannot be cached', () async {
      final service = SubtitleTimelineThumbnailService(
        downloadVideo:
            ({required String url, required String cacheKey}) async => null,
        stripThumbnailStreamFactory:
            ({
              required String videoPath,
              required String clipId,
              required Duration duration,
              required Size outputSize,
              required int thumbsPerSecond,
              List<Duration>? priorityTimestamps,
            }) => fail('extraction must not start without a file'),
      );

      final batches = await service
          .thumbnailsFor(
            videoUrl: 'https://example.com/video.mp4',
            videoId: 'v',
            duration: const Duration(seconds: 6),
            devicePixelRatio: 2,
          )
          .toList();

      expect(batches, isEmpty);
    });

    test('a failed download leaves the timeline without frames', () async {
      final service = SubtitleTimelineThumbnailService(
        downloadVideo:
            ({required String url, required String cacheKey}) async =>
                throw const SocketException('offline'),
        stripThumbnailStreamFactory:
            ({
              required String videoPath,
              required String clipId,
              required Duration duration,
              required Size outputSize,
              required int thumbsPerSecond,
              List<Duration>? priorityTimestamps,
            }) => fail('extraction must not start without a file'),
      );

      final batches = await service
          .thumbnailsFor(
            videoUrl: 'https://example.com/video.mp4',
            videoId: 'v',
            duration: const Duration(seconds: 6),
            devicePixelRatio: 2,
          )
          .toList();

      expect(batches, isEmpty, reason: 'the failure never reaches the widget');
    });

    test('an unknown duration skips extraction entirely', () async {
      final service = SubtitleTimelineThumbnailService(
        downloadVideo:
            ({required String url, required String cacheKey}) async =>
                fail('nothing to extract from, so nothing to download'),
      );

      final batches = await service
          .thumbnailsFor(
            videoUrl: 'https://example.com/video.mp4',
            videoId: 'v',
            duration: Duration.zero,
            devicePixelRatio: 2,
          )
          .toList();

      expect(batches, isEmpty);
    });
  });
}
