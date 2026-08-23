// ABOUTME: Table-driven tests for divine username policy (#3364 AC).

import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  group('validateDivineUsername', () {
    group('acceptance criteria (#3364 table)', () {
      final cases =
          <
            ({
              String label,
              String input,
              bool valid,
              String? normalized,
              DivineUsernameValidationFailure? failure,
            })
          >[
            (
              label: 'alice',
              input: 'alice',
              valid: true,
              normalized: 'alice',
              failure: null,
            ),
            (
              label: 'a-b',
              input: 'a-b',
              valid: true,
              normalized: 'a-b',
              failure: null,
            ),
            (
              label: 'a_b',
              input: 'a_b',
              valid: false,
              normalized: null,
              failure: DivineUsernameValidationFailure.invalidCharacters,
            ),
            (
              label: 'a.b',
              input: 'a.b',
              valid: false,
              normalized: null,
              failure: DivineUsernameValidationFailure.invalidCharacters,
            ),
            (
              label: '-alice',
              input: '-alice',
              valid: false,
              normalized: null,
              failure: DivineUsernameValidationFailure.leadingOrTrailingHyphen,
            ),
            (
              label: 'alice-',
              input: 'alice-',
              valid: false,
              normalized: null,
              failure: DivineUsernameValidationFailure.leadingOrTrailingHyphen,
            ),
            (
              label: 'two chars',
              input: 'ab',
              valid: false,
              normalized: null,
              failure: DivineUsernameValidationFailure.invalidLength,
            ),
            (
              label: '21 chars (within max)',
              input: List.filled(21, 'a').join(),
              valid: true,
              normalized: List.filled(21, 'a').join(),
              failure: null,
            ),
            (
              label: '64 chars (over max)',
              input: List.filled(64, 'a').join(),
              valid: false,
              normalized: null,
              failure: DivineUsernameValidationFailure.invalidLength,
            ),
            (
              label: 'min length boundary (3)',
              input: 'abc',
              valid: true,
              normalized: 'abc',
              failure: null,
            ),
            (
              label: 'max length boundary (63)',
              input: List.filled(63, 'z').join(),
              valid: true,
              normalized: List.filled(63, 'z').join(),
              failure: null,
            ),
            (
              label: 'trim and lowercase',
              input: '  Alice  ',
              valid: true,
              normalized: 'alice',
              failure: null,
            ),
            (
              label: 'empty',
              input: '',
              valid: false,
              normalized: null,
              failure: DivineUsernameValidationFailure.required,
            ),
            (
              label: 'whitespace only',
              input: '   ',
              valid: false,
              normalized: null,
              failure: DivineUsernameValidationFailure.required,
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
            expect((r as DivineUsernameInvalid).failure, c.failure);
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
