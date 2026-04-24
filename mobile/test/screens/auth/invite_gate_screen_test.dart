import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:invite_api_client/invite_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/auth/invite_gate_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';

class _MockInviteApiClient extends Mock implements InviteApiClient {}

class _MockHttpClient extends Mock implements http.Client {}

class _MockResponse extends Mock implements http.Response {}

void main() {
  late _MockInviteApiClient mockInviteApiClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockInviteApiClient = _MockInviteApiClient();
  });

  Widget createTestWidget({InviteApiClient? inviteApiClient}) {
    final client = inviteApiClient ?? mockInviteApiClient;

    return RepositoryProvider<InviteApiClient>.value(
      value: client,
      child: BlocProvider(
        create: (_) => InviteGateBloc(inviteApiClient: client),
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
                      initialSourceSlug:
                          state.uri.queryParameters['sourceSlug'],
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
        () => mockInviteApiClient.getClientConfig(),
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

        final previewInviteApiClient = InviteApiClient(
          baseUrl: 'https://invite.example.com',
          client: mockClient,
          forceOpenOnboarding: true,
        );

        await tester.pumpWidget(
          createTestWidget(inviteApiClient: previewInviteApiClient),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create Account'), findsOneWidget);
      },
    );

    testWidgets('valid code continues to create account', (tester) async {
      when(
        () => mockInviteApiClient.getClientConfig(),
      ).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );
      when(
        () => mockInviteApiClient.validateCode(any()),
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
      verify(() => mockInviteApiClient.validateCode('AB12-EF34')).called(1);
    });

    testWidgets('shows initial recovery error from query params', (
      tester,
    ) async {
      when(
        () => mockInviteApiClient.getClientConfig(),
      ).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );

      await tester.pumpWidget(
        RepositoryProvider<InviteApiClient>.value(
          value: mockInviteApiClient,
          child: BlocProvider(
            create: (_) => InviteGateBloc(inviteApiClient: mockInviteApiClient),
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
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
                          initialSourceSlug:
                              state.uri.queryParameters['sourceSlug'],
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

    testWidgets('preserves creator source slug when joining waitlist', (
      tester,
    ) async {
      when(
        () => mockInviteApiClient.getClientConfig(),
      ).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        ),
      );
      when(
        () => mockInviteApiClient.joinWaitlist(
          contact: any(named: 'contact'),
          sourceSlug: any(named: 'sourceSlug'),
        ),
      ).thenAnswer(
        (_) async => const WaitlistJoinResult(
          id: 'waitlist-entry-1',
          message: 'Joined',
        ),
      );

      await tester.pumpWidget(
        RepositoryProvider<InviteApiClient>.value(
          value: mockInviteApiClient,
          child: BlocProvider(
            create: (_) => InviteGateBloc(inviteApiClient: mockInviteApiClient),
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              routerConfig: GoRouter(
                initialLocation:
                    '${WelcomeScreen.inviteGatePath}?code=LELE-PONS'
                    '&error=This%20creator%27s%20invites%20are%20full'
                    '&sourceSlug=lele-pons',
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
                          initialSourceSlug:
                              state.uri.queryParameters['sourceSlug'],
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

      await tester.tap(find.widgetWithText(DivineButton, 'Join waitlist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'fan@example.com');
      await tester.tap(find.widgetWithText(DivineButton, 'Join waitlist').last);
      await tester.pumpAndSettle();

      verify(
        () => mockInviteApiClient.joinWaitlist(
          contact: 'fan@example.com',
          sourceSlug: 'lele-pons',
        ),
      ).called(1);
    });
  });
}
