// ABOUTME: Tests for the allow_audio_reuse marker derivation on video events,
// ABOUTME: including recovery from rawTags after a JSON-cache round-trip.

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('VideoEvent.allowAudioReuse', () {
    Event buildEvent({required bool withMarker}) {
      return Event(
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        34236,
        [
          const ['d', 'audio-reuse-d-tag'],
          const ['url', 'https://media.divine.video/reuse.mp4'],
          if (withMarker) const ['allow_audio_reuse', 'true'],
        ],
        'Audio reuse video',
        createdAt: 1778120201,
      );
    }

    test('is true when the live event carries the marker', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(withMarker: true));

      expect(video.allowAudioReuse, isTrue);
    });

    test('is false when the live event omits the marker', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(withMarker: false));

      expect(video.allowAudioReuse, isFalse);
    });

    test('survives a JSON-cache round-trip that drops nostrEventTags', () {
      final original = VideoEvent.fromNostrEvent(buildEvent(withMarker: true));

      final restored = VideoEvent.fromJson(original.toJson());

      // Regression guard: the cache path drops nostrEventTags but preserves
      // rawTags, so the marker must still be recoverable.
      expect(restored.nostrEventTags, isEmpty);
      expect(restored.allowAudioReuse, isTrue);
    });

    test('is true from a rawTags-only cached event', () {
      final video = VideoEvent(
        id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        pubkey:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        createdAt: 1778120201,
        content: '',
        timestamp: DateTime.utc(2026, 5, 7),
        title: 'Audio reuse video',
        videoUrl: 'https://media.divine.video/reuse.mp4',
        rawTags: const {'allow_audio_reuse': 'true'},
      );

      expect(video.allowAudioReuse, isTrue);
    });

    test('is false from a cached event without the marker', () {
      final video = VideoEvent(
        id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        pubkey:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        createdAt: 1778120201,
        content: '',
        timestamp: DateTime.utc(2026, 5, 7),
        title: 'Audio reuse video',
        videoUrl: 'https://media.divine.video/reuse.mp4',
      );

      expect(video.allowAudioReuse, isFalse);
    });
  });
}
