// ABOUTME: Table-driven tests for divine username policy (#3364 AC).

import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  const hyphenEdgeReason = "Usernames can't start or end with a hyphen";
  const charsetReason =
      'Only letters, numbers, and hyphens are allowed '
      '(your username becomes username.divine.video)';
  const requiredReason = 'Username is required';

  String lengthFailureReason() =>
      'Usernames must be $kDivineUsernameMinLength–'
      '$kDivineUsernameMaxLength characters';

  group('validateDivineUsername', () {
    group('acceptance criteria (#3364 table)', () {
      final cases =
          <
            ({
              String label,
              String input,
              bool valid,
              String? normalized,
              String? reason,
            })
          >[
            (
              label: 'alice',
              input: 'alice',
              valid: true,
              normalized: 'alice',
              reason: null,
            ),
            (
              label: 'a-b',
              input: 'a-b',
              valid: true,
              normalized: 'a-b',
              reason: null,
            ),
            (
              label: 'a_b',
              input: 'a_b',
              valid: false,
              normalized: null,
              reason: charsetReason,
            ),
            (
              label: 'a.b',
              input: 'a.b',
              valid: false,
              normalized: null,
              reason: charsetReason,
            ),
            (
              label: '-alice',
              input: '-alice',
              valid: false,
              normalized: null,
              reason: hyphenEdgeReason,
            ),
            (
              label: 'alice-',
              input: 'alice-',
              valid: false,
              normalized: null,
              reason: hyphenEdgeReason,
            ),
            (
              label: 'two chars',
              input: 'ab',
              valid: false,
              normalized: null,
              reason: lengthFailureReason(),
            ),
            (
              label: '21 chars (within max)',
              input: List.filled(21, 'a').join(),
              valid: true,
              normalized: List.filled(21, 'a').join(),
              reason: null,
            ),
            (
              label: '64 chars (over max)',
              input: List.filled(64, 'a').join(),
              valid: false,
              normalized: null,
              reason: lengthFailureReason(),
            ),
            (
              label: 'min length boundary (3)',
              input: 'abc',
              valid: true,
              normalized: 'abc',
              reason: null,
            ),
            (
              label: 'max length boundary (63)',
              input: List.filled(63, 'z').join(),
              valid: true,
              normalized: List.filled(63, 'z').join(),
              reason: null,
            ),
            (
              label: 'trim and lowercase',
              input: '  Alice  ',
              valid: true,
              normalized: 'alice',
              reason: null,
            ),
            (
              label: 'empty',
              input: '',
              valid: false,
              normalized: null,
              reason: requiredReason,
            ),
            (
              label: 'whitespace only',
              input: '   ',
              valid: false,
              normalized: null,
              reason: requiredReason,
            ),
          ];

      for (final c in cases) {
        test(c.label, () {
          final r = validateDivineUsername(c.input);
          if (c.valid) {
            expect(r, isA<DivineUsernameValid>());
            expect(
              (r as DivineUsernameValid).normalized,
              c.normalized,
              reason: 'normalized output',
            );
          } else {
            expect(r, isA<DivineUsernameInvalid>());
            expect((r as DivineUsernameInvalid).reason, c.reason);
          }
        });
      }
    });
  });

  group('normalizeDivineUsernameInput', () {
    test('lowercases and trims', () {
      expect(normalizeDivineUsernameInput('  Foo  '), 'foo');
    });
  });
}
