// ABOUTME: Unit tests for AnalyticsApiService with funnelcake API
// ABOUTME: Tests byte array parsing for id/pubkey and VideoStats conversion

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/analytics_api_service.dart';

void main() {
  group('VideoStats', () {
    group('fromJson', () {
      test('parses id and pubkey from byte arrays', () {
        // Funnelcake returns id/pubkey as ASCII byte arrays
        final json = {
          'id': [
            49,
            52,
            55,
            102,
            100,
            55,
            48,
            101,
            48,
            57,
            49,
            97,
            101,
            101,
            51,
            49,
            55,
            51,
            55,
            50,
            49,
            52,
            99,
            54,
            54,
            99,
            56,
            50,
            54,
            100,
            57,
            55,
            48,
            50,
            53,
            101,
            101,
            49,
            102,
            102,
            102,
            48,
            52,
            49,
            52,
            49,
            98,
            54,
            57,
            98,
            97,
            48,
            57,
            56,
            55,
            97,
            53,
            98,
            99,
            102,
            99,
            52,
            54,
            98,
          ],
          'pubkey': [
            57,
            99,
            102,
            97,
            55,
            100,
            53,
            55,
            48,
            97,
            102,
            53,
            100,
            100,
            101,
            49,
            100,
            55,
            57,
            98,
            52,
            55,
            54,
            97,
            99,
            50,
            99,
            56,
            98,
            53,
            52,
            51,
            98,
            49,
            57,
            55,
            48,
            48,
            54,
            53,
            100,
            53,
            52,
            56,
            56,
            102,
            52,
            100,
            56,
            54,
            102,
            97,
            102,
            51,
            99,
            51,
            52,
            99,
            49,
            54,
            55,
            101,
            51,
            49,
          ],
          'created_at': 1767316187,
          'kind': 34236,
          'd_tag':
              '8bdf98cee2ae5de03d5e7a8e5fbe9ba0a7b5bf4c51ecd2d10acdc66fd8511425',
          'title': 'Test Video',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 9,
          'comments': 2,
          'reposts': 1,
          'engagement_score': 15,
          'trending_score': 5.657,
        };

        final stats = VideoStats.fromJson(json);

        expect(
          stats.id,
          '147fd70e091aee31737214c66c826d97025ee1fff04141b69ba0987a5bcfc46b',
        );
        expect(
          stats.pubkey,
          '9cfa7d570af5dde1d79b476ac2c8b543b1970065d5488f4d86faf3c34c167e31',
        );
        expect(stats.id.length, 64);
        expect(stats.pubkey.length, 64);
      });

      test('parses id and pubkey from strings', () {
        // Fallback: if API returns strings directly
        final json = {
          'id':
              '147fd70e091aee31737214c66c826d97025ee1fff04141b69ba0987a5bcfc46b',
          'pubkey':
              '9cfa7d570af5dde1d79b476ac2c8b543b1970065d5488f4d86faf3c34c167e31',
          'created_at': 1767316187,
          'kind': 34236,
          'd_tag': 'test-dtag',
          'title': 'String ID Video',
          'thumbnail': '',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 5,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 5,
        };

        final stats = VideoStats.fromJson(json);

        expect(
          stats.id,
          '147fd70e091aee31737214c66c826d97025ee1fff04141b69ba0987a5bcfc46b',
        );
        expect(
          stats.pubkey,
          '9cfa7d570af5dde1d79b476ac2c8b543b1970065d5488f4d86faf3c34c167e31',
        );
      });

      test('parses created_at from Unix timestamp', () {
        final json = {
          'id': 'abc123',
          'pubkey': 'def456',
          'created_at': 1767316187,
          'kind': 34236,
          'd_tag': '',
          'title': '',
          'thumbnail': '',
          'video_url': '',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.createdAt.year, 2026);
        expect(stats.createdAt.month, 1);
      });

      test('handles missing optional fields', () {
        final json = <String, dynamic>{
          'id': 'abc',
          'pubkey': 'def',
          'created_at': 1700000000,
          'kind': 34236,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.dTag, '');
        expect(stats.title, '');
        expect(stats.thumbnail, '');
        expect(stats.videoUrl, '');
        expect(stats.reactions, 0);
        expect(stats.trendingScore, isNull);
      });
    });

    group('toVideoEvent', () {
      test('converts VideoStats to VideoEvent correctly', () {
        final stats = VideoStats(
          id: 'event123',
          pubkey: 'pubkey456',
          createdAt: DateTime(2026, 1, 1, 12),
          kind: 34236,
          dTag: 'vine-id-789',
          title: 'My Video',
          thumbnail: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 22,
          trendingScore: 7.5,
        );

        final event = stats.toVideoEvent();

        expect(event.id, 'event123');
        expect(event.pubkey, 'pubkey456');
        expect(event.title, 'My Video');
        expect(event.videoUrl, 'https://example.com/video.mp4');
        expect(event.thumbnailUrl, 'https://example.com/thumb.jpg');
        expect(event.vineId, 'vine-id-789');
        expect(event.originalLikes, 10);
        expect(event.originalComments, 5);
        expect(event.originalReposts, 2);
      });

      test('handles empty strings as null in VideoEvent', () {
        final stats = VideoStats(
          id: 'event123',
          pubkey: 'pubkey456',
          createdAt: DateTime.now(),
          kind: 34236,
          dTag: '',
          title: '',
          thumbnail: '',
          videoUrl: '',
          reactions: 0,
          comments: 0,
          reposts: 0,
          engagementScore: 0,
        );

        final event = stats.toVideoEvent();

        expect(event.title, isNull);
        expect(event.videoUrl, isNull);
        expect(event.thumbnailUrl, isNull);
        expect(event.vineId, isNull);
      });
    });
  });

  group('AnalyticsApiService', () {
    test('isAvailable returns false when baseUrl is null', () {
      final service = AnalyticsApiService(baseUrl: null);
      expect(service.isAvailable, false);
    });

    test('isAvailable returns true when baseUrl is set', () {
      final service = AnalyticsApiService(
        baseUrl: 'https://funnelcake.staging.dvines.org',
      );
      expect(service.isAvailable, true);
    });

    test('getTrendingVideos returns empty list when not available', () async {
      final service = AnalyticsApiService(baseUrl: null);
      final videos = await service.getTrendingVideos();
      expect(videos, isEmpty);
    });

    test('getTrendingVideos parses funnelcake response', () async {
      final mockResponse = jsonEncode([
        {
          'id': [97, 98, 99, 49, 50, 51], // "abc123"
          'pubkey': [100, 101, 102, 52, 53, 54], // "def456"
          'created_at': 1767316187,
          'kind': 34236,
          'd_tag': 'test-dtag',
          'title': 'Trending Video',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 100,
          'comments': 20,
          'reposts': 5,
          'engagement_score': 150,
          'trending_score': 8.5,
        },
      ]);

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/videos');
        expect(request.url.queryParameters['sort'], 'trending');
        return http.Response(mockResponse, 200);
      });

      final service = AnalyticsApiService(
        baseUrl: 'https://funnelcake.test',
        httpClient: mockClient,
      );

      final videos = await service.getTrendingVideos();

      expect(videos.length, 1);
      expect(videos.first.id, 'abc123');
      expect(videos.first.pubkey, 'def456');
      expect(videos.first.title, 'Trending Video');
      expect(videos.first.originalLikes, 100);
    });

    test('getVideosByHashtag normalizes hashtag and fetches', () async {
      final mockResponse = jsonEncode([
        {
          'id': 'hash123',
          'pubkey': 'pub456',
          'created_at': 1767316187,
          'kind': 34236,
          'd_tag': '',
          'title': 'Nostr Video',
          'thumbnail': '',
          'video_url': 'https://example.com/nostr.mp4',
          'reactions': 50,
          'comments': 10,
          'reposts': 3,
          'engagement_score': 73,
        },
      ]);

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/search');
        expect(request.url.queryParameters['tag'], 'nostr');
        return http.Response(mockResponse, 200);
      });

      final service = AnalyticsApiService(
        baseUrl: 'https://funnelcake.test',
        httpClient: mockClient,
      );

      // Test with # prefix
      final videos = await service.getVideosByHashtag(hashtag: '#Nostr');

      expect(videos.length, 1);
      expect(videos.first.title, 'Nostr Video');
    });

    test('handles API errors gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = AnalyticsApiService(
        baseUrl: 'https://funnelcake.test',
        httpClient: mockClient,
      );

      final videos = await service.getTrendingVideos();
      expect(videos, isEmpty);
    });

    test('filters out videos without video_url', () async {
      final mockResponse = jsonEncode([
        {
          'id': 'video1',
          'pubkey': 'pub1',
          'created_at': 1767316187,
          'kind': 34236,
          'd_tag': '',
          'title': 'Has Video',
          'thumbnail': '',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 10,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 10,
        },
        {
          'id': 'video2',
          'pubkey': 'pub2',
          'created_at': 1767316187,
          'kind': 34236,
          'd_tag': '',
          'title': 'No Video URL',
          'thumbnail': '',
          'video_url': '',
          'reactions': 20,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 20,
        },
      ]);

      final mockClient = MockClient((request) async {
        return http.Response(mockResponse, 200);
      });

      final service = AnalyticsApiService(
        baseUrl: 'https://funnelcake.test',
        httpClient: mockClient,
      );

      final videos = await service.getTrendingVideos();

      expect(videos.length, 1);
      expect(videos.first.title, 'Has Video');
    });
  });
}
