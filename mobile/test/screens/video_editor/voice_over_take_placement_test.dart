// ABOUTME: Unit tests for placeVoiceOverTakes.
// ABOUTME: Covers back-to-back layout, wrap, clamp, zero-window skip, ids.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/screens/video_editor/voice_over_take_placement.dart';

void main() {
  group('placeVoiceOverTakes', () {
    const nowMs = 1000;
    const available = Duration(seconds: 6);

    AudioEvent take(String id) => AudioEvent.fromLocalImport(
      id: id,
      filePath: '/tmp/$id.m4a',
      createdAt: 0,
      title: id,
      mimeType: 'audio/mp4',
    );

    test('lays a single take from zero', () {
      final placed = placeVoiceOverTakes(
        takes: [take('a')],
        takeDurationsSecs: const [2],
        availableDuration: available,
        nowMs: nowMs,
      );

      expect(placed, hasLength(1));
      expect(placed.single.startTime, equals(Duration.zero));
      expect(placed.single.endTime, equals(const Duration(seconds: 2)));
      expect(placed.single.duration, equals(2));
    });

    test('lays multiple takes back-to-back', () {
      final placed = placeVoiceOverTakes(
        takes: [take('a'), take('b')],
        takeDurationsSecs: const [2, 3],
        availableDuration: available,
        nowMs: nowMs,
      );

      expect(placed, hasLength(2));
      expect(placed[0].startTime, equals(Duration.zero));
      expect(placed[0].endTime, equals(const Duration(seconds: 2)));
      expect(placed[1].startTime, equals(const Duration(seconds: 2)));
      expect(placed[1].endTime, equals(const Duration(seconds: 5)));
    });

    test('wraps back to zero once the cursor fills the video', () {
      final placed = placeVoiceOverTakes(
        takes: [take('a'), take('b')],
        takeDurationsSecs: const [6, 2],
        availableDuration: available,
        nowMs: nowMs,
      );

      expect(placed, hasLength(2));
      // First take fills the whole video.
      expect(placed[0].startTime, equals(Duration.zero));
      expect(placed[0].endTime, equals(available));
      // Cursor reached the end, so the second take restarts at zero.
      expect(placed[1].startTime, equals(Duration.zero));
      expect(placed[1].endTime, equals(const Duration(seconds: 2)));
    });

    test('clamps a take that overruns the video to the end', () {
      final placed = placeVoiceOverTakes(
        takes: [take('a')],
        takeDurationsSecs: const [10],
        availableDuration: available,
        nowMs: nowMs,
      );

      expect(placed.single.startTime, equals(Duration.zero));
      expect(placed.single.endTime, equals(available));
    });

    test('skips zero-duration takes', () {
      final placed = placeVoiceOverTakes(
        takes: [take('a'), take('b'), take('c')],
        takeDurationsSecs: const [0, 2, 0],
        availableDuration: available,
        nowMs: nowMs,
      );

      expect(placed, hasLength(1));
      expect(placed.single.id, startsWith('b'));
      expect(placed.single.startTime, equals(Duration.zero));
      expect(placed.single.endTime, equals(const Duration(seconds: 2)));
    });

    test(
      'suffixes ids with nowMs and the original index so takes are unique',
      () {
        final placed = placeVoiceOverTakes(
          takes: [take('a'), take('a')],
          takeDurationsSecs: const [2, 2],
          availableDuration: available,
          nowMs: nowMs,
        );

        expect(placed[0].id, equals('a-$nowMs-0'));
        expect(placed[1].id, equals('a-$nowMs-1'));
        expect(placed[0].id, isNot(equals(placed[1].id)));
      },
    );

    test('returns empty when every window is zero-width', () {
      final placed = placeVoiceOverTakes(
        takes: [take('a')],
        takeDurationsSecs: const [0],
        availableDuration: available,
        nowMs: nowMs,
      );

      expect(placed, isEmpty);
    });
  });
}
