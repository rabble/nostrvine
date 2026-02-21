// ABOUTME: Tests for engagement count enrichment from Nostr tags
// ABOUTME: Verifies REST API videos get engagement stats from Nostr events

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('VideoEvent engagement enrichment', () {
    test('copyWith updates engagement fields from Nostr-parsed video', () {
      // Simulate a REST API video with no engagement stats
      // (profile endpoint returns reactions:0, no loops field)
      final restApiVideo = VideoEvent(
        id: 'abc123',
        pubkey: 'pubkey123',
        createdAt: 1473050841,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1473050841 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        originalLoops: null, // REST API has no loops field
        originalLikes: 0, // REST API reactions:0
        originalComments: 0, // REST API comments:0
        originalReposts: 0, // REST API reposts:0
        rawTags: const {}, // REST API has no raw tags
      );

      // Simulate a Nostr-parsed video with correct engagement tags
      // (fromNostrEvent correctly parses loops/likes/comments/reposts)
      final nostrParsedVideo = VideoEvent(
        id: 'abc123',
        pubkey: 'pubkey123',
        createdAt: 1473050841,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1473050841 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        originalLoops: 3169386,
        originalLikes: 273622,
        originalComments: 6023,
        originalReposts: 122059,
        rawTags: const {
          'loops': '3169386',
          'likes': '273622',
          'comments': '6023',
          'reposts': '122059',
          'd': 'MuhneZdw7aO',
        },
      );

      // Apply enrichment: copy rawTags AND engagement fields
      final enrichedVideo = restApiVideo.copyWith(
        rawTags: nostrParsedVideo.rawTags,
        originalLoops: nostrParsedVideo.originalLoops,
        originalLikes: nostrParsedVideo.originalLikes,
        originalComments: nostrParsedVideo.originalComments,
        originalReposts: nostrParsedVideo.originalReposts,
      );

      // Verify engagement fields are now populated
      expect(enrichedVideo.originalLoops, equals(3169386));
      expect(enrichedVideo.originalLikes, equals(273622));
      expect(enrichedVideo.originalComments, equals(6023));
      expect(enrichedVideo.originalReposts, equals(122059));

      // Verify rawTags are also populated
      expect(enrichedVideo.rawTags['loops'], equals('3169386'));
      expect(enrichedVideo.rawTags['likes'], equals('273622'));
    });

    test('copyWith preserves existing engagement when Nostr has null', () {
      // REST API video with some engagement data
      final restApiVideo = VideoEvent(
        id: 'abc123',
        pubkey: 'pubkey123',
        createdAt: 1473050841,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1473050841 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        originalLikes: 5, // Has some reactions
      );

      // Nostr video without engagement tags (non-classic video)
      final nostrParsedVideo = VideoEvent(
        id: 'abc123',
        pubkey: 'pubkey123',
        createdAt: 1473050841,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1473050841 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        originalLikes: null, // No likes tag in Nostr event
        rawTags: const {'d': 'some-id'},
      );

      // Enrichment with null engagement should preserve REST API values
      final enrichedVideo = restApiVideo.copyWith(
        rawTags: nostrParsedVideo.rawTags,
        originalLoops: nostrParsedVideo.originalLoops,
        originalLikes: nostrParsedVideo.originalLikes,
        originalComments: nostrParsedVideo.originalComments,
        originalReposts: nostrParsedVideo.originalReposts,
      );

      // originalLikes preserved from REST API (null doesn't override)
      expect(enrichedVideo.originalLikes, equals(5));
    });

    test(
      'fromNostrEvent correctly parses engagement tags for classic vine',
      () {
        final nostrEvent = Event(
          'abc123def456abc123def456abc123def456abc123def456abc123def456abcd',
          34236,
          [
            ['d', 'MuhneZdw7aO'],
            ['title', 'Test Classic Vine'],
            ['url', 'https://media.divine.video/testvideo'],
            ['loops', '3169386'],
            ['likes', '273622'],
            ['comments', '6023'],
            ['reposts', '122059'],
          ],
          'Test Classic Vine',
          createdAt: 1473050841,
        );

        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        expect(videoEvent.originalLoops, equals(3169386));
        expect(videoEvent.originalLikes, equals(273622));
        expect(videoEvent.originalComments, equals(6023));
        expect(videoEvent.originalReposts, equals(122059));
        expect(videoEvent.rawTags['loops'], equals('3169386'));
        expect(videoEvent.rawTags['likes'], equals('273622'));
      },
    );

    group('totalLikes', () {
      test('combines originalLikes and nostrLikeCount for Vine imports', () {
        final video = VideoEvent(
          id: 'abc123',
          pubkey: 'pubkey123',
          createdAt: 1473050841,
          content: 'Test video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1473050841 * 1000),
          videoUrl: 'https://example.com/video.mp4',
          originalLikes: 273622,
          nostrLikeCount: 5,
        );

        expect(video.totalLikes, equals(273627));
      });

      test('returns only originalLikes when nostrLikeCount is null '
          '(API-sourced video)', () {
        final video = VideoEvent(
          id: 'abc123',
          pubkey: 'pubkey123',
          createdAt: 1473050841,
          content: 'Test video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1473050841 * 1000),
          videoUrl: 'https://example.com/video.mp4',
          originalLikes: 42,
        );

        expect(video.totalLikes, equals(42));
      });

      test('returns only nostrLikeCount when originalLikes is null '
          '(relay native video)', () {
        final video = VideoEvent(
          id: 'abc123',
          pubkey: 'pubkey123',
          createdAt: 1473050841,
          content: 'Test video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1473050841 * 1000),
          videoUrl: 'https://example.com/video.mp4',
          nostrLikeCount: 7,
        );

        expect(video.totalLikes, equals(7));
      });

      test('returns 0 when both are null', () {
        final video = VideoEvent(
          id: 'abc123',
          pubkey: 'pubkey123',
          createdAt: 1473050841,
          content: 'Test video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1473050841 * 1000),
          videoUrl: 'https://example.com/video.mp4',
        );

        expect(video.totalLikes, equals(0));
      });
    });
  });
}
