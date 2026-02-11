// ABOUTME: Tests for SubtitleService VTT parsing and generation.
// ABOUTME: Verifies parsing of WebVTT content and round-trip generation.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/subtitle_service.dart';

void main() {
  group(SubtitleService, () {
    group('parseVtt', () {
      test('parses standard WebVTT content', () {
        const vtt =
            'WEBVTT\n'
            '\n'
            '1\n'
            '00:00:00.500 --> 00:00:03.200\n'
            'Hello world\n'
            '\n'
            '2\n'
            '00:00:03.500 --> 00:00:06.000\n'
            'This is a test\n';

        final cues = SubtitleService.parseVtt(vtt);

        expect(cues, hasLength(2));
        expect(cues[0].start, equals(500));
        expect(cues[0].end, equals(3200));
        expect(cues[0].text, equals('Hello world'));
        expect(cues[1].start, equals(3500));
        expect(cues[1].end, equals(6000));
        expect(cues[1].text, equals('This is a test'));
      });

      test('returns empty list for empty content', () {
        expect(SubtitleService.parseVtt(''), isEmpty);
        expect(SubtitleService.parseVtt('   '), isEmpty);
      });

      test('handles VTT without cue numbers', () {
        const vtt =
            'WEBVTT\n'
            '\n'
            '00:00:01.000 --> 00:00:02.000\n'
            'No cue number\n';

        final cues = SubtitleService.parseVtt(vtt);

        expect(cues, hasLength(1));
        expect(cues[0].text, equals('No cue number'));
      });

      test('handles multi-line cue text', () {
        const vtt =
            'WEBVTT\n'
            '\n'
            '00:00:01.000 --> 00:00:03.000\n'
            'Line one\n'
            'Line two\n';

        final cues = SubtitleService.parseVtt(vtt);

        expect(cues, hasLength(1));
        expect(cues[0].text, equals('Line one\nLine two'));
      });

      test('handles MM:SS.mmm timestamp format', () {
        const vtt =
            'WEBVTT\n'
            '\n'
            '01:30.500 --> 02:00.000\n'
            'Short format\n';

        final cues = SubtitleService.parseVtt(vtt);

        expect(cues, hasLength(1));
        expect(cues[0].start, equals(90500));
        expect(cues[0].end, equals(120000));
      });

      test('skips malformed timing lines', () {
        const vtt =
            'WEBVTT\n'
            '\n'
            'not a timing line\n'
            '00:00:01.000 --> 00:00:02.000\n'
            'Valid cue\n';

        final cues = SubtitleService.parseVtt(vtt);

        expect(cues, hasLength(1));
        expect(cues[0].text, equals('Valid cue'));
      });
    });

    group('generateVtt', () {
      test('generates valid WebVTT from cues', () {
        final cues = [
          const SubtitleCue(start: 500, end: 3200, text: 'Hello world'),
          const SubtitleCue(start: 3500, end: 6000, text: 'Second cue'),
        ];

        final vtt = SubtitleService.generateVtt(cues);

        expect(vtt, startsWith('WEBVTT\n'));
        expect(vtt, contains('00:00:00.500 --> 00:00:03.200'));
        expect(vtt, contains('Hello world'));
        expect(vtt, contains('00:00:03.500 --> 00:00:06.000'));
        expect(vtt, contains('Second cue'));
      });

      test('round-trips through parse and generate', () {
        final originalCues = [
          const SubtitleCue(start: 1000, end: 3000, text: 'First'),
          const SubtitleCue(start: 4000, end: 6000, text: 'Second'),
        ];

        final vtt = SubtitleService.generateVtt(originalCues);
        final parsedCues = SubtitleService.parseVtt(vtt);

        expect(parsedCues, hasLength(2));
        expect(parsedCues[0].start, equals(originalCues[0].start));
        expect(parsedCues[0].end, equals(originalCues[0].end));
        expect(parsedCues[0].text, equals(originalCues[0].text));
        expect(parsedCues[1].start, equals(originalCues[1].start));
        expect(parsedCues[1].end, equals(originalCues[1].end));
        expect(parsedCues[1].text, equals(originalCues[1].text));
      });

      test('returns empty VTT header for empty cues', () {
        final vtt = SubtitleService.generateVtt([]);

        expect(vtt, startsWith('WEBVTT\n'));
        expect(vtt.trim(), equals('WEBVTT'));
      });
    });
  });
}
