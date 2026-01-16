// ABOUTME: Tests for RepostResolver - kind 16 repost event resolution.
// ABOUTME: Verifies tag extraction, caching, and relay fetching logic.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:models/models.dart';
import 'package:openvine/services/repost_resolver.dart';

void main() {
  group('RepostResolver', () {
    group('extractTags', () {
      test('extracts e tag (event ID reference)', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(
          tags: [
            ['e', 'abc123eventid'],
          ],
        );

        final tags = resolver.extractTags(event);

        expect(tags.eventId, equals('abc123eventid'));
        expect(tags.addressableId, isNull);
      });

      test('extracts a tag (addressable reference)', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(
          tags: [
            ['a', '34236:pubkey123:d-tag-value'],
          ],
        );

        final tags = resolver.extractTags(event);

        expect(tags.eventId, isNull);
        expect(tags.addressableId, equals('34236:pubkey123:d-tag-value'));
      });

      test('extracts both e and a tags', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(
          tags: [
            ['e', 'eventid123'],
            ['a', '34236:pubkey:dtag'],
          ],
        );

        final tags = resolver.extractTags(event);

        expect(tags.eventId, equals('eventid123'));
        expect(tags.addressableId, equals('34236:pubkey:dtag'));
      });

      test('returns nulls when no relevant tags', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(
          tags: [
            ['p', 'somepubkey'],
            ['t', 'hashtag'],
          ],
        );

        final tags = resolver.extractTags(event);

        expect(tags.eventId, isNull);
        expect(tags.addressableId, isNull);
      });
    });

    group('parseAddressableId', () {
      test('parses valid addressable ID', () {
        final resolver = _createResolver();

        final parsed = resolver.parseAddressableId('34236:pubkey123:my-d-tag');

        expect(parsed, isNotNull);
        expect(parsed!.kind, equals(34236));
        expect(parsed.pubkey, equals('pubkey123'));
        expect(parsed.dTag, equals('my-d-tag'));
      });

      test('returns null for invalid format (too few parts)', () {
        final resolver = _createResolver();

        expect(resolver.parseAddressableId('34236:pubkey'), isNull);
        expect(resolver.parseAddressableId('34236'), isNull);
        expect(resolver.parseAddressableId(''), isNull);
      });

      test('returns null for non-numeric kind', () {
        final resolver = _createResolver();

        expect(resolver.parseAddressableId('notanumber:pubkey:dtag'), isNull);
      });
    });

    group('isLikelyVideoRepost', () {
      test('returns true for content with video keywords', () {
        final resolver = _createResolver();

        expect(
          resolver.isLikelyVideoRepost(
            _createRepostEvent(content: 'Check out this video!'),
          ),
          isTrue,
        );
        expect(
          resolver.isLikelyVideoRepost(
            _createRepostEvent(content: 'Amazing clip'),
          ),
          isTrue,
        );
        expect(
          resolver.isLikelyVideoRepost(_createRepostEvent(content: 'file.mp4')),
          isTrue,
        );
      });

      test('returns true for hashtags with video keywords', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(
          tags: [
            ['t', 'vine'],
          ],
        );

        expect(resolver.isLikelyVideoRepost(event), isTrue);
      });

      test('returns true for k tag indicating video kind', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(
          tags: [
            ['k', '34236'],
          ],
        );

        expect(resolver.isLikelyVideoRepost(event), isTrue);
      });

      test('returns true by default (conservative approach)', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(content: 'just some text');

        // Current implementation defaults to true to avoid missing content
        expect(resolver.isLikelyVideoRepost(event), isTrue);
      });
    });

    group('createRepostVideoEvent', () {
      test('creates repost with correct metadata', () {
        final resolver = _createResolver();
        final original = _createVideoEvent(
          id: 'original-id',
          pubkey: 'original-author',
        );
        final repostEvent = _createRepostEvent(
          id: 'repost-id',
          pubkey: 'reposter-pubkey',
          createdAt: 1700000000,
        );

        final repost = resolver.createRepostVideoEvent(original, repostEvent);

        expect(repost.isRepost, isTrue);
        expect(repost.reposterPubkey, equals('reposter-pubkey'));
        expect(repost.id, equals('original-id'));
      });
    });

    group('resolve', () {
      test(
        'returns null for non-video reposts when filtering is strict',
        () async {
          // This test verifies the isLikelyVideoRepost check
          // Currently defaults to true, but structure is in place for stricter filtering
          final resolver = _createResolver();
          final event = _createRepostEvent(
            content: 'not a video',
            tags: [], // No video indicators
          );

          final result = await resolver.resolve(event, fetchFromRelay: false);

          // Currently returns null because no tags to resolve
          expect(result, isNull);
        },
      );

      test(
        'resolves from cache when original is cached (by addressable)',
        () async {
          final cachedVideo = _createVideoEvent(
            id: 'cached-video-id',
            pubkey: 'author123',
          );

          final resolver = RepostResolver(
            subscribe: (_) => const Stream.empty(),
            findByAddressable: (pubkey, dTag) {
              if (pubkey == 'author123' && dTag == 'my-video') {
                return cachedVideo;
              }
              return null;
            },
            findById: (_) => null,
          );

          final repostEvent = _createRepostEvent(
            tags: [
              ['a', '34236:author123:my-video'],
            ],
          );

          final result = await resolver.resolve(
            repostEvent,
            fetchFromRelay: false,
          );

          expect(result, isNotNull);
          expect(result!.isRepost, isTrue);
          expect(result.id, equals('cached-video-id'));
        },
      );

      test(
        'resolves from cache when original is cached (by event ID)',
        () async {
          final cachedVideo = _createVideoEvent(
            id: 'event-123',
            pubkey: 'author',
          );

          final resolver = RepostResolver(
            subscribe: (_) => const Stream.empty(),
            findByAddressable: (_, __) => null,
            findById: (eventId) {
              if (eventId == 'event-123') {
                return cachedVideo;
              }
              return null;
            },
          );

          final repostEvent = _createRepostEvent(
            tags: [
              ['e', 'event-123'],
            ],
          );

          final result = await resolver.resolve(
            repostEvent,
            fetchFromRelay: false,
          );

          expect(result, isNotNull);
          expect(result!.isRepost, isTrue);
        },
      );

      test(
        'returns null when not cached and fetchFromRelay is false',
        () async {
          final resolver = _createResolver();
          final repostEvent = _createRepostEvent(
            tags: [
              ['a', '34236:author:dtag'],
            ],
          );

          final result = await resolver.resolve(
            repostEvent,
            fetchFromRelay: false,
          );

          expect(result, isNull);
        },
      );
    });
  });
}

/// Helper to create a resolver with empty/null callbacks
RepostResolver _createResolver({
  Stream<Event> Function(List<Filter>)? subscribe,
  VideoEvent? Function(String, String)? findByAddressable,
  VideoEvent? Function(String)? findById,
}) {
  return RepostResolver(
    subscribe: subscribe ?? (_) => const Stream.empty(),
    findByAddressable: findByAddressable ?? (_, __) => null,
    findById: findById ?? (_) => null,
  );
}

/// Helper to create a repost event (kind 16)
Event _createRepostEvent({
  String id = 'repost-event-id',
  String pubkey = 'reposter-pubkey',
  int createdAt = 1700000000,
  String content = '',
  List<List<String>> tags = const [],
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': 16,
    'tags': tags,
    'content': content,
    'sig': 'signature',
  });
}

/// Helper to create a video event for testing
VideoEvent _createVideoEvent({
  String id = 'video-id',
  String pubkey = 'author-pubkey',
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: 1700000000,
    content: 'Video content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
    videoUrl: 'https://example.com/video.mp4',
  );
}
