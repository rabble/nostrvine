// ABOUTME: Widget tests for RelaySettingsScreen layout.
// ABOUTME: Verifies the Nostr relay menu aligns with other settings screens.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    (
      tester,
    ) async {
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
      when(
        () => capabilityService.getRelayCapabilities(any()),
      ).thenThrow(
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
}
