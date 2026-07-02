// ABOUTME: Tests the trust gate for the protected-minor fail-safe — only an
// ABOUTME: authenticated, freshly-resolved status may lift protection (#175).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/protected_minor_providers.dart';

void main() {
  group('trustedProtectedMinorStatus', () {
    test(
      'unauthenticated notProtected is NOT trusted (never wipes sticky)',
      () {
        // The #174 seam returns notProtected() while auth is still restoring.
        // Treating it as a positive signal would wipe a confirmed minor. Reject.
        final result = trustedProtectedMinorStatus(
          authenticated: false,
          live: AsyncData(ProtectedMinorStatus.notProtected()),
        );
        expect(result, isNull);
      },
    );

    test('authenticated but still loading (stale value) is NOT trusted', () {
      // During an account switch, .value retains the previous account. Reject
      // anything that is not freshly resolved.
      final result = trustedProtectedMinorStatus(
        authenticated: true,
        live: const AsyncLoading<ProtectedMinorStatus>(),
      );
      expect(result, isNull);
    });

    test('authenticated + resolved notProtected is trusted (a real lift)', () {
      final result = trustedProtectedMinorStatus(
        authenticated: true,
        live: AsyncData(ProtectedMinorStatus.notProtected()),
      );
      expect(result?.kind, ProtectedMinorStatusKind.notProtected);
    });

    test('authenticated + resolved protected is trusted', () {
      final result = trustedProtectedMinorStatus(
        authenticated: true,
        live: AsyncData(ProtectedMinorStatus.protected()),
      );
      expect(result?.kind, ProtectedMinorStatusKind.protected);
    });

    test('authenticated error is NOT trusted (fail-safe: keep sticky)', () {
      final result = trustedProtectedMinorStatus(
        authenticated: true,
        live: AsyncError<ProtectedMinorStatus>(
          Exception('keycast down'),
          StackTrace.empty,
        ),
      );
      expect(result, isNull);
    });
  });
}
