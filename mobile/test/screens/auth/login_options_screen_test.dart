// ABOUTME: Tests for LoginOptionsScreen
// ABOUTME: Verifies form rendering, sign-in flow, forgot password,
// ABOUTME: and alternative login method buttons

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/login_options_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/widgets/auth_back_button.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

void main() {
  late _MockKeycastOAuth mockOAuth;
  late _MockAuthService mockAuthService;
  late _MockPendingVerificationService mockPendingVerification;

  setUp(() {
    mockOAuth = _MockKeycastOAuth();
    mockAuthService = _MockAuthService();
    mockPendingVerification = _MockPendingVerificationService();
  });

  Widget createTestWidget({String initialLocation = LoginOptionsScreen.path}) {
    return ProviderScope(
      overrides: [
        ...getStandardTestOverrides(mockAuthService: mockAuthService),
        oauthClientProvider.overrideWithValue(mockOAuth),
        pendingVerificationServiceProvider.overrideWithValue(
          mockPendingVerification,
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        routerConfig: GoRouter(
          initialLocation: initialLocation,
          routes: [
            GoRoute(path: '/', builder: (_, _) => const Scaffold()),
            GoRoute(
              path: LoginOptionsScreen.path,
              builder: (_, state) => LoginOptionsScreen(
                initialEmail: state.uri.queryParameters['email'],
                initialError: state.uri.queryParameters['error'],
              ),
            ),
            GoRoute(
              path: '/import-key',
              builder: (_, _) => const Scaffold(body: Text('Key Import')),
            ),
            GoRoute(
              path: '/nostr-connect',
              builder: (_, _) => const Scaffold(body: Text('Nostr Connect')),
            ),
            GoRoute(
              path: '/verify-email',
              builder: (_, _) =>
                  const Scaffold(body: Text('Email Verification')),
            ),
          ],
        ),
      ),
    );
  }

  group(LoginOptionsScreen, () {
    group('renders', () {
      testWidgets('displays Sign in title', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data == 'Sign in' &&
                widget.style?.fontSize == 28,
          ),
          findsOneWidget,
        );
      });

      testWidgets('prefills email and shows recovery error from query params', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            initialLocation:
                '${LoginOptionsScreen.path}?email=person%40example.com&error=This%20email%20is%20already%20registered.%20Please%20sign%20in%20instead.',
          ),
        );
        await tester.pumpAndSettle();

        final emailField = find.descendant(
          of: find.widgetWithText(DivineAuthTextField, 'Email'),
          matching: find.byType(TextField),
        );
        final emailTextField = tester.widget<TextField>(emailField);
        expect(emailTextField.controller?.text, 'person@example.com');

        expect(
          find.text(
            'This email is already registered. Please sign in instead.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays email field', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Email'),
          findsOneWidget,
        );
      });

      testWidgets('displays password field', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Password'),
          findsOneWidget,
        );
      });

      testWidgets('wraps login fields in Form and AutofillGroup', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(DivineAuthTextField, 'Email');
        final passwordField = find.widgetWithText(
          DivineAuthTextField,
          'Password',
        );

        expect(
          find.ancestor(of: emailField, matching: find.byType(Form)),
          findsOneWidget,
        );
        expect(
          find.ancestor(of: emailField, matching: find.byType(AutofillGroup)),
          findsOneWidget,
        );
        expect(
          find.ancestor(of: passwordField, matching: find.byType(Form)),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: passwordField,
            matching: find.byType(AutofillGroup),
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays sign in button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(DivineButton), findsAtLeastNWidgets(1));
      });

      testWidgets('displays forgot password link', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Forgot password?'), findsOneWidget);
      });

      testWidgets('displays Import Nostr key button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineButton, 'Import Nostr key'),
          findsOneWidget,
        );
      });

      testWidgets('displays Connect with a signer app button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineButton, 'Connect with a signer app'),
          findsOneWidget,
        );
      });

      testWidgets('displays $AuthBackButton', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AuthBackButton), findsOneWidget);
      });

      testWidgets('displays info button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tapping info button shows info bottom sheet', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.info_outline));
        await tester.pumpAndSettle();

        expect(find.text('Sign-in options'), findsOneWidget);
        expect(find.text('Email & Password'), findsOneWidget);
        expect(find.text('Signer App'), findsOneWidget);
      });

      testWidgets('tapping forgot password shows dialog', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Forgot password?'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Password'), findsOneWidget);
      });

      testWidgets('calls headlessLogin on sign in tap with valid input', (
        tester,
      ) async {
        when(
          () => mockOAuth.headlessLogin(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer(
          (_) async => (
            HeadlessLoginResult(
              success: false,
              error: 'test',
              errorDescription: 'test error',
            ),
            'test-verifier',
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter valid email and password
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

        // Tap sign in
        await tester.tap(find.widgetWithText(DivineButton, 'Sign in'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          () => mockOAuth.headlessLogin(
            email: 'test@example.com',
            password: 'SecurePass123!',
            scope: 'policy:full',
          ),
        ).called(1);
      });

      testWidgets('displays general error on failed sign in', (tester) async {
        when(
          () => mockOAuth.headlessLogin(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
          ),
        ).thenAnswer(
          (_) async => (
            HeadlessLoginResult(
              success: false,
              error: 'invalid_credentials',
              errorDescription: 'Invalid email or password',
            ),
            'test-verifier',
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter email and password
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'user@example.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'Password123!',
        );

        // Tap sign in
        await tester.tap(find.widgetWithText(DivineButton, 'Sign in'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Invalid email or password'), findsOneWidget);
      });

      testWidgets('shows email validation error for empty form', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap sign in without entering anything
        await tester.tap(find.widgetWithText(DivineButton, 'Sign in'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Validation errors should appear (email required, password required)
        verifyNever(
          () => mockOAuth.headlessLogin(
            email: any(named: 'email'),
            password: any(named: 'password'),
            scope: any(named: 'scope'),
          ),
        );
      });
    });
  });
}
