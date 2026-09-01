import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pubkeyA =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const pubkeyB =
      '2222222222222222222222222222222222222222222222222222222222222222';

  AgeVerificationService buildService({
    String? pubkey = pubkeyA,
    bool Function()? isProtectedMinor,
  }) => AgeVerificationService(
    currentPubkeyHex: () => pubkey,
    isProtectedMinor: isProtectedMinor,
  );

  group('AgeVerificationService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('age verification (creator gate)', () {
      test('starts unverified for a fresh account', () async {
        final service = buildService();
        await service.initialize();

        expect(service.isAgeVerified, isFalse);
        expect(service.verificationDate, isNull);
      });

      test('persists a true value for the active account', () async {
        final service = buildService();
        await service.initialize();

        await service.setAgeVerified(true);

        expect(service.isAgeVerified, isTrue);
        expect(service.verificationDate, isNotNull);
      });

      test('persists across instances for the same account', () async {
        final first = buildService();
        await first.initialize();
        await first.setAgeVerified(true);

        final second = buildService();
        await second.initialize();

        expect(second.isAgeVerified, isTrue);
      });

      test('is scoped per account', () async {
        final accountA = buildService();
        await accountA.initialize();
        await accountA.setAgeVerified(true);

        final accountB = buildService(pubkey: pubkeyB);
        await accountB.initialize();

        expect(accountB.isAgeVerified, isFalse);
      });
    });

    group('adult-content verification', () {
      test('starts unverified for a fresh account', () async {
        final service = buildService();
        await service.initialize();

        expect(service.isAdultContentVerified, isFalse);
      });

      test('persists a true value for the active account', () async {
        final service = buildService();
        await service.initialize();

        await service.setAdultContentVerified(true);

        expect(service.isAdultContentVerified, isTrue);
        expect(service.adultContentVerificationDate, isNotNull);
      });

      test('does not leak between accounts', () async {
        final accountA = buildService();
        await accountA.initialize();
        await accountA.setAdultContentVerified(true);

        final accountB = buildService(pubkey: pubkeyB);
        await accountB.initialize();

        expect(accountB.isAdultContentVerified, isFalse);
      });

      test(
        'a second account keeps its own state after switching back',
        () async {
          final accountA = buildService();
          await accountA.initialize();
          await accountA.setAdultContentVerified(true);

          final accountB = buildService(pubkey: pubkeyB);
          await accountB.initialize();
          expect(accountB.isAdultContentVerified, isFalse);

          final accountAAgain = buildService();
          await accountAAgain.initialize();
          expect(accountAAgain.isAdultContentVerified, isTrue);
        },
      );
    });

    group('no active account (fail-safe)', () {
      test('resolves to unverified when no account is signed in', () async {
        final service = buildService(pubkey: null);
        await service.initialize();

        expect(service.isAgeVerified, isFalse);
        expect(service.isAdultContentVerified, isFalse);
      });

      test('does not persist a write when no account is signed in', () async {
        final service = buildService(pubkey: null);
        await service.initialize();

        await service.setAdultContentVerified(true);

        expect(service.isAdultContentVerified, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getKeys().any((k) => k.startsWith('adult_content_verified')),
          isFalse,
        );
      });

      test('checkAdultContentVerification returns false', () async {
        final service = buildService(pubkey: null);

        expect(await service.checkAdultContentVerification(), isFalse);
      });
    });

    group('protected minor lock', () {
      test('overrides a per-account stored true', () async {
        // Seed a real per-account true, then read it as a protected minor.
        final adult = buildService();
        await adult.initialize();
        await adult.setAdultContentVerified(true);

        final minor = buildService(isProtectedMinor: () => true);
        await minor.initialize();

        expect(minor.isAdultContentVerified, isFalse);
      });

      test('rejects a verification write for a protected minor', () async {
        final minor = buildService(isProtectedMinor: () => true);
        await minor.initialize();

        await minor.setAdultContentVerified(true);

        final adult = buildService();
        await adult.initialize();
        expect(adult.isAdultContentVerified, isFalse);
      });
    });

    group('legacy global-key migration', () {
      test('adopts a legacy global value for the active account', () async {
        SharedPreferences.setMockInitialValues({
          'adult_content_verified': true,
          'adult_content_verification_date':
              DateTime.now().millisecondsSinceEpoch,
        });

        final service = buildService();
        await service.initialize();

        expect(service.isAdultContentVerified, isTrue);
      });

      test('deletes the legacy global keys after adoption', () async {
        SharedPreferences.setMockInitialValues({
          'adult_content_verified': true,
          'adult_content_verification_date':
              DateTime.now().millisecondsSinceEpoch,
        });

        final service = buildService();
        await service.initialize();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('adult_content_verified'), isFalse);
        expect(prefs.containsKey('adult_content_verification_date'), isFalse);
      });

      test('a second account never inherits a migrated legacy value', () async {
        SharedPreferences.setMockInitialValues({
          'adult_content_verified': true,
        });

        final accountA = buildService();
        await accountA.initialize();
        expect(accountA.isAdultContentVerified, isTrue);

        final accountB = buildService(pubkey: pubkeyB);
        await accountB.initialize();
        expect(accountB.isAdultContentVerified, isFalse);
      });

      test('retains the legacy global while no account is active', () async {
        SharedPreferences.setMockInitialValues({
          'adult_content_verified': true,
        });

        final service = buildService(pubkey: null);
        await service.initialize();

        // Not adopted (no account) and not deleted (waiting for one).
        expect(service.isAdultContentVerified, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('adult_content_verified'), isTrue);
      });
    });

    group('clearVerificationStatus', () {
      test('clears only the active account', () async {
        final accountA = buildService();
        await accountA.initialize();
        await accountA.setAdultContentVerified(true);

        final accountB = buildService(pubkey: pubkeyB);
        await accountB.initialize();
        await accountB.setAdultContentVerified(true);

        await accountA.clearVerificationStatus();

        expect(accountA.isAdultContentVerified, isFalse);

        final accountBReload = buildService(pubkey: pubkeyB);
        await accountBReload.initialize();
        expect(accountBReload.isAdultContentVerified, isTrue);
      });
    });

    group('purgeAccount', () {
      test('removes only the target account keys', () async {
        final accountA = buildService();
        await accountA.initialize();
        await accountA.setAdultContentVerified(true);

        final accountB = buildService(pubkey: pubkeyB);
        await accountB.initialize();
        await accountB.setAdultContentVerified(true);

        final prefs = await SharedPreferences.getInstance();
        await AgeVerificationService.purgeAccount(prefs, pubkeyA);

        final accountAReload = buildService();
        await accountAReload.initialize();
        expect(accountAReload.isAdultContentVerified, isFalse);

        final accountBReload = buildService(pubkey: pubkeyB);
        await accountBReload.initialize();
        expect(accountBReload.isAdultContentVerified, isTrue);
      });
    });

    group('adult media access revoke callback', () {
      test('fires when adult verification is revoked', () async {
        var clearCount = 0;
        final service = AgeVerificationService(
          currentPubkeyHex: () => pubkeyA,
          onAdultMediaAccessRevoked: () async => clearCount++,
        );
        await service.initialize();
        await service.setAdultContentVerified(true);

        await service.setAdultContentVerified(false);

        expect(clearCount, equals(1));
      });

      test('fires when verification status is cleared', () async {
        var clearCount = 0;
        final service = AgeVerificationService(
          currentPubkeyHex: () => pubkeyA,
          onAdultMediaAccessRevoked: () async => clearCount++,
        );
        await service.initialize();
        await service.setAdultContentVerified(true);

        await service.clearVerificationStatus();

        expect(clearCount, equals(1));
      });
    });
  });
}
