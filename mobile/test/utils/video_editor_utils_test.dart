// ABOUTME: Tests for video editor time formatting utilities.
// ABOUTME: Verifies toVideoTime, toFormattedSeconds, toMmSs, and
// ABOUTME: SecondsFormatting extensions.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/video_editor_utils.dart';

void main() {
  group('VideoEditorTimeUtils', () {
    group('toVideoTime', () {
      test('formats zero duration', () {
        expect(Duration.zero.toVideoTime(), equals('00:00'));
      });

      test('formats seconds and milliseconds', () {
        const duration = Duration(seconds: 5, milliseconds: 730);

        expect(duration.toVideoTime(), equals('05:73'));
      });

      test('pads single-digit seconds', () {
        const duration = Duration(seconds: 3, milliseconds: 100);

        expect(duration.toVideoTime(), equals('03:10'));
      });
    });

    group('toFormattedSeconds', () {
      test('formats zero duration', () {
        expect(Duration.zero.toFormattedSeconds(), equals('0.00'));
      });

      test('formats with two decimal places', () {
        const duration = Duration(seconds: 5, milliseconds: 730);

        expect(duration.toFormattedSeconds(), equals('5.73'));
      });
    });

    group('toMmSs', () {
      test('formats zero duration', () {
        expect(Duration.zero.toMmSs(), equals('00:00'));
      });

      test('formats seconds only', () {
        const duration = Duration(seconds: 5);

        expect(duration.toMmSs(), equals('00:05'));
      });

      test('formats minutes and seconds', () {
        const duration = Duration(minutes: 1, seconds: 5);

        expect(duration.toMmSs(), equals('01:05'));
      });

      test('pads single-digit values', () {
        const duration = Duration(minutes: 2, seconds: 3);

        expect(duration.toMmSs(), equals('02:03'));
      });

      test('handles durations over an hour', () {
        const duration = Duration(hours: 1, minutes: 5, seconds: 30);

        expect(duration.toMmSs(), equals('65:30'));
      });
    });
  });

  group('SecondsFormatting', () {
    group('toMmSs', () {
      test('formats zero', () {
        expect(0.toMmSs(), equals('00:00'));
      });

      test('formats seconds under a minute', () {
        expect(5.0.toMmSs(), equals('00:05'));
      });

      test('formats fractional seconds', () {
        expect(65.3.toMmSs(), equals('01:05'));
      });

      test('formats integer values', () {
        expect(120.toMmSs(), equals('02:00'));
      });
    });
  });
}
