// ABOUTME: Unit tests for AuthenticationSource enum, covering the nip07 variant
// ABOUTME: and the fromCode round-trip / fallback behaviour.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/authentication_source.dart';

void main() {
  group(AuthenticationSource, () {
    test('nip07 round-trips through code', () {
      expect(
        AuthenticationSource.fromCode(AuthenticationSource.nip07.code),
        equals(AuthenticationSource.nip07),
      );
    });

    test('nip07 code is "nip07"', () {
      expect(AuthenticationSource.nip07.code, equals('nip07'));
    });

    test('unknown code falls back to none', () {
      expect(
        AuthenticationSource.fromCode('not-a-thing'),
        equals(AuthenticationSource.none),
      );
    });
  });
}
