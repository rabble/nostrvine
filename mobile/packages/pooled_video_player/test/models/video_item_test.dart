import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group('VideoItem', () {
    group('Constructor', () {
      test('creates with required id and url', () {
        const video = VideoItem(
          id: 'video-123',
          url: 'https://example.com/video.mp4',
        );

        expect(video.id, 'video-123');
        expect(video.url, 'https://example.com/video.mp4');
      });

      test('title is optional', () {
        const video = VideoItem(
          id: 'video-123',
          url: 'https://example.com/video.mp4',
        );

        expect(video.title, isNull);
      });

      test('title can be provided', () {
        const video = VideoItem(
          id: 'video-123',
          url: 'https://example.com/video.mp4',
          title: 'My Video',
        );

        expect(video.title, 'My Video');
      });

      test('description is optional', () {
        const video = VideoItem(
          id: 'video-123',
          url: 'https://example.com/video.mp4',
        );

        expect(video.description, isNull);
      });

      test('description can be provided', () {
        const video = VideoItem(
          id: 'video-123',
          url: 'https://example.com/video.mp4',
          description: 'A great video',
        );

        expect(video.description, 'A great video');
      });

      test('thumbnailUrl is optional', () {
        const video = VideoItem(
          id: 'video-123',
          url: 'https://example.com/video.mp4',
        );

        expect(video.thumbnailUrl, isNull);
      });

      test('thumbnailUrl can be provided', () {
        const video = VideoItem(
          id: 'video-123',
          url: 'https://example.com/video.mp4',
          thumbnailUrl: 'https://example.com/thumb.jpg',
        );

        expect(video.thumbnailUrl, 'https://example.com/thumb.jpg');
      });

      test('optional fields default to null', () {
        const video = VideoItem(
          id: 'video-123',
          url: 'https://example.com/video.mp4',
        );

        expect(video.title, isNull);
        expect(video.description, isNull);
        expect(video.thumbnailUrl, isNull);
      });

      test('all fields can be provided', () {
        const video = VideoItem(
          id: 'video-123',
          url: 'https://example.com/video.mp4',
          title: 'My Video',
          description: 'A great video',
          thumbnailUrl: 'https://example.com/thumb.jpg',
        );

        expect(video.id, 'video-123');
        expect(video.url, 'https://example.com/video.mp4');
        expect(video.title, 'My Video');
        expect(video.description, 'A great video');
        expect(video.thumbnailUrl, 'https://example.com/thumb.jpg');
      });
    });

    group('const constructor', () {
      test('allows const construction', () {
        const video = VideoItem(
          id: 'video-123',
          url: 'https://example.com/video.mp4',
        );

        expect(video, isA<VideoItem>());
      });

      test('const videos with same values are identical', () {
        const video1 = VideoItem(
          id: 'video-123',
          url: 'https://example.com/video.mp4',
        );

        const video2 = VideoItem(
          id: 'video-123',
          url: 'https://example.com/video.mp4',
        );

        expect(identical(video1, video2), true);
      });
    });
  });
}
