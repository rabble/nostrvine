import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_event.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/invite_protected_create_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/invite_api_service.dart';
import 'package:openvine/services/pending_verification_service.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockInviteApiService extends Mock implements InviteApiService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockHttpClient extends Mock implements http.Client {}

class _MockResponse extends Mock implements http.Response {}

void main() {
  late _MockInviteApiService mockInviteApiService;
  late _MockKeycastOAuth mockOAuth;
  late _MockPendingVerificationService mockPendingVerificationService;
  late _MockAuthService mockAuthService;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockInviteApiService = _MockInviteApiService();
    mockOAuth = _MockKeycastOAuth();
    mockPendingVerificationService = _MockPendingVerificationService();
    mockAuthService = _MockAuthService();

    when(() => mockAuthService.authState).thenReturn(AuthState.unauthenticated);
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
  });

  Widget createTestWidget({
    bool hasAccessGrant = false,
    InviteApiService? inviteApiService,
  }) {
    final container = ProviderContainer(
      overrides: [
        ...getStandardTestOverrides(mockAuthService: mockAuthService),
        oauthClientProvider.overrideWithValue(mockOAuth),
        pendingVerificationServiceProvider.overrideWithValue(
          mockPendingVerificationService,
        ),
      ],
    );
    final service = inviteApiService ?? mockInviteApiService;
    final inviteGateBloc = InviteGateBloc(
      inviteApiService: service,
    );

    if (hasAccessGrant) {
      inviteGateBloc.add(
        InviteGateAccessGranted(
          InviteAccessGrant(
            code: 'AB12-EF34',
            validatedAt: DateTime(2026, 3, 6),
          ),
        ),
      );
    }

    return UncontrolledProviderScope(
      container: container,
      child: RepositoryProvider<InviteApiService>.value(
        value: service,
        child: BlocProvider.value(
          value: inviteGateBloc,
          child: MaterialApp.router(
            theme: VineTheme.theme,
            routerConfig: GoRouter(
              initialLocation: WelcomeScreen.createAccountPath,
              routes: [
                GoRoute(
                  path: WelcomeScreen.path,
                  builder: (context, state) =>
                      const Scaffold(body: Text('Welcome')),
                  routes: [
                    GoRoute(
                      path: 'invite',
                      builder: (context, state) =>
                          const Scaffold(body: Text('Invite Gate')),
                    ),
                    GoRoute(
                      path: 'create-account',
                      builder: (context, state) =>
                          const InviteProtectedCreateAccountScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  group('InviteProtectedCreateAccountScreen', () {
    testWidgets('redirects to invite gate without access grant', (
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

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Invite Gate'), findsOneWidget);
    });

    testWidgets(
      'preview bypass allows direct create-account access without invite grant',
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

        expect(
          find.widgetWithText(DivineAuthTextField, 'Email'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows create-account flow when access grant exists', (
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

      await tester.pumpWidget(createTestWidget(hasAccessGrant: true));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(DivineAuthTextField, 'Email'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Create account'),
        findsOneWidget,
      );
    });
  });
}
