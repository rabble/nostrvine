import 'package:divine_ui/divine_ui.dart';
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
import 'package:profile_repository/profile_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockCrosspostApiClient extends Mock implements CrosspostApiClient {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group('BlueskySettingsScreen', () {
    late _MockAuthService authService;
    late _MockCrosspostApiClient apiClient;
    late _MockProfileRepository profileRepository;
    late AppLocalizations l10n;

    const claimRouteMarker = 'NIP05 CLAIM ROUTE';
    const returnFromClaimFlow = 'Return from claim flow';
    const homePath = '/';
    const openSettings = 'Open Bluesky settings';
    late GoRouter router;

    setUp(() {
      authService = _MockAuthService();
      apiClient = _MockCrosspostApiClient();
      profileRepository = _MockProfileRepository();
      l10n = lookupAppLocalizations(const Locale('en'));
      when(() => authService.currentPublicKeyHex).thenReturn('pubkeyhex');
      when(
        () => profileRepository.lookupUsernameByPubkey(
          pubkeyHex: any(named: 'pubkeyHex'),
        ),
      ).thenAnswer(
        (_) async =>
            const DivineUsernameFound(name: 'testuser', canonical: 'testuser'),
      );
    });

    Widget buildApp({bool startAtHome = false}) {
      router = GoRouter(
        initialLocation: startAtHome ? homePath : BlueskySettingsScreen.path,
        routes: [
          GoRoute(
            path: homePath,
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push(BlueskySettingsScreen.path),
                child: const Text(openSettings),
              ),
            ),
          ),
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
          profileRepositoryProvider.overrideWithValue(profileRepository),
          profileReadRepositoryProvider.overrideWithValue(profileRepository),
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
        () => profileRepository.lookupUsernameByPubkey(
          pubkeyHex: any(named: 'pubkeyHex'),
        ),
      ).thenAnswer((_) async => const DivineUsernameNotFound());
      when(
        () => apiClient.getStatus(),
      ).thenAnswer((_) async => const CrosspostStatus(crosspostEnabled: false));

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.blueskyUsernameRequired), findsOneWidget);
      expect(find.byType(DivineSwitchTile), findsOneWidget);
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
        () => profileRepository.lookupUsernameByPubkey(
          pubkeyHex: any(named: 'pubkeyHex'),
        ),
      ).thenAnswer((_) async => const DivineUsernameNotFound());
      when(
        () => apiClient.getStatus(),
      ).thenAnswer((_) async => const CrosspostStatus(crosspostEnabled: false));

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(DivineButton, l10n.blueskySetUpHandle),
      );
      await tester.pumpAndSettle();

      expect(find.text(claimRouteMarker), findsOneWidget);
    });

    testWidgets(
      'enabling without a username surfaces a snackbar that routes to claim',
      (tester) async {
        when(
          () => profileRepository.lookupUsernameByPubkey(
            pubkeyHex: any(named: 'pubkeyHex'),
          ),
        ).thenAnswer((_) async => const DivineUsernameNotFound());
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
        expect(
          find.descendant(
            of: find.byType(DivineSnackbarContainer),
            matching: find.text(l10n.blueskySetUpHandle),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text(l10n.blueskySetUpHandle).last);
        await tester.pumpAndSettle();

        expect(find.text(claimRouteMarker), findsOneWidget);
      },
    );

    testWidgets(
      'refreshes status and hides the claim notice after returning from claim',
      (tester) async {
        var lookupCallCount = 0;
        when(
          () => profileRepository.lookupUsernameByPubkey(
            pubkeyHex: any(named: 'pubkeyHex'),
          ),
        ).thenAnswer((_) async {
          lookupCallCount += 1;
          if (lookupCallCount == 1) return const DivineUsernameNotFound();
          return const DivineUsernameFound(
            name: 'testuser',
            canonical: 'testuser',
          );
        });
        when(() => apiClient.getStatus()).thenAnswer((_) async {
          return const CrosspostStatus(
            crosspostEnabled: false,
            provisioningState: 'pending',
          );
        });

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text(l10n.blueskyUsernameRequired), findsOneWidget);

        await tester.tap(
          find.widgetWithText(DivineButton, l10n.blueskySetUpHandle),
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
        var lookupCallCount = 0;
        when(
          () => profileRepository.lookupUsernameByPubkey(
            pubkeyHex: any(named: 'pubkeyHex'),
          ),
        ).thenAnswer((_) async {
          lookupCallCount += 1;
          if (lookupCallCount == 1) return const DivineUsernameNotFound();
          return const DivineUsernameFound(
            name: 'testuser',
            canonical: 'testuser',
          );
        });
        when(() => apiClient.getStatus()).thenAnswer((_) async {
          return const CrosspostStatus(
            crosspostEnabled: false,
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

    testWidgets(
      'hides claim notice when name server confirms claim despite keycast null',
      (tester) async {
        when(() => apiClient.getStatus()).thenAnswer(
          (_) async => const CrosspostStatus(crosspostEnabled: false),
        );

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text(l10n.blueskyUsernameRequired), findsNothing);
        expect(find.text('testuser.divine.video'), findsOneWidget);
      },
    );

    testWidgets(
      'shows retry notice instead of claim notice when lookup fails',
      (tester) async {
        when(
          () => profileRepository.lookupUsernameByPubkey(
            pubkeyHex: any(named: 'pubkeyHex'),
          ),
        ).thenAnswer((_) async => const DivineUsernameUnknown());
        when(() => apiClient.getStatus()).thenAnswer(
          (_) async => const CrosspostStatus(crosspostEnabled: false),
        );

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text(l10n.blueskyUsernameRequired), findsNothing);
        expect(find.text(l10n.blueskyStatusUnavailableRetry), findsOneWidget);
        expect(
          find.widgetWithText(DivineButton, l10n.blueskySetUpHandle),
          findsNothing,
        );
      },
    );

    testWidgets(
      'snackbar claim action survives the settings route being popped',
      (tester) async {
        when(
          () => profileRepository.lookupUsernameByPubkey(
            pubkeyHex: any(named: 'pubkeyHex'),
          ),
        ).thenAnswer((_) async => const DivineUsernameNotFound());
        when(() => apiClient.getStatus()).thenAnswer(
          (_) async => const CrosspostStatus(crosspostEnabled: false),
        );

        await tester.pumpWidget(buildApp(startAtHome: true));
        await tester.pumpAndSettle();

        await tester.tap(find.text(openSettings));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(DivineSnackbarContainer),
            matching: find.text(l10n.blueskySetUpHandle),
          ),
          findsOneWidget,
        );

        // The root ScaffoldMessenger sits above the Navigator, so the snackbar
        // migrates to the previous route's Scaffold instead of going away.
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text(openSettings), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(DivineSnackbarContainer),
            matching: find.text(l10n.blueskySetUpHandle),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text(l10n.blueskySetUpHandle).last);
        await tester.pumpAndSettle();

        // The action is inert rather than throwing on the defunct context.
        expect(tester.takeException(), isNull);
        expect(find.text(claimRouteMarker), findsNothing);
      },
    );

    testWidgets('sync-pending snackbar does not route to claim', (
      tester,
    ) async {
      when(
        () => apiClient.getStatus(),
      ).thenAnswer((_) async => const CrosspostStatus(crosspostEnabled: false));
      when(
        () => apiClient.setCrosspost(pubkey: 'pubkeyhex', enabled: true),
      ).thenAnswer(
        (_) async => throw const CrosspostApiException(
          'not synced',
          statusCode: 400,
          kind: CrosspostApiErrorKind.usernameNotClaimed,
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text(l10n.blueskyUsernameSyncPending), findsOneWidget);
      expect(find.byType(SnackBarAction), findsNothing);
      expect(find.text(l10n.blueskySetUpHandle), findsNothing);
    });
  });
}
