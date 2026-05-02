// ABOUTME: Widget tests for RelaySettingsScreen layout.
// ABOUTME: Verifies the Nostr relay menu aligns with other settings screens.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrService extends Mock implements NostrClient {}

class _MockRelayCapabilityService extends Mock
    implements RelayCapabilityService {}

class _MockRelayStatisticsService extends Mock
    implements RelayStatisticsService {}

void main() {
  testWidgets(
    'RelaySettingsScreen constrains menu content width on wide screens',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});

      final nostrService = _MockNostrService();
      final capabilityService = _MockRelayCapabilityService();
      final statsService = _MockRelayStatisticsService();
      final stats = RelayStatistics(relayUrl: 'wss://relay.divine.video')
        ..isConnected = true;

      when(
        () => nostrService.configuredRelays,
      ).thenReturn(['wss://relay.divine.video']);
      when(() => nostrService.connectedRelayCount).thenReturn(1);
      when(() => statsService.getStatistics(any())).thenReturn(stats);
      when(
        statsService.getAllStatistics,
      ).thenReturn({'wss://relay.divine.video': stats});
      when(() => capabilityService.getRelayCapabilities(any())).thenThrow(
        RelayCapabilityException('Not found', 'wss://relay.divine.video'),
      );

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(nostrService),
          relayCapabilityServiceProvider.overrideWithValue(capabilityService),
          relayStatisticsServiceProvider.overrideWithValue(statsService),
          relayStatisticsStreamProvider.overrideWith(
            (_) => Stream.value({'wss://relay.divine.video': stats}),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const RelaySettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listViewWidth = tester.getSize(find.byType(ListView).first).width;
      expect(listViewWidth, moreOrLessEquals(600));
    },
  );

  group('Add Relay validation (#3362)', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required _MockNostrService nostrService,
    }) async {
      SharedPreferences.setMockInitialValues({});

      final capabilityService = _MockRelayCapabilityService();
      final statsService = _MockRelayStatisticsService();

      when(() => nostrService.configuredRelays).thenReturn(const []);
      when(() => nostrService.connectedRelayCount).thenReturn(0);
      when(statsService.getAllStatistics).thenReturn(const {});
      when(
        () => capabilityService.getRelayCapabilities(any()),
      ).thenThrow(RelayCapabilityException('Not found', 'wss://x'));

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(nostrService),
          relayCapabilityServiceProvider.overrideWithValue(capabilityService),
          relayStatisticsServiceProvider.overrideWithValue(statsService),
          relayStatisticsStreamProvider.overrideWith(
            (_) => const Stream<Map<String, RelayStatistics>>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // The screen uses go_router's `dialogContext.pop()` to close its
      // Add Relay dialog, so the test must host it inside a GoRouter.
      final router = GoRouter(
        initialLocation: RelaySettingsScreen.path,
        routes: [
          GoRoute(
            path: RelaySettingsScreen.path,
            name: RelaySettingsScreen.routeName,
            builder: (_, _) => const RelaySettingsScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openAddDialogAndSubmit(
      WidgetTester tester,
      String url,
      AppLocalizations l10n,
    ) async {
      // The empty-relay state surfaces an "Add custom relay" button; it
      // opens the same dialog that the populated state's "Add relay" button
      // does. Tap whichever is showing.
      await tester.tap(find.text(l10n.relaySettingsAddCustomRelay));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), url);
      await tester.pumpAndSettle();

      // Dialog's confirm button uses relaySettingsAdd ("Add").
      await tester.tap(find.text(l10n.relaySettingsAdd));
      await tester.pumpAndSettle();
    }

    testWidgets('rejects ws:// non-loopback URL with insecure-url snackbar', (
      tester,
    ) async {
      final nostrService = _MockNostrService();
      await pumpScreen(tester, nostrService: nostrService);

      final l10n = lookupAppLocalizations(const Locale('en'));
      await openAddDialogAndSubmit(tester, 'ws://attacker.example.com', l10n);

      expect(find.text(l10n.relaySettingsInsecureUrl), findsOneWidget);
      verifyNever(() => nostrService.addRelay(any()));
    });

    testWidgets('accepts wss:// URL and forwards to NostrClient', (
      tester,
    ) async {
      final nostrService = _MockNostrService();
      when(() => nostrService.addRelay(any())).thenAnswer((_) async => true);

      await pumpScreen(tester, nostrService: nostrService);

      final l10n = lookupAppLocalizations(const Locale('en'));
      await openAddDialogAndSubmit(tester, 'wss://relay.example.com', l10n);

      verify(() => nostrService.addRelay('wss://relay.example.com')).called(1);
    });

    testWidgets('accepts uppercase WSS:// URL and forwards to NostrClient', (
      tester,
    ) async {
      final nostrService = _MockNostrService();
      when(() => nostrService.addRelay(any())).thenAnswer((_) async => true);

      await pumpScreen(tester, nostrService: nostrService);

      final l10n = lookupAppLocalizations(const Locale('en'));
      await openAddDialogAndSubmit(tester, 'WSS://relay.example.com', l10n);

      verify(() => nostrService.addRelay('WSS://relay.example.com')).called(1);
    });

    testWidgets('shows malformed-URL message for empty-host wss://', (
      tester,
    ) async {
      // Self-review fix: a bare scheme like `wss://` previously surfaced
      // the security-relevant insecure-URL message, which told the user
      // to do exactly what they typed. After the fix it falls through to
      // the malformed-URL message.
      final nostrService = _MockNostrService();
      await pumpScreen(tester, nostrService: nostrService);

      final l10n = lookupAppLocalizations(const Locale('en'));
      await openAddDialogAndSubmit(tester, 'wss://', l10n);

      expect(find.text(l10n.relaySettingsInvalidUrl), findsOneWidget);
      expect(find.text(l10n.relaySettingsInsecureUrl), findsNothing);
      verifyNever(() => nostrService.addRelay(any()));
    });

    testWidgets(
      'shows malformed-URL message for https:// input (relays are WS-only)',
      (tester) async {
        // Reviewer ask on PR #3806: form previously accepted https:// /
        // http://, but `RelayManager._normalizeUrl` only accepts wss:// /
        // loopback ws://, so they fell through to a generic "failed to add"
        // message. Surface the structurally-bad-input bucket instead.
        final nostrService = _MockNostrService();
        await pumpScreen(tester, nostrService: nostrService);

        final l10n = lookupAppLocalizations(const Locale('en'));
        await openAddDialogAndSubmit(tester, 'https://relay.example.com', l10n);

        expect(find.text(l10n.relaySettingsInvalidUrl), findsOneWidget);
        expect(find.text(l10n.relaySettingsInsecureUrl), findsNothing);
        verifyNever(() => nostrService.addRelay(any()));
      },
    );

    testWidgets(
      'shows malformed-URL message for http:// input (relays are WS-only)',
      (tester) async {
        final nostrService = _MockNostrService();
        await pumpScreen(tester, nostrService: nostrService);

        final l10n = lookupAppLocalizations(const Locale('en'));
        await openAddDialogAndSubmit(
          tester,
          'http://attacker.example.com',
          l10n,
        );

        expect(find.text(l10n.relaySettingsInvalidUrl), findsOneWidget);
        expect(find.text(l10n.relaySettingsInsecureUrl), findsNothing);
        verifyNever(() => nostrService.addRelay(any()));
      },
    );
  });
}
