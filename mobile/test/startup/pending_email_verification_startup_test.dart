// ABOUTME: Startup-level regression tests for persisted email verification restore
// ABOUTME: Exercises matching automatic identity routing through the real GoRouter

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetNavigationState);

  group('restorePendingEmailVerificationOnStartup', () {
    test(
      'matching automatic identity restores owner-bound pending before first frame',
      () async {
        const publicKeyHex =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final authService = createMockAuthService();
        final pendingService = _MockPendingVerificationService();
        when(() => authService.authState).thenReturn(AuthState.authenticated);
        when(() => authService.isAuthenticated).thenReturn(true);
        when(() => authService.isAnonymous).thenReturn(true);
        when(() => authService.currentPublicKeyHex).thenReturn(publicKeyHex);
        when(() => authService.hasExpiredOAuthSession).thenReturn(false);
        when(pendingService.load).thenAnswer(
          (_) async => PendingVerification(
            deviceCode: 'device-code',
            verifier: 'verifier',
            email: 'user@example.com',
            createdAt: DateTime.now(),
            ownerPublicKeyHex: publicKeyHex,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(mockAuthService: authService),
            pendingVerificationServiceProvider.overrideWithValue(
              pendingService,
            ),
            currentMinorAccountReviewStatusProvider.overrideWith(
              (ref) async => MinorAccountReviewStatus.active(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await app.restorePendingEmailVerificationOnStartup(container);

        final uri = container
            .read(goRouterProvider)
            .routeInformationProvider
            .value
            .uri;
        expect(uri.path, '/verify-email');
        expect(uri.queryParameters, {
          'email': 'user@example.com',
          'restored': 'true',
        });
      },
    );
  });
}
