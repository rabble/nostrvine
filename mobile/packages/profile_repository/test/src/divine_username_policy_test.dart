import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  group('validateDivineUsername', () {
    test('accepts alice', () {
      final r = validateDivineUsername('alice');
      expect(r, isA<DivineUsernameValid>());
      expect((r as DivineUsernameValid).normalized, 'alice');
    });

    test('accepts a-b', () {
      final r = validateDivineUsername('a-b');
      expect(r, isA<DivineUsernameValid>());
      expect((r as DivineUsernameValid).normalized, 'a-b');
    });

    test('rejects a_b', () {
      final r = validateDivineUsername('a_b');
      expect(r, isA<DivineUsernameInvalid>());
    });

    test('rejects a.b', () {
      final r = validateDivineUsername('a.b');
      expect(r, isA<DivineUsernameInvalid>());
    });

    test('rejects -alice', () {
      final r = validateDivineUsername('-alice');
      expect(r, isA<DivineUsernameInvalid>());
      expect(
        (r as DivineUsernameInvalid).reason,
        "Usernames can't start or end with a hyphen",
      );
    });

    test('rejects alice-', () {
      final r = validateDivineUsername('alice-');
      expect(r, isA<DivineUsernameInvalid>());
      expect(
        (r as DivineUsernameInvalid).reason,
        "Usernames can't start or end with a hyphen",
      );
    });

    test('rejects 2-char input', () {
      final r = validateDivineUsername('ab');
      expect(r, isA<DivineUsernameInvalid>());
      expect(
        (r as DivineUsernameInvalid).reason,
        'Usernames must be $kDivineUsernameMinLength–'
        '$kDivineUsernameMaxLength characters',
      );
    });

    test('accepts 21-char input', () {
      final name = List.filled(21, 'a').join();
      final r = validateDivineUsername(name);
      expect(r, isA<DivineUsernameValid>());
      expect((r as DivineUsernameValid).normalized, name);
    });

    test('rejects 64-char input', () {
      final name = List.filled(64, 'a').join();
      final r = validateDivineUsername(name);
      expect(r, isA<DivineUsernameInvalid>());
      expect(
        (r as DivineUsernameInvalid).reason,
        'Usernames must be $kDivineUsernameMinLength–'
        '$kDivineUsernameMaxLength characters',
      );
    });

    test('normalizes case and trims', () {
      final r = validateDivineUsername('  Alice  ');
      expect(r, isA<DivineUsernameValid>());
      expect((r as DivineUsernameValid).normalized, 'alice');
    });

    test('rejects empty and whitespace-only', () {
      expect(validateDivineUsername(''), isA<DivineUsernameInvalid>());
      expect(validateDivineUsername('   '), isA<DivineUsernameInvalid>());
    });
  });

  group('normalizeDivineUsernameInput', () {
    test('lowercases and trims', () {
      expect(normalizeDivineUsernameInput('  Foo  '), 'foo');
    });
  });
}
