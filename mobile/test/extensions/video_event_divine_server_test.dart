// ABOUTME: Tests for isFromDivineServer detection logic
// ABOUTME: Verifies all Divine subdomains are recognized as first-party

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

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
    test('returns original MP4 for Divine-hosted videos on desktop hosts', () {
      const url =
          'https://media.divine.video/'
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef.mp4';
      final video = _createVideoWithUrl(url);

      expect(video.getOptimalVideoUrlForPlatform(), url);
    });

    test('prefers HLS for bare media.divine.video blob URLs', () {
      const hash =
          '191679cbbeea3e4e3539d46b558e66fbadb673733af1ada0161a6e8b1cf61bea';
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      expect(video.hasBareDivineHashPath, isTrue);
      expect(video.shouldPreferHlsPlayback, isTrue);
      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://media.divine.video/$hash/hls/master.m3u8'),
      );
    });

    test('keeps explicit MP4 URLs unchanged on Divine hosts', () {
      final video = _createVideoWithUrl(
        'https://media.divine.video/test/video.mp4',
      );

      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://media.divine.video/test/video.mp4'),
      );
    });
  });

  group('hash-only Divine media URLs', () {
    const hash =
        'cfb5cf3415ec4ad3f45eff478570d898ff9a660ecea63d0c058892b22468a90d';

    test('skip direct-file caching for bare hash paths', () {
      final video = _createVideoWithUrl('https://media.divine.video/$hash');

      expect(video.shouldSkipFileCaching, isTrue);
      expect(video.getCacheableVideoUrlForPlatform(), isNull);
    });

    test('do not treat quality variants as bare hash paths', () {
      final video = _createVideoWithUrl(
        'https://media.divine.video/$hash/720p',
      );

      expect(video.hasBareDivineHashPath, isFalse);
      expect(video.shouldPreferHlsPlayback, isFalse);
    });

    test('do not force HLS for bare hash paths on cdn.divine.video', () {
      final video = _createVideoWithUrl('https://cdn.divine.video/$hash');

      expect(video.hasBareDivineHashPath, isFalse);
      expect(video.shouldPreferHlsPlayback, isFalse);
      expect(
        video.getOptimalVideoUrlForPlatform(),
        equals('https://cdn.divine.video/$hash'),
      );
      expect(
        video.getCacheableVideoUrlForPlatform(),
        equals('https://cdn.divine.video/$hash'),
      );
    });
  });

  group('toPooledVideoItems', () {
    test('uses the platform-aware URL for pooled playback', () {
      const url =
          'https://media.divine.video/'
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef.mp4';
      final video = _createVideoWithUrl(url);

      final items = <VideoEvent>[video].toPooledVideoItems();

      expect(items, hasLength(1));
      expect(items.single, isA<VideoItem>());
      expect(items.single.id, video.id);
      expect(items.single.url, url);
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
