// ABOUTME: Tests the protected-minor DM send policy (#176) — the app-level
// ABOUTME: composition (DM restriction ∩ approved official) injected into
// ABOUTME: NIP17MessageService as a DmSendPolicy.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart' show DmSendPolicyDecision;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/official_accounts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOfficials extends Mock implements OfficialAccountsService {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  const hqHex =
      'c4a39f1291291d452405cd8ddd798c4a29a3858c52cd0d843f1f6852cf17682e';
  const strangerHex =
      'deadbeef00000000000000000000000000000000000000000000000000000000';

  late _MockOfficials officials;

  setUp(() {
    officials = _MockOfficials();
  });

  ProviderContainer containerWith({required bool isRestricted}) =>
      ProviderContainer(
        overrides: [
          isDmRestrictedProvider.overrideWithValue(isRestricted),
          hasConfirmedDmRestrictionProvider.overrideWithValue(isRestricted),
          officialAccountsServiceProvider.overrideWithValue(officials),
        ],
      );

  test(
    'an unrestricted user may send to anyone; officials not consulted',
    () async {
      final container = containerWith(isRestricted: false);
      final policy = container.read(dmSendPolicyProvider);

      expect(await policy(strangerHex), DmSendPolicyDecision.allowed);
      verifyNever(() => officials.isApprovedMinorDmRecipient(any()));
    },
  );

  test('a restricted user may send to an approved official', () async {
    when(
      () => officials.isApprovedMinorDmRecipient(hqHex),
    ).thenAnswer((_) async => true);
    final container = containerWith(isRestricted: true);
    final policy = container.read(dmSendPolicyProvider);

    expect(await policy(hqHex), DmSendPolicyDecision.allowed);
  });

  test('a restricted user may not send to a non-approved recipient', () async {
    when(
      () => officials.isApprovedMinorDmRecipient(strangerHex),
    ).thenAnswer((_) async => false);
    final container = containerWith(isRestricted: true);
    final policy = container.read(dmSendPolicyProvider);

    expect(
      await policy(strangerHex),
      DmSendPolicyDecision.terminallyBlocked,
    );
  });

  test(
    'fail-closed: unresolved status with no persisted verdict denies a '
    'stranger (never unrestricted before a trusted not-protected answer)',
    () async {
      // The exact hole from review: while Keycast is loading / unknown /
      // token-missing AND the sticky store has never seen this account, the
      // policy must restrict — not fall through to unrestricted. Spec
      // "Fail-safe posture": only a positive not-protected signal lifts.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn('a' * 64);
      when(
        () => officials.isApprovedMinorDmRecipient(strangerHex),
      ).thenAnswer((_) async => false);
      when(
        () => officials.isApprovedMinorDmRecipient(hqHex),
      ).thenAnswer((_) async => true);

      final container = ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(authService),
          // Keycast never answers (outage / suppressed by the restricted
          // party). The policy must not wait on this to fail closed.
          protectedMinorStatusProvider.overrideWith(
            (ref) => Completer<ProtectedMinorStatus>().future,
          ),
          officialAccountsServiceProvider.overrideWithValue(officials),
        ],
      );
      addTearDown(container.dispose);
      final policy = container.read(dmSendPolicyProvider);

      expect(
        await policy(strangerHex),
        DmSendPolicyDecision.temporarilyBlocked,
        reason: 'unresolved + never-seen must restrict (fail closed)',
      );
      expect(
        await policy(hqHex),
        DmSendPolicyDecision.allowed,
        reason: 'a pinned approved official stays reachable while restricted',
      );
    },
  );

  test(
    'unresolved fail-closed denial is temporary, not a terminal policy block',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn('a' * 64);
      when(
        () => officials.isApprovedMinorDmRecipient(strangerHex),
      ).thenAnswer((_) async => false);

      final container = ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(authService),
          protectedMinorStatusProvider.overrideWith(
            (ref) => Completer<ProtectedMinorStatus>().future,
          ),
          officialAccountsServiceProvider.overrideWithValue(officials),
        ],
      );
      addTearDown(container.dispose);

      final decision = await container.read(dmSendPolicyProvider)(strangerHex);

      expect(
        decision,
        DmSendPolicyDecision.temporarilyBlocked,
      );
    },
  );
}
