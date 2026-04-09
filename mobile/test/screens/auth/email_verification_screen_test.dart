// ABOUTME: Tests for EmailVerificationScreen
// ABOUTME: Verifies polling, success, and error state rendering

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockEmailVerificationCubit extends MockCubit<EmailVerificationState>
    implements EmailVerificationCubit {}

class _MockAuthService extends Mock implements AuthService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

class _MockInviteApiClient extends Mock implements InviteApiClient {}

void main() {
  late _MockEmailVerificationCubit mockCubit;
  late _MockAuthService mockAuthService;
  late _MockKeycastOAuth mockOAuth;
  late _MockPendingVerificationService mockPendingVerification;
  late _MockInviteApiClient mockInviteApiClient;
  late StreamController<AuthState> authStateController;

  setUp(() {
    mockCubit = _MockEmailVerificationCubit();
    mockAuthService = _MockAuthService();
    mockOAuth = _MockKeycastOAuth();
    mockPendingVerification = _MockPendingVerificationService();
    mockInviteApiClient = _MockInviteApiClient();
    authStateController = StreamController<AuthState>.broadcast();

    // Stub authService stream
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => authStateController.stream);
    when(() => mockAuthService.isAuthenticated).thenReturn(false);

    // Stub pending verification service
    when(() => mockPendingVerification.clear()).thenAnswer((_) async {});
    when(() => mockPendingVerification.load()).thenAnswer((_) async => null);
  });

  tearDown(() {
    authStateController.close();
  });

  Widget createTestWidget({
    String? deviceCode,
    String? verifier,
    String? email,
    String? token,
    EmailVerificationState initialState = const EmailVerificationState(),
  }) {
    // Set up cubit state
    when(() => mockCubit.state).thenReturn(initialState);
    whenListen(
      mockCubit,
      const Stream<EmailVerificationState>.empty(),
      initialState: initialState,
    );

    return ProviderScope(
      overrides: [
        ...getStandardTestOverrides(mockAuthService: mockAuthService),
        oauthClientProvider.overrideWithValue(mockOAuth),
        pendingVerificationServiceProvider.overrideWithValue(
          mockPendingVerification,
        ),
        forceExploreTabNameProvider.overrideWith((ref) => null),
      ],
      child: RepositoryProvider<InviteApiClient>.value(
        value: mockInviteApiClient,
        child: BlocProvider(
          create: (_) => InviteGateBloc(inviteApiClient: mockInviteApiClient),
          child: MaterialApp.router(
            theme: VineTheme.theme,
            routerConfig: GoRouter(
              initialLocation: '/verify-email',
              routes: [
                GoRoute(path: '/', builder: (_, _) => const Scaffold()),
                GoRoute(
                  path: '/verify-email',
                  builder: (_, _) => BlocProvider<EmailVerificationCubit>.value(
                    value: mockCubit,
                    child: EmailVerificationScreen(
                      deviceCode: deviceCode,
                      verifier: verifier,
                      email: email,
                      token: token,
                    ),
                  ),
                ),
                GoRoute(
                  path: '/login-options',
                  builder: (_, _) =>
                      const Scaffold(body: Text('Login Options')),
                ),
                GoRoute(
                  path: '/explore',
                  builder: (_, _) => const Scaffold(body: Text('Explore')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  group(EmailVerificationScreen, () {
    group('polling mode', () {
      testWidgets('renders polling content with email', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            email: 'user@example.com',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.polling,
              pendingEmail: 'user@example.com',
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Complete your registration'), findsOneWidget);
        expect(find.text('user@example.com'), findsOneWidget);
        expect(find.text('Waiting for verification'), findsOneWidget);
      });

      testWidgets('renders Open email app button', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            email: 'user@example.com',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.polling,
              pendingEmail: 'user@example.com',
            ),
          ),
        );
        await tester.pump();

        expect(
          find.widgetWithText(DivineButton, 'Open email app'),
          findsOneWidget,
        );
      });

      testWidgets('renders close button', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            email: 'user@example.com',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.polling,
              pendingEmail: 'user@example.com',
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('renders verification link instruction text', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            email: 'user@example.com',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.polling,
              pendingEmail: 'user@example.com',
            ),
          ),
        );
        await tester.pump();

        expect(find.text('We sent a verification link to:'), findsOneWidget);
      });
    });

    group('initial state', () {
      testWidgets('renders waiting content in initial state', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
          ),
        );
        await tester.pump();

        expect(find.text('Waiting for verification'), findsOneWidget);
      });
    });

    group('success state', () {
      testWidgets('renders success content', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            email: 'user@example.com',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.success,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Welcome to Divine!'), findsOneWidget);
        expect(find.text('Your email has been verified.'), findsOneWidget);
      });

      testWidgets('renders Signing you in status', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.success,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Signing you in'), findsOneWidget);
      });

      testWidgets('hides close button on success', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.success,
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.close), findsNothing);
      });
    });

    group('failure state', () {
      testWidgets('renders error content', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              error: 'Verification timed out',
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Uh oh.'), findsOneWidget);
      });

      testWidgets('renders Start over button', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              error: 'Error',
            ),
          ),
        );
        await tester.pump();

        expect(
          find.widgetWithText(DivineButton, 'Start over'),
          findsOneWidget,
        );
      });

      testWidgets('renders close button on failure', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              error: 'Error',
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('renders failure instruction text', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              error: 'Verification failed',
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Verification failed'), findsOneWidget);
      });

      testWidgets('renders invite recovery button when available', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              error: 'Invite problem',
              showInviteGateRecovery: true,
              inviteRecoveryCode: 'AB12-EF34',
            ),
          ),
        );
        await tester.pump();

        expect(
          find.widgetWithText(DivineButton, 'Back to invite code'),
          findsOneWidget,
        );
      });
    });

    group('interactions', () {
      testWidgets('calls stopPolling on dispose', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            deviceCode: 'test-device-code',
            verifier: 'test-verifier',
            initialState: const EmailVerificationState(
              status: EmailVerificationStatus.polling,
              pendingEmail: 'user@example.com',
            ),
          ),
        );
        await tester.pump();

        // Navigate away to dispose the screen
        final router = GoRouter.of(
          tester.element(find.byType(EmailVerificationScreen)),
        );
        router.go('/');
        await tester.pumpAndSettle();

        verify(() => mockCubit.stopPolling()).called(greaterThan(0));
      });

      testWidgets(
        're-verifies when token changes while already in token mode',
        (tester) async {
          final tokenNotifier = ValueNotifier<String>('token-1');
          const initialState = EmailVerificationState();

          when(() => mockCubit.state).thenReturn(initialState);
          whenListen(
            mockCubit,
            const Stream<EmailVerificationState>.empty(),
            initialState: initialState,
          );

          when(
            () => mockOAuth.verifyEmail(token: any(named: 'token')),
          ).thenAnswer(
            (_) async =>
                VerifyEmailResult(success: false, error: 'Invalid token'),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...getStandardTestOverrides(mockAuthService: mockAuthService),
                oauthClientProvider.overrideWithValue(mockOAuth),
                pendingVerificationServiceProvider.overrideWithValue(
                  mockPendingVerification,
                ),
                forceExploreTabNameProvider.overrideWith((ref) => null),
              ],
              child: MaterialApp(
                theme: VineTheme.theme,
                home: BlocProvider<EmailVerificationCubit>.value(
                  value: mockCubit,
                  child: ValueListenableBuilder<String>(
                    valueListenable: tokenNotifier,
                    builder: (context, token, _) =>
                        EmailVerificationScreen(token: token),
                  ),
                ),
              ),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 10));

          verify(() => mockOAuth.verifyEmail(token: 'token-1')).called(1);

          tokenNotifier.value = 'token-2';
          await tester.pump();

          verify(() => mockOAuth.verifyEmail(token: 'token-2')).called(1);
        },
      );
    });
  });
}
