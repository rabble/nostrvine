// ABOUTME: E2E test for session expired banner "Sign in" navigation flow
// ABOUTME: Verifies tapping "Sign in" on expired session banner reaches login
// ABOUTME: options screen instead of bouncing to home feed.
// ABOUTME: Requires: local Docker stack (mise run local_up)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  group('Session Expired Banner', () {
    final testEmail =
        'banner-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const testPassword = 'TestPass123!';

    patrolTest(
      'tapping Sign in navigates to login options instead of bouncing home',
      ($) async {
        final tester = $.tester;
        // ── Setup ──
        final originalOnError = suppressSetStateErrors();
        final originalErrorBuilder = saveErrorWidgetBuilder();

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final authService = container.read(authServiceProvider);

        // ════════════════════════════════════════════════════════════
        // Phase 1: Register + Verify (create OAuth session)
        // ════════════════════════════════════════════════════════════

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, testEmail, testPassword);

        final foundVerifyScreen = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(
          foundVerifyScreen,
          isTrue,
          reason: 'Should navigate to email verification screen',
        );

        final verifyToken = await getVerificationToken(testEmail);
        expect(verifyToken, isNotEmpty);

        final emailListener = container.read(
          emailVerificationListenerProvider,
        );
        await emailListener.handleUri(
          Uri.parse(
            'https://login.divine.video/verify-email?token=$verifyToken',
          ),
        );

        final leftVerifyScreen = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(leftVerifyScreen, isTrue);
        await pumpUntilSettled(tester);

        expect(authService.isAuthenticated, isTrue);
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.divineOAuth),
        );

        logPhase('Phase 1 complete: user registered and authenticated');

        // ════════════════════════════════════════════════════════════
        // Phase 1b: Plant local private keys for fallback
        // ════════════════════════════════════════════════════════════
        // OAuth-only users have no local private keys (only a
        // public-key container). When the OAuth session expires and
        // refresh fails, initialize() falls back to
        // _keyStorage.hasKeys() → getKeyContainer(). Without local
        // private keys, the user becomes fully unauthenticated.
        // Real users who started anonymous before upgrading to OAuth
        // already have local keys. We simulate this by generating
        // and storing keys after OAuth registration.

        final keyStorage = container.read(secureKeyStorageProvider);
        await keyStorage.generateAndStoreKeys();
        logPhase('Phase 1b: planted local private keys for fallback');

        // ════════════════════════════════════════════════════════════
        // Phase 2: Kill both tokens to trigger expired session state
        // ════════════════════════════════════════════════════════════

        // 2a. Expire the locally stored session
        final secureStorage = container.read(flutterSecureStorageProvider);
        final storedSession = await KeycastSession.load(secureStorage);
        expect(storedSession, isNotNull);
        final expiredSession = storedSession!.copyWith(
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        await expiredSession.save(secureStorage);

        // 2b. Consume all refresh tokens in DB so refresh fails
        final userPubkey = await getUserPubkeyByEmail(testEmail);
        expect(userPubkey, isNotNull);
        final consumedCount = await consumeAllRefreshTokens(userPubkey!);
        logPhase(
          'Phase 2: expired local session, consumed $consumedCount DB tokens',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 3: Reinitialize auth (simulates cold app restart)
        // ════════════════════════════════════════════════════════════

        await authService.initialize();
        await pumpUntilSettled(tester, maxSeconds: 10);

        expect(
          authService.hasExpiredOAuthSession,
          isTrue,
          reason: 'Should detect expired OAuth session after reinit',
        );
        expect(
          authService.isAuthenticated,
          isTrue,
          reason: 'Should still be authenticated via local key fallback',
        );

        logPhase(
          'Phase 3 complete: hasExpiredOAuthSession=${authService.hasExpiredOAuthSession}',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 4: Navigate to profile, find banner, tap "Sign in"
        // ════════════════════════════════════════════════════════════

        await tapBottomNavTab(tester, 'profile_tab');
        await pumpUntilSettled(tester);

        final foundBanner = await waitForText(tester, 'Session Expired');
        expect(
          foundBanner,
          isTrue,
          reason: 'Profile should show "Session Expired" banner',
        );

        // Tap the "Sign in" button on the banner
        final signInButton = find.widgetWithText(ElevatedButton, 'Sign in');
        expect(signInButton, findsOneWidget);
        await tester.tap(signInButton);
        await pumpUntilSettled(tester, maxSeconds: 10);

        logPhase('Phase 4: tapped Sign in on expired session banner');

        // ════════════════════════════════════════════════════════════
        // Phase 5: Assert user reaches login options (not bounced home)
        // ════════════════════════════════════════════════════════════

        // Login options screen shows "Forgot password?" and auth fields
        final foundLoginScreen = await waitForText(
          tester,
          'Forgot password?',
          maxSeconds: 10,
        );
        expect(
          foundLoginScreen,
          isTrue,
          reason: 'Should reach login options screen, not be bounced to home',
        );

        logPhase('Phase 5: reached login options screen successfully');

        // ════════════════════════════════════════════════════════════
        // Phase 6: Login with credentials, verify banner disappears
        // ════════════════════════════════════════════════════════════

        await loginWithCredentials(tester, testEmail, testPassword);
        await pumpUntilSettled(tester, maxSeconds: 15);

        expect(authService.isAuthenticated, isTrue);
        expect(
          authService.hasExpiredOAuthSession,
          isFalse,
          reason: 'Banner flag should clear after successful login',
        );

        logPhase('Phase 6: logged in, expired session banner cleared');

        drainAsyncErrors(tester);
        restoreErrorHandler(originalOnError);
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
