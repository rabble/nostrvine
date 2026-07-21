import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crosspost_api_client.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockCrosspostApiClient extends Mock implements CrosspostApiClient {}

void main() {
  group('BlueskySettingsScreen', () {
    late _MockAuthService authService;
    late _MockCrosspostApiClient apiClient;
    late AppLocalizations l10n;

    const claimRouteMarker = 'NIP05 CLAIM ROUTE';
    const returnFromClaimFlow = 'Return from claim flow';

    setUp(() {
      authService = _MockAuthService();
      apiClient = _MockCrosspostApiClient();
      l10n = lookupAppLocalizations(const Locale('en'));
      when(() => authService.currentPublicKeyHex).thenReturn('pubkeyhex');
    });

    Widget buildApp() {
      final router = GoRouter(
        initialLocation: BlueskySettingsScreen.path,
        routes: [
          GoRoute(
            path: BlueskySettingsScreen.path,
            builder: (_, _) => const BlueskySettingsScreen(),
          ),
          GoRoute(
            path: Nip05SettingsScreen.path,
            builder: (context, _) => Scaffold(
              body: Column(
                children: [
                  const Text(claimRouteMarker),
                  TextButton(
                    onPressed: context.pop,
                    child: const Text(returnFromClaimFlow),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          crosspostApiClientProvider.overrideWithValue(apiClient),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.dark(),
          routerConfig: router,
        ),
      );
    }

    testWidgets('shows the claim notice when no username is claimed', (
      tester,
    ) async {
      when(
        () => apiClient.getStatus(),
      ).thenAnswer((_) async => const CrosspostStatus(crosspostEnabled: false));

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.blueskyUsernameRequired), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text(l10n.blueskyPublishVideos), findsOneWidget);
      expect(find.text(l10n.blueskyDisabledSubtitle), findsOneWidget);
    });

    testWidgets('hides the claim notice once a username is claimed', (
      tester,
    ) async {
      when(() => apiClient.getStatus()).thenAnswer(
        (_) async => const CrosspostStatus(
          crosspostEnabled: false,
          username: 'testuser',
          handle: 'testuser.divine.video',
          provisioningState: 'pending',
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.blueskyUsernameRequired), findsNothing);
      expect(find.text('testuser.divine.video'), findsOneWidget);
    });

    testWidgets('claim notice Set up button routes to the nip05 screen', (
      tester,
    ) async {
      when(
        () => apiClient.getStatus(),
      ).thenAnswer((_) async => const CrosspostStatus(crosspostEnabled: false));

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(TextButton, l10n.blueskySetUpHandle),
      );
      await tester.pumpAndSettle();

      expect(find.text(claimRouteMarker), findsOneWidget);
    });

    testWidgets(
      'enabling without a username surfaces a snackbar that routes to claim',
      (tester) async {
        when(() => apiClient.getStatus()).thenAnswer(
          (_) async => const CrosspostStatus(crosspostEnabled: false),
        );

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        verifyNever(
          () => apiClient.setCrosspost(
            pubkey: any(named: 'pubkey'),
            enabled: any(named: 'enabled'),
          ),
        );
        expect(find.byType(SnackBarAction), findsOneWidget);

        await tester.tap(find.text(l10n.blueskySetUpHandle).last);
        await tester.pumpAndSettle();

        expect(find.text(claimRouteMarker), findsOneWidget);
      },
    );

    testWidgets(
      'refreshes status and hides the claim notice after returning from claim',
      (tester) async {
        var getStatusCallCount = 0;
        when(() => apiClient.getStatus()).thenAnswer((_) async {
          getStatusCallCount += 1;
          if (getStatusCallCount == 1) {
            return const CrosspostStatus(crosspostEnabled: false);
          }
          return const CrosspostStatus(
            crosspostEnabled: false,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: 'pending',
          );
        });

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text(l10n.blueskyUsernameRequired), findsOneWidget);

        await tester.tap(
          find.widgetWithText(TextButton, l10n.blueskySetUpHandle),
        );
        await tester.pumpAndSettle();
        expect(find.text(claimRouteMarker), findsOneWidget);

        await tester.tap(find.text(returnFromClaimFlow));
        await tester.pumpAndSettle();

        verify(() => apiClient.getStatus()).called(2);
        expect(find.text(l10n.blueskyUsernameRequired), findsNothing);
        expect(find.text('testuser.divine.video'), findsOneWidget);
      },
    );

    testWidgets(
      'snackbar claim action refreshes status after returning from claim',
      (tester) async {
        var getStatusCallCount = 0;
        when(() => apiClient.getStatus()).thenAnswer((_) async {
          getStatusCallCount += 1;
          if (getStatusCallCount == 1) {
            return const CrosspostStatus(crosspostEnabled: false);
          }
          return const CrosspostStatus(
            crosspostEnabled: false,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: 'pending',
          );
        });

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.blueskySetUpHandle).last);
        await tester.pumpAndSettle();
        expect(find.text(claimRouteMarker), findsOneWidget);

        await tester.tap(find.text(returnFromClaimFlow));
        await tester.pumpAndSettle();

        verify(() => apiClient.getStatus()).called(2);
        expect(find.text(l10n.blueskyUsernameRequired), findsNothing);
        expect(find.text('testuser.divine.video'), findsOneWidget);
      },
    );
  });
}
