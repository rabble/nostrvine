// ABOUTME: Unit tests for pendingEmailVerificationRestoreLocation
// ABOUTME: Pure PendingVerification -> verify-email restore URL mapping

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';

PendingVerification _pending({
  String deviceCode = 'device-123',
  String verifier = 'verifier-abc',
  String email = 'user@example.com',
  DateTime? createdAt,
  String? ownerPublicKeyHex,
}) {
  return PendingVerification(
    deviceCode: deviceCode,
    verifier: verifier,
    email: email,
    createdAt: createdAt ?? DateTime.now(),
    ownerPublicKeyHex: ownerPublicKeyHex,
  );
}

void main() {
  group('pendingEmailVerificationRestoreLocation', () {
    test('returns null when there is no pending record', () {
      expect(pendingEmailVerificationRestoreLocation(null), isNull);
    });

    test('returns null when the pending record has expired', () {
      final expired = _pending(
        createdAt: DateTime.now().subtract(const Duration(hours: 25)),
      );
      expect(pendingEmailVerificationRestoreLocation(expired), isNull);
    });

    test('builds a restore URL with only email + restored flag', () {
      final location = pendingEmailVerificationRestoreLocation(_pending());
      expect(location, isNotNull);

      final uri = Uri.parse(location!);
      expect(uri.path, equals('/verify-email'));
      expect(uri.queryParameters['email'], equals('user@example.com'));
      expect(uri.queryParameters['restored'], equals('true'));
    });

    test('does not put the deviceCode or verifier secrets in the URL', () {
      final location = pendingEmailVerificationRestoreLocation(_pending());
      // deviceCode/verifier are secrets and are rehydrated from the persisted
      // record on the restore path, never carried on a URL that could be
      // logged or leaked.
      expect(location, isNot(contains('device-123')));
      expect(location, isNot(contains('verifier-abc')));
      final uri = Uri.parse(location!);
      expect(uri.queryParameters.containsKey('deviceCode'), isFalse);
      expect(uri.queryParameters.containsKey('verifier'), isFalse);
    });

    test('percent-encodes the email so the URL round-trips', () {
      final location = pendingEmailVerificationRestoreLocation(
        _pending(email: 'a+b@example.com'),
      );
      final uri = Uri.parse(location!);
      expect(uri.queryParameters['email'], equals('a+b@example.com'));
    });
  });

  group('pendingEmailVerificationStartupLocation', () {
    const ownerPublicKeyHex =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const differentPublicKeyHex =
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

    String? startupLocation({
      PendingVerification? pending,
      AuthState authState = AuthState.unauthenticated,
      bool isAnonymous = false,
      String? currentPublicKeyHex,
      String currentPath = '/welcome',
    }) => pendingEmailVerificationStartupLocation(
      pending: pending,
      authState: authState,
      isAnonymous: isAnonymous,
      currentPublicKeyHex: currentPublicKeyHex,
      currentPath: currentPath,
    );

    test('allows an ownerless record while unauthenticated', () {
      expect(startupLocation(pending: _pending()), isNotNull);
    });

    test(
      'allows an owner-bound record for its matching automatic identity',
      () {
        expect(
          startupLocation(
            pending: _pending(ownerPublicKeyHex: ownerPublicKeyHex),
            authState: AuthState.authenticated,
            isAnonymous: true,
            currentPublicKeyHex: ownerPublicKeyHex,
          ),
          isNotNull,
        );
      },
    );

    test('denies an owner-bound record for a different automatic identity', () {
      expect(
        startupLocation(
          pending: _pending(ownerPublicKeyHex: ownerPublicKeyHex),
          authState: AuthState.authenticated,
          isAnonymous: true,
          currentPublicKeyHex: differentPublicKeyHex,
        ),
        isNull,
      );
    });

    test(
      'denies an ownerless record while an automatic identity is active',
      () {
        expect(
          startupLocation(
            pending: _pending(),
            authState: AuthState.authenticated,
            isAnonymous: true,
            currentPublicKeyHex: ownerPublicKeyHex,
          ),
          isNull,
        );
      },
    );

    test('denies an owner-bound record while unauthenticated', () {
      expect(
        startupLocation(
          pending: _pending(ownerPublicKeyHex: ownerPublicKeyHex),
        ),
        isNull,
      );
    });

    for (final source in [
      'registered Divine OAuth',
      'imported keys',
      'bunker',
      'Amber',
      'NIP-07',
    ]) {
      test('denies an owner-bound record for $source', () {
        expect(
          startupLocation(
            pending: _pending(ownerPublicKeyHex: ownerPublicKeyHex),
            authState: AuthState.authenticated,
            currentPublicKeyHex: ownerPublicKeyHex,
          ),
          isNull,
        );
      });
    }

    test('denies an absent record', () {
      expect(startupLocation(), isNull);
    });

    test('denies an expired record', () {
      expect(
        startupLocation(
          pending: _pending(
            createdAt: DateTime.now().subtract(const Duration(hours: 25)),
          ),
        ),
        isNull,
      );
    });

    test('does not override an existing verify-email route', () {
      expect(
        startupLocation(
          pending: _pending(),
          currentPath: '/verify-email',
        ),
        isNull,
      );
    });

    test('does not override a non-Welcome route', () {
      expect(
        startupLocation(pending: _pending(), currentPath: '/explore'),
        isNull,
      );
    });
  });
}
