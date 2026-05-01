// ABOUTME: Tests for PendingVerificationService — leak-prevention migration
// ABOUTME: Verifies pre-fix nsec-bearing verifiers are discarded on load

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/pending_verification_service.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group(PendingVerificationService, () {
    late _MockFlutterSecureStorage storage;
    late PendingVerificationService service;

    setUp(() {
      storage = _MockFlutterSecureStorage();
      service = PendingVerificationService(storage);

      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => storage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});
    });

    void stubReads({
      required String? deviceCode,
      required String? verifier,
      required String? email,
      required String? createdAt,
      required String? inviteCode,
    }) {
      when(
        () => storage.read(key: 'pending_verification_device_code'),
      ).thenAnswer((_) async => deviceCode);
      when(
        () => storage.read(key: 'pending_verification_verifier'),
      ).thenAnswer((_) async => verifier);
      when(
        () => storage.read(key: 'pending_verification_email'),
      ).thenAnswer((_) async => email);
      when(
        () => storage.read(key: 'pending_verification_created_at'),
      ).thenAnswer((_) async => createdAt);
      when(
        () => storage.read(key: 'pending_verification_invite_code'),
      ).thenAnswer((_) async => inviteCode);
    }

    group('load', () {
      test(
        'discards a persisted verifier that still carries an embedded nsec '
        '— Phase 1 leak-prevention guard',
        () async {
          // Pre-fix builds persisted verifiers of shape `<random>.<nsec1...>`.
          // Replaying them through OAuth code exchange would re-leak the
          // nsec to the server (divinevideo/divine-mobile#3359). The load
          // path must drop and clear them, returning null so the caller
          // forces a clean re-registration.
          stubReads(
            deviceCode: 'device-123',
            verifier: 'random_part.nsec1abc123secret',
            email: 'user@example.com',
            createdAt: DateTime.now().toIso8601String(),
            inviteCode: null,
          );

          final result = await service.load();

          expect(result, isNull);
          verify(
            () => storage.delete(key: 'pending_verification_device_code'),
          ).called(1);
          verify(
            () => storage.delete(key: 'pending_verification_verifier'),
          ).called(1);
          verify(
            () => storage.delete(key: 'pending_verification_email'),
          ).called(1);
        },
      );

      test('returns parsed value for a clean (random-only) verifier', () async {
        final now = DateTime.now().toIso8601String();
        stubReads(
          deviceCode: 'device-123',
          verifier: 'random_only_verifier_no_dot_no_nsec',
          email: 'user@example.com',
          createdAt: now,
          inviteCode: 'invite-abc',
        );

        final result = await service.load();

        expect(result, isNotNull);
        expect(result!.deviceCode, 'device-123');
        expect(result.verifier, 'random_only_verifier_no_dot_no_nsec');
        expect(result.email, 'user@example.com');
        expect(result.inviteCode, 'invite-abc');
      });

      test('returns null when no pending data is stored', () async {
        stubReads(
          deviceCode: null,
          verifier: null,
          email: null,
          createdAt: null,
          inviteCode: null,
        );

        final result = await service.load();
        expect(result, isNull);
      });
    });
  });
}
