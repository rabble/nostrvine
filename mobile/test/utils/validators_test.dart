// ABOUTME: Tests shared auth validators used by signup and account recovery.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/validators.dart';

void main() {
  group(Validators, () {
    group('validateEmail', () {
      test('rejects malformed domains with consecutive dots', () {
        expect(
          Validators.validateEmail('person@gmail..com'),
          equals('Please enter a valid email'),
        );
      });

      test('rejects addresses with consecutive dots in local part', () {
        expect(
          Validators.validateEmail('first..last@example.com'),
          equals('Please enter a valid email'),
        );
      });

      test('accepts normal email addresses', () {
        expect(Validators.validateEmail('person@example.com'), isNull);
      });
    });
  });
}
