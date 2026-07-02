// ABOUTME: Verifies the protected-minor lock on AgeVerificationService — the
// ABOUTME: single choke point that forces adult content off for #175.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'isAdultContentVerified is false for a protected minor even if stored true',
    () async {
      final service = AgeVerificationService(isProtectedMinor: () => true);
      await service.initialize();
      await service.setAdultContentVerified(true); // rejected below
      expect(service.isAdultContentVerified, false);
    },
  );

  test(
    'setAdultContentVerified(true) is rejected for a protected minor',
    () async {
      var protected = true;
      final service = AgeVerificationService(isProtectedMinor: () => protected);
      await service.initialize();
      await service.setAdultContentVerified(true);
      // Even after lifting the protection, nothing was persisted as true.
      protected = false;
      expect(service.isAdultContentVerified, false);
    },
  );

  test('non-protected account behaves normally', () async {
    final service = AgeVerificationService(isProtectedMinor: () => false);
    await service.initialize();
    await service.setAdultContentVerified(true);
    expect(service.isAdultContentVerified, true);
  });

  test('defaults to not-protected when no callback supplied', () async {
    final service = AgeVerificationService();
    await service.initialize();
    await service.setAdultContentVerified(true);
    expect(service.isAdultContentVerified, true);
  });
}
