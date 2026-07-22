// ABOUTME: Tests for the caption track/cue models.
// ABOUTME: Covers JSON round-trips, adapters, and unknown-mode fallback.

import 'package:caption_generator/caption_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/caption_track.dart';

void main() {
  const cue = CaptionCue(
    id: 'cue-1',
    text: 'Hello world.',
    start: Duration(milliseconds: 250),
    end: Duration(milliseconds: 1750),
  );

  group(CaptionCue, () {
    test('round-trips through toJson/fromJson', () {
      expect(CaptionCue.fromJson(cue.toJson()), equals(cue));
    });

    test('fromJson throws $FormatException for malformed maps', () {
      expect(
        () => CaptionCue.fromJson(const {'id': 'x', 'text': 'y'}),
        throwsFormatException,
      );
    });

    test('adapts a recognizer segment', () {
      const segment = CaptionSegment(
        text: 'Hi there.',
        start: Duration(milliseconds: 100),
        end: Duration(milliseconds: 900),
      );

      final adapted = CaptionCue.fromSegment(segment, id: 'cue-9');

      expect(adapted.id, equals('cue-9'));
      expect(adapted.text, equals('Hi there.'));
      expect(adapted.start, equals(const Duration(milliseconds: 100)));
      expect(adapted.end, equals(const Duration(milliseconds: 900)));
    });

    test('adapts to a SubtitleCue in milliseconds', () {
      final subtitle = cue.toSubtitleCue();

      expect(subtitle.start, equals(250));
      expect(subtitle.end, equals(1750));
      expect(subtitle.text, equals('Hello world.'));
    });

    test('exposes its duration and supports copyWith', () {
      expect(cue.duration, equals(const Duration(milliseconds: 1500)));
      final moved = cue.copyWith(start: Duration.zero);
      expect(moved.id, equals(cue.id));
      expect(moved.start, equals(Duration.zero));
      expect(moved.text, equals(cue.text));
    });
  });

  group(CaptionTrack, () {
    const track = CaptionTrack(
      mode: CaptionRenderMode.overlay,
      presetId: 'classic',
      languageTag: 'de-CH',
      cues: [cue],
    );

    test('round-trips through toJson/fromJson', () {
      final decoded = CaptionTrack.fromJson(track.toJson());

      expect(decoded, equals(track));
      expect(decoded.mode, equals(CaptionRenderMode.overlay));
      expect(decoded.cues.single, equals(cue));
    });

    test('round-trips burn-in mode without cues', () {
      const burnIn = CaptionTrack(
        mode: CaptionRenderMode.burnIn,
        presetId: 'pop',
        languageTag: 'en-US',
      );

      final decoded = CaptionTrack.fromJson(burnIn.toJson());

      expect(decoded.mode, equals(CaptionRenderMode.burnIn));
      expect(decoded.cues, isEmpty);
    });

    test('falls back to overlay for an unknown serialized mode', () {
      final json = track.toJson()..['mode'] = 'holograph';

      expect(
        CaptionTrack.fromJson(json).mode,
        equals(CaptionRenderMode.overlay),
      );
    });

    test('fromJson throws $FormatException for malformed maps', () {
      expect(
        () => CaptionTrack.fromJson(const {'presetId': 1}),
        throwsFormatException,
      );
    });

    test('copyWith replaces only the given fields', () {
      final updated = track.copyWith(presetId: 'mono');

      expect(updated.presetId, equals('mono'));
      expect(updated.mode, equals(track.mode));
      expect(updated.cues, equals(track.cues));
    });
  });
}
