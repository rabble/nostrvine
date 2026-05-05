// ABOUTME: Tests for TranscriptSanitizer.
// ABOUTME: Pins behavior against the leaked-prompt example from issue #3737
// ABOUTME: and guards against false positives on conversational speech.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/transcript_sanitizer.dart';

void main() {
  group(TranscriptSanitizer, () {
    group('sanitize', () {
      test('passes through normal speech unchanged', () {
        const text = 'Hello world, this is a regular caption.';
        expect(TranscriptSanitizer.sanitize(text), equals(text));
      });

      test('passes through empty string unchanged', () {
        expect(TranscriptSanitizer.sanitize(''), equals(''));
      });

      test('strips trailing leaked LLM prompt from issue #3737', () {
        // Verbatim cue text from the bug report.
        const polluted =
            'And I promise you, if I get elected, freedom is the only '
            "option. Well, that's not really freedom now, is it, you "
            'freaking idiot? a single JSON array. Do not include any extra '
            'text outside of the JSON string. When producing JSON you must '
            'follow the schema provided in the context.';

        const expected =
            'And I promise you, if I get elected, freedom is the only '
            "option. Well, that's not really freedom now, is it, you "
            'freaking idiot?';

        expect(TranscriptSanitizer.sanitize(polluted), equals(expected));
      });

      test('strips "do not include any extra text" directive', () {
        const polluted =
            'This is real content. Do not include any extra text outside '
            'of the JSON.';
        expect(
          TranscriptSanitizer.sanitize(polluted),
          equals('This is real content.'),
        );
      });

      test('strips "follow the schema provided in the context" directive', () {
        const polluted =
            'Real transcribed line! follow the schema provided in the '
            'context.';
        expect(
          TranscriptSanitizer.sanitize(polluted),
          equals('Real transcribed line!'),
        );
      });

      test('matches markers case-insensitively', () {
        const polluted =
            'Hello there. A SINGLE JSON ARRAY. Do Not Include Any Extra '
            'Text outside of the JSON.';
        expect(
          TranscriptSanitizer.sanitize(polluted),
          equals('Hello there.'),
        );
      });

      test('returns null when entire text is prompt content', () {
        const onlyPrompt =
            'a single JSON array do not include any extra text outside '
            'of the JSON';
        expect(TranscriptSanitizer.sanitize(onlyPrompt), isNull);
      });

      test('returns null when no sentence terminator precedes marker', () {
        const noTerminator =
            'and then a single JSON array do not include any extra text';
        expect(TranscriptSanitizer.sanitize(noTerminator), isNull);
      });

      test('truncates at the earliest marker among multiple', () {
        const polluted =
            'Real content here. When producing JSON you must follow the '
            'schema. Do not include any extra text outside of the JSON.';
        expect(
          TranscriptSanitizer.sanitize(polluted),
          equals('Real content here.'),
        );
      });

      test('keeps multi-sentence content before marker', () {
        const polluted =
            'First sentence. Second sentence! Third sentence? a single '
            'JSON array.';
        expect(
          TranscriptSanitizer.sanitize(polluted),
          equals('First sentence. Second sentence! Third sentence?'),
        );
      });

      test('handles "respond with a json" variant', () {
        const polluted =
            'Hello world. Respond with a JSON object containing the '
            'transcription.';
        expect(
          TranscriptSanitizer.sanitize(polluted),
          equals('Hello world.'),
        );
      });

      test('handles "output only json" variant', () {
        const polluted = 'Hello world. Output only JSON without commentary.';
        expect(
          TranscriptSanitizer.sanitize(polluted),
          equals('Hello world.'),
        );
      });
    });
  });
}
