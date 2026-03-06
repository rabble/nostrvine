// ABOUTME: Tests for isFromDivineServer detection logic
// ABOUTME: Verifies all Divine subdomains are recognized as first-party

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/extensions/video_event_extensions.dart';

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
        ],
        'sig':
            'cccc1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
      });
      final video = VideoEvent.fromNostrEvent(event);
      expect(video.shouldShowNotDivineBadge, isFalse);
    });
  });
}
