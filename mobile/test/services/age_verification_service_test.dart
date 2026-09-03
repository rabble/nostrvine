import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pubkeyA =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const pubkeyB =
      '2222222222222222222222222222222222222222222222222222222222222222';
  late SharedPreferences preferences;

  AgeVerificationService buildService({
    String? pubkey = pubkeyA,
    bool Function()? isProtectedMinor,
  }) => AgeVerificationService(
    preferences: preferences,
    currentPubkeyHex: () => pubkey,
    isProtectedMinor: isProtectedMinor,
  );

  group('AgeVerificationService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
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

      test(
        'reads the active account after auth resolves without reinitializing',
        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('adult_content_verified_$pubkeyA', true);
          String? activePubkey;
          final service = AgeVerificationService(
            preferences: preferences,
            currentPubkeyHex: () => activePubkey,
          );

          await service.initialized;
          expect(service.isAdultContentVerified, isFalse);

          activePubkey = pubkeyA;

          expect(service.isAdultContentVerified, isTrue);
        },
      );

      test('aborts a write if the active account changes', () async {
        var activePubkey = pubkeyA;
        final service = AgeVerificationService(
          preferences: preferences,
          currentPubkeyHex: () => activePubkey,
        );
        await service.initialize();

        final write = service.setAdultContentVerified(true);
        activePubkey = pubkeyB;
        await write;

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('adult_content_verified_$pubkeyA'), isFalse);
        expect(service.isAdultContentVerified, isFalse);
      });
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
      test('deletes legacy global values without granting them', () async {
        SharedPreferences.setMockInitialValues({
          'adult_content_verified': true,
          'adult_content_verification_date':
              DateTime.now().millisecondsSinceEpoch,
        });

        final service = buildService();
        await service.initialize();

        expect(service.isAdultContentVerified, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('adult_content_verified'), isFalse);
        expect(prefs.containsKey('adult_content_verification_date'), isFalse);
        expect(prefs.containsKey('adult_content_verified_$pubkeyA'), isFalse);
      });
    });

    group('adult media access revoke callback', () {
      test('fires when adult verification is revoked', () async {
        var clearCount = 0;
        final service = AgeVerificationService(
          preferences: preferences,
          currentPubkeyHex: () => pubkeyA,
          onAdultMediaAccessRevoked: () async => clearCount++,
        );
        await service.initialize();
        await service.setAdultContentVerified(true);

        await service.setAdultContentVerified(false);

        expect(clearCount, equals(1));
      });
    });
  });
}
