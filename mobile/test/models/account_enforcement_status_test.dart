// ABOUTME: Tests the account enforcement status model: mapping Keycast's
// ABOUTME: account_status to client state without leaking moderation internals.

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/models/account_enforcement_status.dart';

KeycastAccountStatus _status({String? accountStatus, String? suspendedReason}) {
  return KeycastAccountStatus(
    email: 'a@b.c',
    emailVerified: true,
    publicKey: 'p',
    verifiedMinor: false,
    accountStatus: accountStatus,
    suspendedReason: suspendedReason,
  );
}

void main() {
  group('AccountEnforcementStatus.fromKeycast', () {
    test('unverified when account_status is absent', () {
      // Keycast is a best-effort mirror of relay enforcement. Its absence is
      // not authoritative evidence that the relay considers this account
      // unrestricted.
      final s = AccountEnforcementStatus.fromKeycast(_status());

      expect(s.kind, AccountEnforcementKind.unverified);
      expect(s.isEnforced, isFalse);
    });

    test('suspended when account_status is suspended', () {
      final s = AccountEnforcementStatus.fromKeycast(
        _status(accountStatus: 'suspended'),
      );

      expect(s.kind, AccountEnforcementKind.suspended);
      expect(s.isEnforced, isTrue);
    });

    test('banned when account_status is banned', () {
      final s = AccountEnforcementStatus.fromKeycast(
        _status(accountStatus: 'banned'),
      );

      expect(s.kind, AccountEnforcementKind.banned);
      expect(s.isEnforced, isTrue);
    });

    test('an unrecognized account_status is enforced, never good standing', () {
      // Keycast sets account_status ONLY for a non-active account, so ANY
      // value we do not recognize still means the account is restricted.
      // Defaulting an unknown value to `none` would tell a restricted user
      // their account is fine and hand them the generic retry copy — the exact
      // failure s-t-s#200 exists to fix. Fail closed instead.
      final s = AccountEnforcementStatus.fromKeycast(
        _status(accountStatus: 'deactivated'),
      );

      expect(s.isEnforced, isTrue);
      expect(s.kind, isNot(AccountEnforcementKind.unverified));
    });

    test('an empty account_status is not treated as good standing', () {
      final s = AccountEnforcementStatus.fromKeycast(
        _status(accountStatus: ''),
      );

      expect(s.kind, isNot(AccountEnforcementKind.unverified));
    });
  });

  group('AccountEnforcementStatus moderation internals', () {
    // Regression guard for R-7 rather than a red/green cycle: this passes on
    // the current model and exists to keep it that way. suspended_reason is
    // free text written by whatever called Keycast's admin API, so it must
    // never reach state that copy or logging could render.
    test('suspended_reason does not alter the resulting state', () {
      final a = AccountEnforcementStatus.fromKeycast(
        _status(accountStatus: 'suspended', suspendedReason: 'moderation'),
      );
      final b = AccountEnforcementStatus.fromKeycast(
        _status(
          accountStatus: 'suspended',
          suspendedReason: 'policy_violation',
        ),
      );

      expect(a.kind, b.kind);
      expect(a.kind, AccountEnforcementKind.suspended);
    });
  });
}
