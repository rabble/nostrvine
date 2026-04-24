// ABOUTME: Tests shared auth validators used by signup and account recovery.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/validators.dart';

void main() {
  const messages = AuthValidationMessages.englishDefaults;

  group(Validators, () {
    group('validateEmail', () {
      test('rejects malformed domains with consecutive dots', () {
        expect(
          Validators.validateEmail('person@gmail..com', messages: messages),
          equals('Please enter a valid email'),
        );
      });

      test('rejects addresses with consecutive dots in local part', () {
        expect(
          Validators.validateEmail(
            'first..last@example.com',
            messages: messages,
          ),
          equals('Please enter a valid email'),
        );
      });

      test('accepts normal email addresses', () {
        expect(
          Validators.validateEmail('person@example.com', messages: messages),
          isNull,
        );
      });

      test('accepts a realistic Apple Hide-My-Email relay address (#2092)', () {
        // Apple iCloud "Hide My Email" returns relay addresses with a
        // 24-char lowercase-hex local part on the privaterelay.appleid.com
        // domain. Pin this exact shape so validator tightening cannot
        // silently block iOS users who pick Hide My Email from autofill.
        expect(
          Validators.validateEmail(
            '1a2b3c4d5e6f7a8b9c0d1e2f@privaterelay.appleid.com',
            messages: messages,
          ),
          isNull,
          reason:
              'Hide-My-Email produces a 24-char lowercase-hex local part; '
              'secure-account must accept it.',
        );
      });
    });
  });
}
