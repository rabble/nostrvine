import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group('VideoItem', () {
    group('constructor', () {
      test('creates instance with required parameters only', () {
        const item = VideoItem(
          id: 'test_id',
          url: 'https://example.com/video.mp4',
        );

        expect(item.id, equals('test_id'));
        expect(item.url, equals('https://example.com/video.mp4'));
        expect(item.title, isNull);
        expect(item.description, isNull);
        expect(item.thumbnailUrl, isNull);
      });

      test('creates instance with all parameters', () {
        const item = VideoItem(
          id: 'test_id',
          url: 'https://example.com/video.mp4',
          title: 'Test Title',
          description: 'Test Description',
          thumbnailUrl: 'https://example.com/thumb.jpg',
        );

        expect(item.id, equals('test_id'));
        expect(item.url, equals('https://example.com/video.mp4'));
        expect(item.title, equals('Test Title'));
        expect(item.description, equals('Test Description'));
        expect(item.thumbnailUrl, equals('https://example.com/thumb.jpg'));
      });

      test('can be created as const', () {
        const item1 = VideoItem(
          id: 'const_id',
          url: 'https://example.com/video.mp4',
        );
        const item2 = VideoItem(
          id: 'const_id',
          url: 'https://example.com/video.mp4',
        );

        expect(identical(item1, item2), isTrue);
      });
    });

    group('properties', () {
      test('id property returns correct value', () {
        const item = VideoItem(
          id: 'unique_id_123',
          url: 'https://example.com/video.mp4',
        );

        expect(item.id, equals('unique_id_123'));
      });

      test('url property returns correct value', () {
        const item = VideoItem(
          id: 'test',
          url: 'https://cdn.example.com/path/to/video.mp4',
        );

        expect(item.url, equals('https://cdn.example.com/path/to/video.mp4'));
      });

      test('title property returns null when not provided', () {
        const item = VideoItem(
          id: 'test',
          url: 'https://example.com/video.mp4',
        );

        expect(item.title, isNull);
      });

      test('title property returns value when provided', () {
        const item = VideoItem(
          id: 'test',
          url: 'https://example.com/video.mp4',
          title: 'My Video Title',
        );

        expect(item.title, equals('My Video Title'));
      });

      test('description property returns null when not provided', () {
        const item = VideoItem(
          id: 'test',
          url: 'https://example.com/video.mp4',
        );

        expect(item.description, isNull);
      });

      test('description property returns value when provided', () {
        const item = VideoItem(
          id: 'test',
          url: 'https://example.com/video.mp4',
          description: 'A detailed description of the video content.',
        );

        expect(
          item.description,
          equals('A detailed description of the video content.'),
        );
      });

      test('thumbnailUrl property returns null when not provided', () {
        const item = VideoItem(
          id: 'test',
          url: 'https://example.com/video.mp4',
        );

        expect(item.thumbnailUrl, isNull);
      });

      test('thumbnailUrl property returns value when provided', () {
        const item = VideoItem(
          id: 'test',
          url: 'https://example.com/video.mp4',
          thumbnailUrl: 'https://example.com/thumbnails/thumb.jpg',
        );

        expect(
          item.thumbnailUrl,
          equals('https://example.com/thumbnails/thumb.jpg'),
        );
      });
    });

    group('edge cases', () {
      test('handles empty strings for id and url', () {
        const item = VideoItem(id: '', url: '');

        expect(item.id, equals(''));
        expect(item.url, equals(''));
      });

      test('handles very long strings', () {
        final longId = 'a' * 1000;
        final longUrl = 'https://example.com/${'path/' * 100}video.mp4';

        final item = VideoItem(id: longId, url: longUrl);

        expect(item.id.length, equals(1000));
        expect(item.url.contains('video.mp4'), isTrue);
      });

      test('handles special characters in strings', () {
        const item = VideoItem(
          id: 'id-with-special_chars.123',
          url: 'https://example.com/video?id=123&format=mp4',
          title: "Title with 'quotes' and \"double quotes\"",
          description: 'Description with\nnewlines\tand\ttabs',
        );

        expect(item.id, contains('-'));
        expect(item.url, contains('?'));
        expect(item.title, contains("'"));
        expect(item.description, contains('\n'));
      });
    });
  });
}
