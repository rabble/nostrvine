// ABOUTME: Tests the protected-minor DM send policy (#176) — the app-level
// ABOUTME: composition (isProtectedMinor ∩ approved official) injected into
// ABOUTME: NIP17MessageService as a DmSendPolicy.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/services/official_accounts_service.dart';

class _MockOfficials extends Mock implements OfficialAccountsService {}

void main() {
  const hqHex =
      'c4a39f1291291d452405cd8ddd798c4a29a3858c52cd0d843f1f6852cf17682e';
  const strangerHex =
      'deadbeef00000000000000000000000000000000000000000000000000000000';

  late _MockOfficials officials;

  setUp(() {
    officials = _MockOfficials();
  });

  ProviderContainer containerWith({required bool isMinor}) => ProviderContainer(
    overrides: [
      isProtectedMinorProvider.overrideWithValue(isMinor),
      officialAccountsServiceProvider.overrideWithValue(officials),
    ],
  );

  test(
    'a non-protected user may send to anyone; officials not consulted',
    () async {
      final container = containerWith(isMinor: false);
      final policy = container.read(dmSendPolicyProvider);

      expect(await policy(strangerHex), isTrue);
      verifyNever(() => officials.isApprovedMinorDmRecipient(any()));
    },
  );

  test('a protected minor may send to an approved official', () async {
    when(
      () => officials.isApprovedMinorDmRecipient(hqHex),
    ).thenAnswer((_) async => true);
    final container = containerWith(isMinor: true);
    final policy = container.read(dmSendPolicyProvider);

    expect(await policy(hqHex), isTrue);
  });

  test('a protected minor may not send to a non-approved recipient', () async {
    when(
      () => officials.isApprovedMinorDmRecipient(strangerHex),
    ).thenAnswer((_) async => false);
    final container = containerWith(isMinor: true);
    final policy = container.read(dmSendPolicyProvider);

    expect(await policy(strangerHex), isFalse);
  });
}
