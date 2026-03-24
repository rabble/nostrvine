import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/screens/auth/invite_gate_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/invite_api_service.dart';

class _MockInviteApiService extends Mock implements InviteApiService {}

class _MockHttpClient extends Mock implements http.Client {}

class _MockResponse extends Mock implements http.Response {}

void main() {
  late _MockInviteApiService mockInviteApiService;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockInviteApiService = _MockInviteApiService();
  });

  Widget createTestWidget({InviteApiService? inviteApiService}) {
    final service = inviteApiService ?? mockInviteApiService;

    return RepositoryProvider<InviteApiService>.value(
      value: service,
      child: BlocProvider(
        create: (_) => InviteGateBloc(inviteApiService: service),
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

    testWidgets(
      'preview bypass continues past invite gate when server requires invites',
      (tester) async {
        final mockClient = _MockHttpClient();
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(200);
        when(() => response.body).thenReturn(
          jsonEncode({
            'onboarding_mode': 'invite_code_required',
            'support_email': 'support@divine.video',
          }),
        );
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => response);

        final previewInviteApiService = InviteApiService(
          client: mockClient,
          forceOpenOnboarding: true,
        );

        await tester.pumpWidget(
          createTestWidget(inviteApiService: previewInviteApiService),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create Account'), findsOneWidget);
      },
    );

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
      await tester.tap(find.widgetWithText(DivineButton, 'Next'));
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
