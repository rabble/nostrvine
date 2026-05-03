// ABOUTME: Tests for SecureAccountScreen
// ABOUTME: Verifies registration form, validation, and email verification flow

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/autofill_context_mock.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(SecureAccountScreen, () {
    late _MockKeycastOAuth mockOAuth;
    late _MockAuthService mockAuthService;

    setUp(() {
      mockOAuth = _MockKeycastOAuth();
      mockAuthService = _MockAuthService();

      // Default stubs
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.isAnonymous).thenReturn(true);
      when(() => mockAuthService.isRegistered).thenReturn(false);
      when(() => mockAuthService.currentNpub).thenReturn('npub1test...');
      when(
        () => mockAuthService.exportNsec(),
      ).thenAnswer((_) async => 'nsec1testabc123xyz');
    });

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
    });

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          oauthClientProvider.overrideWithValue(mockOAuth),
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
        child: BlocProvider<EmailVerificationCubit>(
          create: (_) => EmailVerificationCubit(
            oauthClient: mockOAuth,
            authService: mockAuthService,
          ),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SecureAccountScreen(),
          ),
        ),
      );
    }

    group('Form Display', () {
      testWidgets('displays email field', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays password field', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays confirm password field', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays Secure account button', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineButton, 'Secure account'),
          findsOneWidget,
        );
      });

      testWidgets('displays back button', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      });
    });

    group('Form Validation', () {
      testWidgets('shows error for invalid email', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Enter invalid email
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'invalid-email',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'password123',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'password123',
        );

        // Tap submit
        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        await tester.pumpAndSettle();

        // Should show validation error
        expect(find.textContaining('valid email'), findsOneWidget);
      });

      testWidgets('shows error for malformed email domain', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'person@gmail..com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid email'), findsOneWidget);
        verifyNever(() => mockAuthService.exportNsec());
      });

      testWidgets('shows error for password mismatch', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'test@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'DifferentPass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        await tester.pumpAndSettle();

        expect(find.text("Passwords don't match"), findsOneWidget);
        verifyNever(() => mockAuthService.exportNsec());
      });
    });

    group('Password Visibility Toggle', () {
      testWidgets('toggles password visibility', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // DivineAuthTextField uses DivineIcon (SVG) for password visibility
        // toggles. The password and confirmation fields each have one.
        expect(find.byType(DivineIcon), findsNWidgets(2));

        // Password should be obscured initially
        final textField = tester.widget<TextField>(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
        );
        expect(textField.obscureText, isTrue);

        // Tap the visibility toggle (GestureDetector wrapping DivineIcon)
        await tester.tap(find.byType(DivineIcon).first);
        await tester.pumpAndSettle();

        // Password should now be visible
        final textFieldAfter = tester.widget<TextField>(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
        );
        expect(textFieldAfter.obscureText, isFalse);
      });
    });

    group('Registration Flow', () {
      testWidgets('calls headlessRegister on valid form submission', (
        tester,
      ) async {
        // Use verificationRequired: false to avoid triggering polling
        when(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            nsec: any(named: 'nsec'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer(
          (_) async => (
            HeadlessRegisterResult(
              success: true,
              pubkey: 'test-pubkey',
              verificationRequired: false,
              email: 'test@example.com',
            ),
            'test-verifier',
          ),
        );

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'test@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        // Use pump() instead of pumpAndSettle() to avoid timer issues
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          () => mockOAuth.headlessRegister(
            email: 'test@example.com',
            password: 'SecurePass123!',
            nsec: any(named: 'nsec'),
            scope: 'policy:full',
          ),
        ).called(1);
      });

      testWidgets('shows error message on registration failure', (
        tester,
      ) async {
        when(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            nsec: any(named: 'nsec'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer(
          (_) async => (
            HeadlessRegisterResult.error('Email already registered'),
            'test-verifier',
          ),
        );

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'existing@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        await tester.pumpAndSettle();

        expect(find.text('Email already registered'), findsOneWidget);
      });

      testWidgets('shows error when nsec export fails', (tester) async {
        when(() => mockAuthService.exportNsec()).thenAnswer((_) async => null);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'test@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        await tester.pumpAndSettle();

        expect(
          find.text('Unable to access your keys. Please try again.'),
          findsOneWidget,
        );
      });
    });

    group('Autofill Context', () {
      testWidgets(
        'calls TextInput.finishAutofillContext when tapping Continue to App',
        (tester) async {
          final recorder = AutofillContextRecorder.install();

          // Return verification-required result so the dialog is shown.
          when(
            () => mockOAuth.headlessRegister(
              email: any(named: 'email'),
              password: any(named: 'password'),
              nsec: any(named: 'nsec'),
              scope: any(named: 'scope'),
            ),
          ).thenAnswer(
            (_) async => (
              HeadlessRegisterResult(
                success: true,
                pubkey: 'test-pubkey',
                verificationRequired: true,
                deviceCode: 'test-device-code',
                email: 'test@example.com',
              ),
              'test-verifier',
            ),
          );

          // Build with GoRouter so context.go() in _continueToApp() succeeds.
          // BlocProvider and ProviderScope must wrap MaterialApp.router so
          // that dialogs opened via showDialog (which uses the root overlay)
          // can find both the BLoC and Riverpod providers.
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const SecureAccountScreen(),
              ),
              GoRoute(path: '/explore', builder: (_, _) => const Scaffold()),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...getStandardTestOverrides(),
                oauthClientProvider.overrideWithValue(mockOAuth),
                authServiceProvider.overrideWithValue(mockAuthService),
              ],
              child: BlocProvider<EmailVerificationCubit>(
                create: (_) => EmailVerificationCubit(
                  oauthClient: mockOAuth,
                  authService: mockAuthService,
                ),
                child: MaterialApp.router(
                  theme: VineTheme.theme,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  routerConfig: router,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Enter valid credentials.
          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'Email'),
              matching: find.byType(TextField),
            ),
            'test@example.com',
          );
          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'Password'),
              matching: find.byType(TextField),
            ),
            'SecurePass123!',
          );
          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
              matching: find.byType(TextField),
            ),
            'SecurePass123!',
          );

          // Submit the form — triggers headlessRegister → dialog shown.
          await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
          // Pump through the async headlessRegister call and showDialog.
          // Use pump() + pump(duration) to drain microtask + timer queues
          // without relying on pumpAndSettle (which hangs on polling timers).
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          // Tap "Continue to App" in the verification dialog.
          await tester.tap(find.text('Continue to App'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(recorder.didFinishAutofillContext, isTrue);
        },
      );

      testWidgets('verification dialog is not dismissed by tapping outside', (
        tester,
      ) async {
        when(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            nsec: any(named: 'nsec'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer(
          (_) async => (
            HeadlessRegisterResult(
              success: true,
              pubkey: 'test-pubkey',
              verificationRequired: true,
              deviceCode: 'test-device-code',
              email: 'test@example.com',
            ),
            'test-verifier',
          ),
        );

        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const SecureAccountScreen()),
            GoRoute(path: '/explore', builder: (_, _) => const Scaffold()),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...getStandardTestOverrides(),
              oauthClientProvider.overrideWithValue(mockOAuth),
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: BlocProvider<EmailVerificationCubit>(
              create: (_) => EmailVerificationCubit(
                oauthClient: mockOAuth,
                authService: mockAuthService,
              ),
              child: MaterialApp.router(
                theme: VineTheme.theme,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'test@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Continue to App'), findsOneWidget);

        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Continue to App'), findsOneWidget);
      });

      testWidgets('verification dialog is not dismissed by system back', (
        tester,
      ) async {
        when(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
            nsec: any(named: 'nsec'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer(
          (_) async => (
            HeadlessRegisterResult(
              success: true,
              pubkey: 'test-pubkey',
              verificationRequired: true,
              deviceCode: 'test-device-code',
              email: 'test@example.com',
            ),
            'test-verifier',
          ),
        );

        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const SecureAccountScreen()),
            GoRoute(path: '/explore', builder: (_, _) => const Scaffold()),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...getStandardTestOverrides(),
              oauthClientProvider.overrideWithValue(mockOAuth),
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: BlocProvider<EmailVerificationCubit>(
              create: (_) => EmailVerificationCubit(
                oauthClient: mockOAuth,
                authService: mockAuthService,
              ),
              child: MaterialApp.router(
                theme: VineTheme.theme,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'test@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Confirm password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Secure account'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Continue to App'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Continue to App'), findsOneWidget);
      });
    });
  });
}
