// ABOUTME: Tests for VideoItem model
// ABOUTME: Validates constructor, properties, equality, and edge cases

import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group('VideoItem', () {
    group('constructor', () {
      test('creates instance with required parameters', () {
        const item = VideoItem(
          id: 'test_id',
          url: 'https://example.com/video.mp4',
        );

        expect(item.id, equals('test_id'));
        expect(item.url, equals('https://example.com/video.mp4'));
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
      test('id returns correct value', () {
        const item = VideoItem(
          id: 'unique_id_123',
          url: 'https://example.com/video.mp4',
        );

        expect(item.id, equals('unique_id_123'));
      });

      test('url returns correct value', () {
        const item = VideoItem(
          id: 'test',
          url: 'https://cdn.example.com/path/to/video.mp4',
        );

        expect(item.url, equals('https://cdn.example.com/path/to/video.mp4'));
      });
    });

    group('equality', () {
      test('items with same id are equal', () {
        const item1 = VideoItem(
          id: 'same_id',
          url: 'https://example.com/video1.mp4',
        );
        const item2 = VideoItem(
          id: 'same_id',
          url: 'https://example.com/video2.mp4',
        );

        expect(item1, equals(item2));
      });

      test('items with different ids are not equal', () {
        const item1 = VideoItem(
          id: 'id_1',
          url: 'https://example.com/video.mp4',
        );
        const item2 = VideoItem(
          id: 'id_2',
          url: 'https://example.com/video.mp4',
        );

        expect(item1, isNot(equals(item2)));
      });

      test('props contains only id', () {
        const item = VideoItem(
          id: 'test_id',
          url: 'https://example.com/video.mp4',
        );

        expect(item.props, equals(['test_id']));
      });
    });

    group('edge cases', () {
      test('handles empty strings', () {
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

      test('handles special characters', () {
        const item = VideoItem(
          id: 'id-with-special_chars.123',
          url: 'https://example.com/video?id=123&format=mp4',
        );

        expect(item.id, contains('-'));
        expect(item.url, contains('?'));
      });
    });
  });
}
