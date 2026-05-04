// ABOUTME: E2E coverage for Key Management private-key export affordances
// ABOUTME: Verifies RPC-only Keycast accounts do not show a local nsec copy action

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  group('Key Management Export', () {
    final testEmail =
        'key-management-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const testPassword = 'TestPass123!';

    patrolTest(
      'RPC-only Keycast account explains that no local nsec can be copied',
      ($) async {
        final tester = $.tester;
        final originalOnError = suppressSetStateErrors();
        final originalErrorBuilder = saveErrorWidgetBuilder();
        final semanticsHandle = tester.ensureSemantics();

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, testEmail, testPassword);

        final foundVerifyScreen = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(
          foundVerifyScreen,
          isTrue,
          reason: 'Registration should reach the email verification screen',
        );

        final verifyToken = await getVerificationToken(testEmail);
        expect(verifyToken, isNotEmpty);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
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
        await pumpUntilSettled(tester, maxSeconds: 10);

        final authService = container.read(authServiceProvider);
        expect(authService.isAuthenticated, isTrue);
        expect(
          authService.authenticationSource,
          AuthenticationSource.divineOAuth,
        );
        expect(
          authService.canExportLocalNsec,
          isFalse,
          reason:
              'Standard Keycast registration does not store an nsec locally',
        );

        GoRouter.of(tester.element(find.byType(MaterialApp))).go(
          KeyManagementScreen.path,
        );
        await pumpUntilSettled(tester, maxSeconds: 10);

        expect(find.text('Key Management'), findsOneWidget);
        expect(
          find.text('Copy My Private Key (nsec)', skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text(
            'This account signs with Keycast. No private key is stored on this device, so there is no nsec to copy here.',
            skipOffstage: false,
          ),
          findsOneWidget,
        );

        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        restoreErrorHandler(originalOnError);
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
