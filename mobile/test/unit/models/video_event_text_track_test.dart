// ABOUTME: Tests for VideoEvent text-track (subtitle) tag parsing and
// nostrEventTags preservation for republishing with new tags.
// ABOUTME: Verifies support for Kind 39307 subtitle event references in video
// events, and hasSubtitles with sha256 for Blossom VTT.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';

void main() {
  // Valid 64-character hex string for test pubkey
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  group('VideoEvent nostrEventTags', () {
    test('stores original nostrEventTags from event', () {
      final originalTags = [
        ['d', 'test-vine-id'],
        ['url', 'https://example.com/video.mp4'],
        ['title', 'My Video'],
        ['t', 'test'],
      ];
      final nostrEvent = Event(
        testPubkey,
        34236,
        originalTags,
        'Video content',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.nostrEventTags, isNotEmpty);
      expect(videoEvent.nostrEventTags.length, equals(originalTags.length));
      // Verify the tags are preserved as List<List<String>>
      expect(videoEvent.nostrEventTags[0], equals(['d', 'test-vine-id']));
      expect(
        videoEvent.nostrEventTags[1],
        equals(['url', 'https://example.com/video.mp4']),
      );
    });

    test('preserves nostrEventTags through copyWith', () {
      final originalTags = [
        ['d', 'test-vine-id'],
        ['url', 'https://example.com/video.mp4'],
      ];
      final nostrEvent = Event(
        testPubkey,
        34236,
        originalTags,
        'Video content',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);
      final copied = videoEvent.copyWith(title: 'Updated Title');

      expect(copied.nostrEventTags, equals(videoEvent.nostrEventTags));
      expect(copied.title, equals('Updated Title'));
    });

    test('defaults to empty list when constructed without tags', () {
      final videoEvent = VideoEvent(
        id: 'test-id',
        pubkey: testPubkey,
        createdAt: 1757385263,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      );

      expect(videoEvent.nostrEventTags, isEmpty);
    });
  });

  group('VideoEvent text-track tag parsing', () {
    test('parses text-track tag with addressable coordinates', () {
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
          [
            'text-track',
            '39307:$testPubkey:subtitles:test-vine-id',
            'wss://relay.divine.video',
            'captions',
            'en',
          ],
        ],
        'Video content',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(
        videoEvent.textTrackRef,
        equals('39307:$testPubkey:subtitles:test-vine-id'),
      );
      expect(videoEvent.hasSubtitles, isTrue);
    });

    test('hasSubtitles is false when no text-track tag and no sha256', () {
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
        ],
        'Video content',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.textTrackRef, isNull);
      expect(videoEvent.textTrackContent, isNull);
      expect(videoEvent.sha256, isNull);
      expect(videoEvent.hasSubtitles, isFalse);
    });

    test('hasSubtitles is true when textTrackContent is present '
        '(even without ref)', () {
      final videoEvent = VideoEvent(
        id: 'test-id',
        pubkey: testPubkey,
        createdAt: 1757385263,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        textTrackContent:
            'WEBVTT\n\n1\n00:00:00.500 --> 00:00:03.200\n'
            'Hello world',
      );

      expect(videoEvent.textTrackRef, isNull);
      expect(videoEvent.textTrackContent, isNotNull);
      expect(videoEvent.hasSubtitles, isTrue);
    });

    test('hasSubtitles is true when sha256 is present '
        '(Blossom auto-generated VTT)', () {
      final videoEvent = VideoEvent(
        id: 'test-id',
        pubkey: testPubkey,
        createdAt: 1757385263,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        sha256:
            'abc123def456abc123def456abc123def456abc123def456abc123def456abcd',
      );

      expect(videoEvent.textTrackRef, isNull);
      expect(videoEvent.textTrackContent, isNull);
      expect(videoEvent.sha256, isNotNull);
      expect(videoEvent.hasSubtitles, isTrue);
    });

    test('hasSubtitles is false when sha256 is empty string', () {
      final videoEvent = VideoEvent(
        id: 'test-id',
        pubkey: testPubkey,
        createdAt: 1757385263,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        sha256: '',
      );

      expect(videoEvent.hasSubtitles, isFalse);
    });

    test('preserves textTrackRef through copyWith', () {
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
          [
            'text-track',
            '39307:$testPubkey:subtitles:test-vine-id',
            'wss://relay.divine.video',
            'captions',
            'en',
          ],
        ],
        'Video content',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);
      final copied = videoEvent.copyWith(title: 'New Title');

      expect(copied.textTrackRef, equals(videoEvent.textTrackRef));
    });

    test('preserves textTrackContent through copyWith', () {
      const vttContent =
          'WEBVTT\n\n1\n00:00:00.500 --> 00:00:03.200\n'
          'Hello world';
      final videoEvent = VideoEvent(
        id: 'test-id',
        pubkey: testPubkey,
        createdAt: 1757385263,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        textTrackContent: vttContent,
      );

      final copied = videoEvent.copyWith(title: 'New Title');

      expect(copied.textTrackContent, equals(vttContent));
    });

    test('text-track tag with HTTP URL is parsed as textTrackRef', () {
      // Backward compat: other clients may use a URL instead of coordinates
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
          [
            'text-track',
            'https://example.com/subtitles.vtt',
            '',
            'captions',
            'en',
          ],
        ],
        'Video content',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(
        videoEvent.textTrackRef,
        equals('https://example.com/subtitles.vtt'),
      );
      expect(videoEvent.hasSubtitles, isTrue);
    });
  });
}
