// ABOUTME: Tests for CreateAccountScreen
// ABOUTME: Verifies form rendering, submit interaction,
// ABOUTME: and skip button behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/create_account_screen.dart';
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

    when(
      () => mockAuthService.createAnonymousAccount(),
    ).thenAnswer((_) async {});
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        ...getStandardTestOverrides(mockAuthService: mockAuthService),
        oauthClientProvider.overrideWithValue(mockOAuth),
        pendingVerificationServiceProvider.overrideWithValue(
          mockPendingVerification,
        ),
      ],
      child: MaterialApp(
        theme: VineTheme.theme,
        home: const CreateAccountScreen(),
      ),
    );
  }

  group(CreateAccountScreen, () {
    group('renders', () {
      testWidgets('displays title', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data == 'Create account' &&
                widget.style?.fontSize == 32,
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays $AuthBackButton', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AuthBackButton), findsOneWidget);
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

      testWidgets('displays create account button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(ElevatedButton, 'Create account'),
          findsOneWidget,
        );
      });

      testWidgets('displays skip button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(TextButton, 'Use Divine with no backup'),
          findsOneWidget,
        );
      });

      testWidgets('displays dog sticker', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName.contains('samoyed_dog'),
          ),
          findsOneWidget,
        );
      });
    });

    group('interactions', () {
      testWidgets('tapping skip shows confirmation bottom sheet', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final skipButton = find.widgetWithText(
          TextButton,
          'Use Divine with no backup',
        );
        await tester.ensureVisible(skipButton);
        await tester.pumpAndSettle();
        await tester.tap(skipButton);
        await tester.pumpAndSettle();

        expect(find.text('One last thing...'), findsOneWidget);
        expect(
          find.widgetWithText(ElevatedButton, 'Add email & password'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextButton, 'Use this device only'),
          findsOneWidget,
        );
      });

      testWidgets('tapping Use this device only calls createAnonymousAccount', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final skipButton = find.widgetWithText(
          TextButton,
          'Use Divine with no backup',
        );
        await tester.ensureVisible(skipButton);
        await tester.pumpAndSettle();
        await tester.tap(skipButton);
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(TextButton, 'Use this device only'),
        );
        // Use pump() instead of pumpAndSettle() because the loading
        // spinner animates indefinitely after createAnonymousAccount is called.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(() => mockAuthService.createAnonymousAccount()).called(1);
      });

      testWidgets(
        'tapping Add email & password dismisses sheet without skipping',
        (tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          final skipButton = find.widgetWithText(
            TextButton,
            'Use Divine with no backup',
          );
          await tester.ensureVisible(skipButton);
          await tester.pumpAndSettle();
          await tester.tap(skipButton);
          await tester.pumpAndSettle();

          await tester.tap(
            find.widgetWithText(ElevatedButton, 'Add email & password'),
          );
          await tester.pumpAndSettle();

          expect(find.text('One last thing...'), findsNothing);
          verifyNever(() => mockAuthService.createAnonymousAccount());
        },
      );

      testWidgets('calls submit on create account tap', (tester) async {
        // Stub headlessRegister so submit proceeds
        when(
          () => mockOAuth.headlessRegister(
            email: any(named: 'email'),
            password: any(named: 'password'),
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

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter email
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'test@example.com',
        );

        // Enter password
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        // Tap create account
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify the cubit called headlessRegister (via submit)
        verify(
          () => mockOAuth.headlessRegister(
            email: 'test@example.com',
            password: 'SecurePass123!',
            scope: 'policy:full',
          ),
        ).called(1);
      });
    });
  });
}
