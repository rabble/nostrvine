// ABOUTME: Tests for grouping word-level segments into caption cues.
// ABOUTME: Covers gap, length, and duration splits plus input validation.

import 'package:caption_generator/caption_generator.dart';
import 'package:flutter_test/flutter_test.dart';

CaptionSegment _word(String text, int startMs, int endMs) => CaptionSegment(
  text: text,
  start: Duration(milliseconds: startMs),
  end: Duration(milliseconds: endMs),
);

void main() {
  group('groupCaptionSegments', () {
    test('returns an empty list for empty input', () {
      expect(groupCaptionSegments(const []), isEmpty);
    });

    test('keeps a single word as one cue', () {
      final cues = groupCaptionSegments([_word('hello', 0, 400)]);

      expect(cues, equals([_word('hello', 0, 400)]));
    });

    test('merges words within all limits into one cue', () {
      final cues = groupCaptionSegments([
        _word('hello', 0, 400),
        _word('there', 450, 800),
        _word('world', 900, 1300),
      ]);

      expect(cues, equals([_word('hello there world', 0, 1300)]));
    });

    test('starts a new cue after a long silence gap', () {
      final cues = groupCaptionSegments([
        _word('hello', 0, 400),
        _word('world', 3000, 3400),
      ]);

      expect(
        cues,
        equals([_word('hello', 0, 400), _word('world', 3000, 3400)]),
      );
    });

    test('starts a new cue when the character limit would be exceeded', () {
      final cues = groupCaptionSegments(
        [
          _word('aaaa', 0, 200),
          _word('bbbb', 250, 450),
          _word('cccc', 500, 700),
        ],
        maxCharactersPerCaption: 9,
      );

      expect(
        cues,
        equals([_word('aaaa bbbb', 0, 450), _word('cccc', 500, 700)]),
      );
    });

    test('starts a new cue when the duration limit would be exceeded', () {
      final cues = groupCaptionSegments(
        [
          _word('one', 0, 400),
          _word('two', 900, 1300),
          _word('three', 1800, 2200),
        ],
        maxCaptionDuration: const Duration(milliseconds: 1500),
      );

      expect(
        cues,
        equals([_word('one two', 0, 1300), _word('three', 1800, 2200)]),
      );
    });

    test('keeps a single word longer than the character limit as own cue', () {
      final cues = groupCaptionSegments(
        [_word('supercalifragilistic', 0, 900), _word('yes', 950, 1200)],
        maxCharactersPerCaption: 10,
      );

      expect(
        cues,
        equals([
          _word('supercalifragilistic', 0, 900),
          _word('yes', 950, 1200),
        ]),
      );
    });

    test('sorts unsorted input by start time before grouping', () {
      final cues = groupCaptionSegments([
        _word('world', 450, 800),
        _word('hello', 0, 400),
      ]);

      expect(cues, equals([_word('hello world', 0, 800)]));
    });

    test('throws $ArgumentError for a non-positive character limit', () {
      expect(
        () => groupCaptionSegments(const [], maxCharactersPerCaption: 0),
        throwsArgumentError,
      );
    });

    test('throws $ArgumentError for a non-positive duration limit', () {
      expect(
        () => groupCaptionSegments(const [], maxCaptionDuration: Duration.zero),
        throwsArgumentError,
      );
    });

    test('throws $ArgumentError for a non-positive silence gap', () {
      expect(
        () => groupCaptionSegments(const [], maxSilenceGap: Duration.zero),
        throwsArgumentError,
      );
    });
  });
}
