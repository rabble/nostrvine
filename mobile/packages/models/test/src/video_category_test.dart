// ABOUTME: Tests for the VideoCategory model
// ABOUTME: Verifies JSON parsing, display name, emoji mapping,
// ABOUTME: and count formatting

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(VideoCategory, () {
    group('fromJson', () {
      test('parses name and video_count correctly', () {
        final json = {'name': 'music', 'video_count': 1500};
        final category = VideoCategory.fromJson(json);

        expect(category.name, equals('music'));
        expect(category.videoCount, equals(1500));
      });

      test('handles string video_count', () {
        final json = {'name': 'comedy', 'video_count': '895'};
        final category = VideoCategory.fromJson(json);

        expect(category.videoCount, equals(895));
      });

      test('handles null name', () {
        final json = <String, dynamic>{'video_count': 100};
        final category = VideoCategory.fromJson(json);

        expect(category.name, equals(''));
      });

      test('handles null video_count', () {
        final json = <String, dynamic>{'name': 'dance'};
        final category = VideoCategory.fromJson(json);

        expect(category.videoCount, equals(0));
      });

      test('handles double video_count', () {
        final json = {'name': 'sports', 'video_count': 42.0};
        final category = VideoCategory.fromJson(json);

        expect(category.videoCount, equals(42));
      });
    });

    group('displayName', () {
      test('capitalizes first letter', () {
        const category = VideoCategory(name: 'music', videoCount: 100);
        expect(category.displayName, equals('Music'));
      });

      test('returns empty string for empty name', () {
        const category = VideoCategory(name: '', videoCount: 0);
        expect(category.displayName, equals(''));
      });

      test('capitalizes single character name', () {
        const category = VideoCategory(name: 'a', videoCount: 0);
        expect(category.displayName, equals('A'));
      });
    });

    group('emoji', () {
      test('returns correct emoji for known categories', () {
        const music = VideoCategory(name: 'music', videoCount: 0);
        expect(music.emoji, equals('🎸'));

        const sports = VideoCategory(name: 'sports', videoCount: 0);
        expect(sports.emoji, equals('🏆'));

        const comedy = VideoCategory(name: 'comedy', videoCount: 0);
        expect(comedy.emoji, equals('😂'));
      });

      test('returns default emoji for unknown category', () {
        const unknown = VideoCategory(name: 'unknown', videoCount: 0);
        expect(unknown.emoji, equals('🎬'));
      });

      test('is case insensitive', () {
        const category = VideoCategory(name: 'MUSIC', videoCount: 0);
        expect(category.emoji, equals('🎸'));
      });
    });

    group('equality', () {
      test('two categories with same props are equal', () {
        const a = VideoCategory(name: 'music', videoCount: 100);
        const b = VideoCategory(name: 'music', videoCount: 100);
        expect(a, equals(b));
      });

      test('two categories with different props are not equal', () {
        const a = VideoCategory(name: 'music', videoCount: 100);
        const b = VideoCategory(name: 'music', videoCount: 200);
        expect(a, isNot(equals(b)));
      });
    });
  });
}
