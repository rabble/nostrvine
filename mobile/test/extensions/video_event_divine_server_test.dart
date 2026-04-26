// ABOUTME: Tests for isFromDivineServer detection logic
// ABOUTME: Verifies all Divine subdomains are recognized as first-party

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

VideoEvent _createVideoWithUrl(String url) {
  final event = Event.fromJson({
    'id': 'aaaa1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
    'pubkey':
        'bbbb1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
    'created_at': 1234567890,
    'kind': 34236,
    'content': '',
    'tags': [
      ['url', url],
    ],
    'sig': 'cccc1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
  });
  return VideoEvent.fromNostrEvent(event);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    bandwidthTracker.clearSamples();
    await bandwidthTracker.setQualityOverride(null);
  });

  group('isFromDivineServer', () {
    test('returns true for cdn.divine.video', () {
      final video = _createVideoWithUrl(
        'https://cdn.divine.video/abc123/video.mp4',
      );
      expect(video.isFromDivineServer, isTrue);
    });

    test('returns true for stream.divine.video', () {
      final video = _createVideoWithUrl(
        'https://stream.divine.video/abc123/playlist.m3u8',
      );
      expect(video.isFromDivineServer, isTrue);
    });

    test('returns true for media.divine.video', () {
      final video = _createVideoWithUrl(
        'https://media.divine.video/abc123.mp4',
      );
      expect(video.isFromDivineServer, isTrue);
    });

    test('returns true for blossom.divine.video', () {
      final video = _createVideoWithUrl(
        'https://blossom.divine.video/'
        'abc123def456abc123def456abc123def456abc123def456abc123def456abcd.mp4',
      );
      expect(video.isFromDivineServer, isTrue);
    });

    test('returns true for bare divine.video domain', () {
      final video = _createVideoWithUrl('https://divine.video/video.mp4');
      expect(video.isFromDivineServer, isTrue);
    });

    test('returns false for external hosts', () {
      final video = _createVideoWithUrl(
        'https://blossom.primal.net/abc123.mp4',
      );
      expect(video.isFromDivineServer, isFalse);
    });

    test('returns false for other video hosts', () {
      final video = _createVideoWithUrl('https://nostr.build/video/abc123.mp4');
      expect(video.isFromDivineServer, isFalse);
    });

    test(
      'returns false for hosts that only contain divine.video in the URL',
      () {
        final video = _createVideoWithUrl(
          'https://notdivine.video.evil.com/video.mp4',
        );
        expect(video.isFromDivineServer, isFalse);
      },
    );
  });

  group('shouldShowNotDivineBadge', () {
    test('returns false for divine-hosted video', () {
      final video = _createVideoWithUrl(
        'https://cdn.divine.video/abc123/video.mp4',
      );
      expect(video.shouldShowNotDivineBadge, isFalse);
    });

    test('returns false for blossom.divine.video-hosted video', () {
      final video = _createVideoWithUrl(
        'https://blossom.divine.video/'
        'abc123def456abc123def456abc123def456abc123def456abc123def456abcd.mp4',
      );
      expect(video.shouldShowNotDivineBadge, isFalse);
    });

    test('returns true for externally hosted video', () {
      final video = _createVideoWithUrl(
        'https://blossom.primal.net/abc123.mp4',
      );
      expect(video.shouldShowNotDivineBadge, isTrue);
    });

    test('returns false for vintage vine', () {
      final event = Event.fromJson({
        'id':
            'aaaa1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
        'pubkey':
            'bbbb1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
        'created_at': 1473050841,
        'kind': 34236,
        'content': '',
        'tags': [
          ['url', 'https://example.com/video.mp4'],
          ['loops', '10000'],
          ['platform', 'vine'],
        ],
        'sig':
            'cccc1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
      });
      final video = VideoEvent.fromNostrEvent(event);
      expect(video.shouldShowNotDivineBadge, isFalse);
    });
  });

  group('getOptimalVideoUrlForPlatform', () {
    test('returns MP4 720p for Divine-hosted videos by default', () {
      const hash =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      expect(video.shouldPreferHlsPlayback, isFalse);
      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
    });

    test('uses MP4 720p for bare media.divine.video blob URLs', () {
      const hash =
          '191679cbbeea3e4e3539d46b558e66fbadb673733af1ada0161a6e8b1cf61bea';
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      expect(video.hasBareDivineHashPath, isTrue);
      expect(video.shouldPreferHlsPlayback, isFalse);
      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
    });

    test('returns original URL for non-Divine videos', () {
      final video = _createVideoWithUrl(
        'https://blossom.primal.net/test/video.mp4',
      );

      expect(video.shouldPreferHlsPlayback, isFalse);
      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://blossom.primal.net/test/video.mp4'),
      );
    });
  });

  group('hash-only Divine media URLs', () {
    const hash =
        'cfb5cf3415ec4ad3f45eff478570d898ff9a660ecea63d0c058892b22468a90d';

    test('returns MP4 cache URL for Divine videos', () {
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      expect(
        video.getCacheableVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
    });

    test('do not treat quality variants as bare hash paths', () {
      final video = _createVideoWithUrl(
        'https://media.divine.video/$hash/720p',
      );

      expect(video.hasBareDivineHashPath, isFalse);
      expect(video.shouldPreferHlsPlayback, isFalse);
    });

    test('uses MP4 720p for all Divine hosts including cdn.divine.video', () {
      final video = _createVideoWithUrl('https://cdn.divine.video/$hash');

      expect(video.shouldPreferHlsPlayback, isFalse);
      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
      expect(
        video.getCacheableVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
    });
  });

  group('getFallbackUrl', () {
    const hash =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    test('returns HLS URL for Divine-hosted videos', () {
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      final fallback = video.getFallbackUrl();
      expect(fallback, isNotNull);
      expect(fallback, contains('/hls/'));
      expect(fallback, contains('.m3u8'));
    });

    test('returns null for non-Divine videos', () {
      final video = _createVideoWithUrl(
        'https://blossom.primal.net/test/video.mp4',
      );

      expect(video.getFallbackUrl(), isNull);
    });

    test('returns different URL than getOptimalVideoUrlForPlatform', () {
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      final primary = video.getOptimalVideoUrlForPlatform();
      final fallback = video.getFallbackUrl();

      expect(primary, isNot(equals(fallback)));
    });
  });

  group('toPooledVideoItems', () {
    test('uses MP4 720p URL for Divine-hosted pooled playback', () {
      const hash =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      final items = <VideoEvent>[video].toPooledVideoItems();

      expect(items, hasLength(1));
      expect(items.single, isA<VideoItem>());
      expect(items.single.id, video.id);
      expect(
        items.single.url,
        equals('https://media.divine.video/$hash/720p.mp4'),
      );
    });

    test('filters out videos with null URLs', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000);
      final videoWithoutUrl = VideoEvent(
        id: 'deadbeef',
        pubkey:
            'bbbb1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
        createdAt: 1704067200,
        content: '',
        timestamp: now,
      );

      expect(<VideoEvent>[videoWithoutUrl].toPooledVideoItems(), isEmpty);
    });
  });
}
