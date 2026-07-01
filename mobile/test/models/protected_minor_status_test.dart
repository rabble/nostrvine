// ABOUTME: Tests mapping Keycast account status to the protected-minor state
// ABOUTME: Covers #174 detection semantics (verified_minor -> protected)

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/models/protected_minor_status.dart';

KeycastAccountStatus _status({
  required bool verifiedMinor,
  DateTime? verifiedMinorAt,
}) {
  return KeycastAccountStatus(
    email: 'a@b.com',
    emailVerified: true,
    publicKey: 'abc',
    verifiedMinor: verifiedMinor,
    verifiedMinorAt: verifiedMinorAt,
  );
}

void main() {
  group('ProtectedMinorStatus', () {
    test('notProtected() is not a protected minor', () {
      final s = ProtectedMinorStatus.notProtected();
      expect(s.isProtectedMinor, isFalse);
      expect(s.verifiedMinorAt, isNull);
    });

    test('fromKeycast(null) -> not protected', () {
      expect(
        ProtectedMinorStatus.fromKeycast(null).isProtectedMinor,
        isFalse,
      );
    });

    test('verified_minor true -> protected, carries timestamp', () {
      final at = DateTime.utc(2026, 6, 30, 12);
      final s = ProtectedMinorStatus.fromKeycast(
        _status(verifiedMinor: true, verifiedMinorAt: at),
      );
      expect(s.isProtectedMinor, isTrue);
      expect(s.verifiedMinorAt, at);
    });

    test('verified_minor false -> not protected', () {
      expect(
        ProtectedMinorStatus.fromKeycast(
          _status(verifiedMinor: false),
        ).isProtectedMinor,
        isFalse,
      );
    });
  });
}
