// ABOUTME: Tests for nextDuplicateDraftTitle
// ABOUTME: Validates numbering, suffix stripping, and locale independence

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/draft_copy_naming.dart';

// Mimics the English "{title} (copy {number})" ARB template.
String _en(String base, int number) => '$base (copy $number)';

// Mimics the Japanese "{title}（コピー {number}）" ARB template.
String _ja(String base, int number) => '$base（コピー $number）';

void main() {
  group('nextDuplicateDraftTitle', () {
    test('numbers the first copy from 1', () {
      expect(
        nextDuplicateDraftTitle(
          sourceTitle: 'Trip',
          existingTitles: const ['Trip'],
          format: _en,
        ),
        equals('Trip (copy 1)'),
      );
    });

    test('strips an existing copy suffix instead of stacking', () {
      expect(
        nextDuplicateDraftTitle(
          sourceTitle: 'Trip (copy 1)',
          existingTitles: const ['Trip', 'Trip (copy 1)'],
          format: _en,
        ),
        equals('Trip (copy 2)'),
      );
    });

    test('skips numbers already taken', () {
      expect(
        nextDuplicateDraftTitle(
          sourceTitle: 'Trip',
          existingTitles: const ['Trip', 'Trip (copy 1)', 'Trip (copy 2)'],
          format: _en,
        ),
        equals('Trip (copy 3)'),
      );
    });

    test('does not strip a copy suffix that is not at the end', () {
      expect(
        nextDuplicateDraftTitle(
          sourceTitle: 'A (copy 1) B',
          existingTitles: const [],
          format: _en,
        ),
        equals('A (copy 1) B (copy 1)'),
      );
    });

    test('treats a custom title as its own base', () {
      expect(
        nextDuplicateDraftTitle(
          sourceTitle: 'My Best Video',
          existingTitles: const [],
          format: _en,
        ),
        equals('My Best Video (copy 1)'),
      );
    });

    test('derives the strip pattern from the format for any locale', () {
      expect(
        nextDuplicateDraftTitle(
          sourceTitle: 'テスト（コピー 1）',
          existingTitles: const ['テスト（コピー 1）'],
          format: _ja,
        ),
        equals('テスト（コピー 2）'),
      );
    });
  });
}
