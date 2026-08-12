// ABOUTME: Unit tests for the video card meta-line resolver.
// ABOUTME: Pins which videos surface a public count and which show only a date.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/video_card_meta.dart';

const _vineEraCreatedAt = 1398124800; // 2014-04-22
const _divineEraCreatedAt = 1735689600; // 2025-01-01

VideoEvent _video({
  int? originalLoops,
  Map<String, String> rawTags = const {},
  int createdAt = _divineEraCreatedAt,
  String? publishedAt,
  List<String> hashtags = const [],
}) {
  return VideoEvent(
    id: 'a' * 64,
    pubkey: 'b' * 64,
    createdAt: createdAt,
    content: 'caption',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      createdAt * 1000,
      isUtc: true,
    ),
    originalLoops: originalLoops,
    rawTags: rawTags,
    publishedAt: publishedAt,
    hashtags: hashtags,
  );
}

/// A classic Vine: archival loops plus a Vine-era `published_at`.
///
/// `platform: vine` is what [VideoEvent.isOriginalVine] keys off — it is
/// relay metadata from Funnelcake, so it cannot be spoofed by a crafted event.
VideoEvent _classicVine({int? originalLoops = 2100000, int liveViews = 0}) {
  return _video(
    originalLoops: originalLoops,
    createdAt: _vineEraCreatedAt,
    publishedAt: '$_vineEraCreatedAt',
    rawTags: {
      'platform': 'vine',
      'published_at': '$_vineEraCreatedAt',
      if (liveViews > 0) 'views': '$liveViews',
    },
  );
}

void main() {
  group('resolveVideoCardMeta', () {
    group('with the flag off', () {
      test('returns the combined loop count and no date', () {
        final meta = resolveVideoCardMeta(
          video: _video(originalLoops: 12, rawTags: {'views': '5'}),
          isOwnVideo: false,
          showPostDate: false,
        );

        expect(meta.loopCount, equals(17));
        expect(meta.timestamp, isNull);
      });

      test('reports zero rather than nothing for a null video', () {
        final meta = resolveVideoCardMeta(
          video: null,
          isOwnVideo: false,
          showPostDate: false,
        );

        expect(meta.loopCount, equals(0));
        expect(meta.isEmpty, isFalse);
      });
    });

    group('with the flag on, for a stranger', () {
      test('hides a small count on a new diVine post', () {
        final meta = resolveVideoCardMeta(
          video: _video(rawTags: {'views': '7'}),
          isOwnVideo: false,
          showPostDate: true,
        );

        expect(meta.timestamp, equals(_divineEraCreatedAt));
        expect(meta.loopCount, isNull);
      });

      test('hides a small count on a classic Vine too', () {
        // The archival source does not redeem a discouraging number: 47 loops
        // reads as a warning whether it was earned in 2014 or last week.
        final meta = resolveVideoCardMeta(
          video: _classicVine(originalLoops: 47),
          isOwnVideo: false,
          showPostDate: true,
        );

        expect(meta.loopCount, isNull);
        expect(meta.timestamp, equals(_vineEraCreatedAt));
      });

      test('surfaces a large count on a classic Vine', () {
        final meta = resolveVideoCardMeta(
          video: _classicVine(),
          isOwnVideo: false,
          showPostDate: true,
        );

        expect(meta.loopCount, equals(2100000));
        expect(meta.timestamp, equals(_vineEraCreatedAt));
      });

      test('surfaces a large count on a diVine-native post', () {
        // A genuinely popular new video earns the same social proof a famous
        // Vine gets — the rule is about size, not about provenance.
        final meta = resolveVideoCardMeta(
          video: _video(rawTags: {'views': '50000'}),
          isOwnVideo: false,
          showPostDate: true,
        );

        expect(meta.loopCount, equals(50000));
      });

      test('excludes live diVine views from a classic Vine count', () {
        final meta = resolveVideoCardMeta(
          video: _classicVine(liveViews: 340),
          isOwnVideo: false,
          showPostDate: true,
        );

        expect(meta.loopCount, equals(2100000));
      });

      test('withholds the count when no archival figure survived', () {
        final meta = resolveVideoCardMeta(
          video: _classicVine(originalLoops: null, liveViews: 340),
          isOwnVideo: false,
          showPostDate: true,
        );

        expect(meta.loopCount, isNull);
      });

      test('shows a count exactly at the floor', () {
        final meta = resolveVideoCardMeta(
          video: _video(rawTags: {'views': '$publicLoopCountFloor'}),
          isOwnVideo: false,
          showPostDate: true,
        );

        expect(meta.loopCount, equals(publicLoopCountFloor));
      });

      test('hides a count one below the floor', () {
        final meta = resolveVideoCardMeta(
          video: _video(rawTags: {'views': '${publicLoopCountFloor - 1}'}),
          isOwnVideo: false,
          showPostDate: true,
        );

        expect(meta.loopCount, isNull);
      });
    });

    group('with the flag on, for your own video', () {
      test('surfaces both the date and the combined count', () {
        final meta = resolveVideoCardMeta(
          video: _video(originalLoops: 3, rawTags: {'views': '9'}),
          isOwnVideo: true,
          showPostDate: true,
        );

        expect(meta.timestamp, equals(_divineEraCreatedAt));
        expect(meta.loopCount, equals(12));
      });

      test('keeps a count below the floor visible to its creator', () {
        final meta = resolveVideoCardMeta(
          video: _video(rawTags: {'views': '7'}),
          isOwnVideo: true,
          showPostDate: true,
        );

        expect(meta.loopCount, equals(7));
      });

      test('keeps a genuine zero visible to its creator', () {
        final meta = resolveVideoCardMeta(
          video: _video(rawTags: {'views': '0'}),
          isOwnVideo: true,
          showPostDate: true,
        );

        expect(meta.loopCount, equals(0));
      });

      test('reports the combined total on a claimed classic Vine', () {
        // Performance data for the creator, so live views count: 2.1M
        // archival plus 340 live.
        final meta = resolveVideoCardMeta(
          video: _classicVine(liveViews: 340),
          isOwnVideo: true,
          showPostDate: true,
        );

        expect(meta.loopCount, equals(2100340));
      });
    });

    group('with the flag on, for edge cases', () {
      test('omits the date when the original date is unrecoverable', () {
        // No published_at tag and a createdAt after Vine shut down: the
        // import could not recover when this was actually posted.
        final video = _video(
          originalLoops: 900000,
          rawTags: {'platform': 'vine'},
        );
        expect(
          video.hasUnknownOriginalDate,
          isTrue,
          reason: 'fixture must exercise the unknown-date branch',
        );

        final meta = resolveVideoCardMeta(
          video: video,
          isOwnVideo: false,
          showPostDate: true,
        );

        expect(meta.timestamp, isNull);
        expect(meta.loopCount, equals(900000));
      });

      test('is empty for a null video so the caller omits the line', () {
        final meta = resolveVideoCardMeta(
          video: null,
          isOwnVideo: false,
          showPostDate: true,
        );

        expect(meta.isEmpty, isTrue);
      });

      test('prefers published_at over createdAt when both are present', () {
        final meta = resolveVideoCardMeta(
          video: _video(publishedAt: '$_vineEraCreatedAt'),
          isOwnVideo: false,
          showPostDate: true,
        );

        expect(meta.timestamp, equals(_vineEraCreatedAt));
      });
    });
  });
}
