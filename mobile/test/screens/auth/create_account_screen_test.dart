// ABOUTME: Tests for CreateAccountScreen
// ABOUTME: Verifies form rendering, submit interaction,
// ABOUTME: and skip button behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/create_account_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/widgets/auth_back_button.dart';

import '../../helpers/autofill_context_mock.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

class _MockInviteApiClient extends Mock implements InviteApiClient {}

class _FakeSecureKeyContainer extends Fake implements SecureKeyContainer {}

void main() {
  late _MockKeycastOAuth mockOAuth;
  late _MockAuthService mockAuthService;
  late _MockPendingVerificationService mockPendingVerification;
  late _MockInviteApiClient mockInviteApiClient;

  setUpAll(() {
    registerFallbackValue(_FakeSecureKeyContainer());
  });

  setUp(() {
    mockOAuth = _MockKeycastOAuth();
    mockAuthService = _MockAuthService();
    mockPendingVerification = _MockPendingVerificationService();
    mockInviteApiClient = _MockInviteApiClient();

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
      child: RepositoryProvider<InviteApiClient>.value(
        value: mockInviteApiClient,
        child: BlocProvider(
          create: (_) => InviteGateBloc(inviteApiClient: mockInviteApiClient),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const CreateAccountScreen(),
          ),
        ),
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
          find.widgetWithText(DivineButton, 'Create account'),
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

        expect(find.byType(SvgPicture), findsAtLeast(1));
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
          find.widgetWithText(DivineButton, 'Add email & password'),
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
            find.widgetWithText(DivineButton, 'Add email & password'),
          );
          await tester.pumpAndSettle();

          expect(find.text('One last thing...'), findsNothing);
          verifyNever(() => mockAuthService.createAnonymousAccount());
        },
      );

      testWidgets(
        'calls TextInput.finishAutofillContext on $DivineAuthEmailVerification',
        (tester) async {
          final recorder = AutofillContextRecorder.install();

          // Return verification-required result so the cubit emits
          // DivineAuthEmailVerification.
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
                verificationRequired: true,
                deviceCode: 'test-device-code',
                email: 'test@example.com',
              ),
              'test-verifier',
            ),
          );

          when(
            () => mockPendingVerification.save(
              deviceCode: any(named: 'deviceCode'),
              verifier: any(named: 'verifier'),
              email: any(named: 'email'),
              inviteCode: any(named: 'inviteCode'),
            ),
          ).thenAnswer((_) async {});

          // Build with a GoRouter so context.go() in the listener succeeds.
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => ProviderScope(
                  overrides: [
                    ...getStandardTestOverrides(
                      mockAuthService: mockAuthService,
                    ),
                    oauthClientProvider.overrideWithValue(mockOAuth),
                    pendingVerificationServiceProvider.overrideWithValue(
                      mockPendingVerification,
                    ),
                  ],
                  child: RepositoryProvider<InviteApiClient>.value(
                    value: mockInviteApiClient,
                    child: BlocProvider(
                      create: (_) => InviteGateBloc(
                        inviteApiClient: mockInviteApiClient,
                      ),
                      child: const CreateAccountScreen(),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/verify-email',
                builder: (_, _) => const Scaffold(),
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp.router(
              theme: VineTheme.theme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
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

          await tester.tap(
            find.widgetWithText(DivineButton, 'Create account'),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(recorder.didFinishAutofillContext, isTrue);
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
        await tester.tap(find.widgetWithText(DivineButton, 'Create account'));
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
