// ABOUTME: Tests mapping Funnelcake account status into client enforcement state.
// ABOUTME: Only recognized API statuses become account enforcement state.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/services/account_status_api_client.dart';

void main() {
  group('AccountEnforcementStatus.fromFunnelcake', () {
    test('active reports no restriction', () {
      final status = AccountEnforcementStatus.fromFunnelcake(
        FunnelcakeAccountStatus.active,
      );
      expect(status.kind, AccountEnforcementKind.noRestrictionReported);
      expect(status.isEnforced, isFalse);
    });

    test('suspended and banned are enforced', () {
      expect(
        AccountEnforcementStatus.fromFunnelcake(
          FunnelcakeAccountStatus.suspended,
        ).kind,
        AccountEnforcementKind.suspended,
      );
      expect(
        AccountEnforcementStatus.fromFunnelcake(
          FunnelcakeAccountStatus.banned,
        ).kind,
        AccountEnforcementKind.banned,
      );
    });
  });
}
