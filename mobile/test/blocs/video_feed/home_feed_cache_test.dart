// ABOUTME: Tests for HomeFeedCache - cache read/write for home feed data
// ABOUTME: Verifies SharedPreferences caching with expiry logic

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_feed/home_feed_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(HomeFeedCache, () {
    late HomeFeedCache cache;

    setUp(() {
      cache = const HomeFeedCache();
    });

    String validFeedJson({int videoCount = 2}) {
      final videos = List.generate(
        videoCount,
        (i) => {
          'id': 'video-$i',
          'pubkey': '0' * 64,
          'video_url': 'https://example.com/video-$i.mp4',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 - i,
        },
      );
      return jsonEncode({'videos': videos});
    }

    group('read', () {
      test('returns null when no cache exists', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final result = cache.read(prefs);

        expect(result, isNull);
      });

      test('returns null when cache is expired', () async {
        final expiredTime = DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch;

        SharedPreferences.setMockInitialValues({
          homeFeedCacheKey: validFeedJson(),
          homeFeedCacheTimeKey: expiredTime,
        });
        final prefs = await SharedPreferences.getInstance();

        final result = cache.read(prefs);

        expect(result, isNull);
      });

      test('returns cached result when cache is fresh', () async {
        final freshTime = DateTime.now()
            .subtract(const Duration(minutes: 30))
            .millisecondsSinceEpoch;

        SharedPreferences.setMockInitialValues({
          homeFeedCacheKey: validFeedJson(),
          homeFeedCacheTimeKey: freshTime,
        });
        final prefs = await SharedPreferences.getInstance();

        final result = cache.read(prefs);

        expect(result, isNotNull);
        expect(result!.videos, hasLength(2));
        expect(result.videos[0].id, equals('video-0'));
        expect(result.videos[1].id, equals('video-1'));
      });

      test('returns null when cached JSON is invalid', () async {
        final freshTime = DateTime.now().millisecondsSinceEpoch;

        SharedPreferences.setMockInitialValues({
          homeFeedCacheKey: 'not valid json',
          homeFeedCacheTimeKey: freshTime,
        });
        final prefs = await SharedPreferences.getInstance();

        final result = cache.read(prefs);

        expect(result, isNull);
      });

      test('filters out videos without valid URLs', () async {
        final freshTime = DateTime.now().millisecondsSinceEpoch;
        final json = jsonEncode({
          'videos': [
            {
              'id': 'valid',
              'pubkey': '0' * 64,
              'video_url': 'https://example.com/valid.mp4',
              'created_at': 1000,
            },
            {
              'id': 'no-url',
              'pubkey': '0' * 64,
              'video_url': '',
              'created_at': 999,
            },
            {
              'id': '',
              'pubkey': '0' * 64,
              'video_url': 'https://example.com/no-id.mp4',
              'created_at': 998,
            },
          ],
        });

        SharedPreferences.setMockInitialValues({
          homeFeedCacheKey: json,
          homeFeedCacheTimeKey: freshTime,
        });
        final prefs = await SharedPreferences.getInstance();

        final result = cache.read(prefs);

        expect(result, isNotNull);
        expect(result!.videos, hasLength(1));
        expect(result.videos[0].id, equals('valid'));
      });

      test('returns null when cache time key is missing', () async {
        SharedPreferences.setMockInitialValues({
          homeFeedCacheKey: validFeedJson(),
          // No time key — defaults to epoch 0, which is > 1 hour ago
        });
        final prefs = await SharedPreferences.getInstance();

        final result = cache.read(prefs);

        expect(result, isNull);
      });
    });

    group('write', () {
      test('stores JSON and timestamp in SharedPreferences', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final json = validFeedJson();

        await cache.write(prefs, json);

        expect(prefs.getString(homeFeedCacheKey), equals(json));
        expect(prefs.getInt(homeFeedCacheTimeKey), isNotNull);
        // Timestamp should be within last second
        final storedTime = prefs.getInt(homeFeedCacheTimeKey)!;
        final diff = DateTime.now().millisecondsSinceEpoch - storedTime;
        expect(diff, lessThan(1000));
      });
    });

    group('round-trip', () {
      test('write then read returns valid result', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final json = validFeedJson(videoCount: 3);

        await cache.write(prefs, json);
        final result = cache.read(prefs);

        expect(result, isNotNull);
        expect(result!.videos, hasLength(3));
      });
    });
  });
}
