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
    });
  });
}
