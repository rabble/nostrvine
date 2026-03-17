import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/screens/auth/invite_gate_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/invite_api_service.dart';

class _MockInviteApiService extends Mock implements InviteApiService {}

void main() {
  late _MockInviteApiService mockInviteApiService;

  setUp(() {
    mockInviteApiService = _MockInviteApiService();
  });

  Widget createTestWidget() {
    return RepositoryProvider<InviteApiService>.value(
      value: mockInviteApiService,
      child: BlocProvider(
        create: (_) => InviteGateBloc(inviteApiService: mockInviteApiService),
        child: MaterialApp.router(
          theme: VineTheme.theme,
          routerConfig: GoRouter(
            initialLocation: WelcomeScreen.inviteGatePath,
            routes: [
              GoRoute(
                path: WelcomeScreen.path,
                builder: (context, state) =>
                    const Scaffold(body: Text('Welcome')),
                routes: [
                  GoRoute(
                    path: 'invite',
                    builder: (context, state) => InviteGateScreen(
                      initialCode: state.uri.queryParameters['code'],
                      initialError: state.uri.queryParameters['error'],
                    ),
                  ),
                  GoRoute(
                    path: 'create-account',
                    builder: (context, state) =>
                        const Scaffold(body: Text('Create Account')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  group('InviteGateScreen', () {
    testWidgets('maps legacy waitlist-only mode to invite entry flow', (
      tester,
    ) async {
      when(
        () => mockInviteApiService.getClientConfig(),
      ).thenAnswer(
        (_) async => InviteClientConfig(
          mode: parseOnboardingMode('waitlist_only'),
          supportEmail: 'support@divine.video',
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add your invite code'), findsOneWidget);
      expect(find.text('Join waitlist'), findsOneWidget);
    });

    testWidgets('valid code continues to create account', (tester) async {
      when(
        () => mockInviteApiService.getClientConfig(),
      ).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );
      when(
        () => mockInviteApiService.validateCode(any()),
      ).thenAnswer(
        (_) async => const InviteValidationResult(
          valid: true,
          used: false,
          code: 'AB12-EF34',
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add your invite code'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'ab12ef34',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      verify(() => mockInviteApiService.validateCode('AB12-EF34')).called(1);
    });

    testWidgets('shows initial recovery error from query params', (
      tester,
    ) async {
      when(
        () => mockInviteApiService.getClientConfig(),
      ).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );

      await tester.pumpWidget(
        RepositoryProvider<InviteApiService>.value(
          value: mockInviteApiService,
          child: BlocProvider(
            create: (_) =>
                InviteGateBloc(inviteApiService: mockInviteApiService),
            child: MaterialApp.router(
              theme: VineTheme.theme,
              routerConfig: GoRouter(
                initialLocation:
                    '${WelcomeScreen.inviteGatePath}?code=AB12-EF34'
                    '&error=Invite%20problem',
                routes: [
                  GoRoute(
                    path: WelcomeScreen.path,
                    builder: (context, state) =>
                        const Scaffold(body: Text('Welcome')),
                    routes: [
                      GoRoute(
                        path: 'invite',
                        builder: (context, state) => InviteGateScreen(
                          initialCode: state.uri.queryParameters['code'],
                          initialError: state.uri.queryParameters['error'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Invite problem'), findsOneWidget);
      expect(find.text('Add your invite code'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
