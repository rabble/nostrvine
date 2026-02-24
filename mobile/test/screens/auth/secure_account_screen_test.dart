// ABOUTME: Tests for SecureAccountScreen
// ABOUTME: Verifies registration form, validation, and email verification flow

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';
@GenerateMocks([KeycastOAuth, AuthService])
import 'secure_account_screen_test.mocks.dart';

void main() {
  group(SecureAccountScreen, () {
    late MockKeycastOAuth mockOAuth;
    late MockAuthService mockAuthService;

    setUp(() {
      mockOAuth = MockKeycastOAuth();
      mockAuthService = MockAuthService();

      // Default stubs
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.isAnonymous).thenReturn(true);
      when(mockAuthService.currentNpub).thenReturn('npub1test...');
      when(
        mockAuthService.exportNsec(),
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
          child: const MaterialApp(home: SecureAccountScreen()),
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

      testWidgets('displays Secure account button', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(ElevatedButton, 'Secure account'),
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

        // Tap submit
        await tester.tap(find.widgetWithText(ElevatedButton, 'Secure account'));
        await tester.pumpAndSettle();

        // Should show validation error
        expect(find.textContaining('valid email'), findsOneWidget);
      });
    });

    group('Password Visibility Toggle', () {
      testWidgets('toggles password visibility', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // DivineAuthTextField uses DivineIcon (SVG) for the toggle, not
        // Material Icons. Find it by type — there's exactly one.
        expect(find.byType(DivineIcon), findsOneWidget);

        // Password should be obscured initially
        final textField = tester.widget<TextField>(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
        );
        expect(textField.obscureText, isTrue);

        // Tap the visibility toggle (GestureDetector wrapping DivineIcon)
        await tester.tap(find.byType(DivineIcon));
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
          mockOAuth.headlessRegister(
            email: anyNamed('email'),
            password: anyNamed('password'),
            nsec: anyNamed('nsec'),
            scope: anyNamed('scope'),
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

        await tester.tap(find.widgetWithText(ElevatedButton, 'Secure account'));
        // Use pump() instead of pumpAndSettle() to avoid timer issues
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          mockOAuth.headlessRegister(
            email: 'test@example.com',
            password: 'SecurePass123!',
            nsec: anyNamed('nsec'),
            scope: 'policy:full',
          ),
        ).called(1);
      });

      testWidgets('shows error message on registration failure', (
        tester,
      ) async {
        when(
          mockOAuth.headlessRegister(
            email: anyNamed('email'),
            password: anyNamed('password'),
            nsec: anyNamed('nsec'),
            scope: anyNamed('scope'),
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

        await tester.tap(find.widgetWithText(ElevatedButton, 'Secure account'));
        await tester.pumpAndSettle();

        expect(find.text('Email already registered'), findsOneWidget);
      });

      testWidgets('shows error when nsec export fails', (tester) async {
        when(mockAuthService.exportNsec()).thenAnswer((_) async => null);

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

        await tester.tap(find.widgetWithText(ElevatedButton, 'Secure account'));
        await tester.pumpAndSettle();

        expect(
          find.text('Unable to access your keys. Please try again.'),
          findsOneWidget,
        );
      });
    });
  });
}
