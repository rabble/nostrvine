// ABOUTME: Tests for PendingVerificationService persistence and the #3359
// ABOUTME: migration guard that purges legacy nsec-bearing PKCE verifiers.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/pending_verification_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  group(PendingVerificationService, () {
    late MockSecureStorage storage;
    late PendingVerificationService service;

    setUp(() {
      storage = MockSecureStorage();
      service = PendingVerificationService(storage);
    });

    group('load', () {
      test('returns null when nothing is stored', () async {
        expect(await service.load(), isNull);
      });

      test('returns a clean random-only verifier unchanged', () async {
        const cleanVerifier = 'abc123randomVerifierWithNoEmbeddedMaterial456';
        await service.save(
          deviceCode: 'device_code_clean',
          verifier: cleanVerifier,
          email: 'user@example.com',
        );

        final result = await service.load();

        expect(result, isNotNull);
        expect(result!.verifier, cleanVerifier);
        expect(result.deviceCode, 'device_code_clean');
        expect(result.email, 'user@example.com');
      });
    });

    group('load migration guard (#3359)', () {
      test(
        'discards a legacy <random>.<nsec1...> verifier and clears storage',
        () async {
          const leakedVerifier =
              'abc123randomPart.nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9'
              'k0t9af8935ke9laqsnlfe5';
          await service.save(
            deviceCode: 'device_code_leaked',
            verifier: leakedVerifier,
            email: 'user@example.com',
          );

          final result = await service.load();

          // The tainted verifier must never be returned, and storage must be
          // cleared so it can't be replayed to the token endpoint on restart.
          expect(result, isNull);
          expect(await service.hasPending(), isFalse);
        },
      );

      test(
        'discards a bare nsec1 verifier with no leading dot (defense in depth)',
        () async {
          await service.save(
            deviceCode: 'device_code_bare',
            verifier:
                'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsn',
            email: 'user@example.com',
          );

          final result = await service.load();

          expect(result, isNull);
          expect(await service.hasPending(), isFalse);
        },
      );
    });
  });
}
