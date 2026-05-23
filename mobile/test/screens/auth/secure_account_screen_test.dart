// ABOUTME: Tests for SecureAccountScreen — verifies the #3359 paused-upgrade
// ABOUTME: notice renders and that the screen never touches the nsec/OAuth path.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(SecureAccountScreen, () {
    late _MockKeycastOAuth mockOAuth;
    late _MockAuthService mockAuthService;

    setUpAll(() {
      SharedPreferences.setMockInitialValues({});
    });

    setUp(() {
      mockOAuth = _MockKeycastOAuth();
      mockAuthService = _MockAuthService();
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.isAnonymous).thenReturn(true);
    });

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          oauthClientProvider.overrideWithValue(mockOAuth),
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SecureAccountScreen(),
        ),
      );
    }

    testWidgets('renders the paused-upgrade notice', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.authSecureAccountTitle), findsOneWidget);
      expect(
        find.text(l10n.authSecureAccountUnavailableMessage),
        findsOneWidget,
      );
    });

    testWidgets('does not render a registration form', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // The form (and therefore the nsec export + OAuth register path) is gone.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets(
      'never exports the local nsec or calls OAuth registration — '
      'leak-prevention regression guard (#3359)',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        verifyNever(() => mockAuthService.exportNsec());
        verifyNever(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
          ),
        );
      },
    );
  });
}
