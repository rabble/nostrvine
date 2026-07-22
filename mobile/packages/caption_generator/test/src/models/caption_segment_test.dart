// ABOUTME: Tests for the CaptionSegment wire model.
// ABOUTME: Covers equality, map round-trips, and malformed map handling.

import 'package:caption_generator/caption_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(CaptionSegment, () {
    const segment = CaptionSegment(
      text: 'hello',
      start: Duration(milliseconds: 120),
      end: Duration(milliseconds: 480),
    );

    test('supports value equality', () {
      expect(
        segment,
        equals(
          const CaptionSegment(
            text: 'hello',
            start: Duration(milliseconds: 120),
            end: Duration(milliseconds: 480),
          ),
        ),
      );
      expect(
        segment,
        isNot(
          const CaptionSegment(
            text: 'world',
            start: Duration(milliseconds: 120),
            end: Duration(milliseconds: 480),
          ),
        ),
      );
    });

    test('exposes its duration', () {
      expect(segment.duration, equals(const Duration(milliseconds: 360)));
    });

    test('round-trips through toMap/fromMap', () {
      expect(CaptionSegment.fromMap(segment.toMap()), equals(segment));
    });

    test('fromMap throws $FormatException for missing keys', () {
      expect(
        () => CaptionSegment.fromMap(const {'text': 'hello'}),
        throwsFormatException,
      );
    });

    test('fromMap throws $FormatException for wrong value types', () {
      expect(
        () => CaptionSegment.fromMap(
          const {'text': 'hello', 'startMs': 'zero', 'endMs': 400},
        ),
        throwsFormatException,
      );
    });

    test('toString names the text and time range', () {
      expect(segment.toString(), contains('hello'));
      expect(segment.toString(), contains('120ms'));
      expect(segment.toString(), contains('480ms'));
    });
  });
}
