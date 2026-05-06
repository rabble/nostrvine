// ABOUTME: Widget tests for the public-key (npub) display block on the key
// ABOUTME: management screen: label, npub display, copy-to-clipboard.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group(KeyManagementScreen, () {
    const testNpub =
        'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz';

    late _MockAuthService mockAuthService;
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockAuthService = _MockAuthService();
      mockNostrClient = _MockNostrClient();
      when(() => mockAuthService.currentNpub).thenReturn(testNpub);
    });

    Widget buildSubject() {
      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const KeyManagementScreen(),
        ),
      );
    }

    testWidgets('renders the public key label', (tester) async {
      await tester.pumpWidget(buildSubject());
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.keyManagementYourPublicKeyLabel), findsOneWidget);
    });

    testWidgets('renders the user npub somewhere on the screen', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text(testNpub), findsOneWidget);
    });

    testWidgets('copies npub to clipboard when copy button is tapped', (
      tester,
    ) async {
      String? clipboardPayload;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardPayload = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(buildSubject());
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.tap(
        find.byTooltip(l10n.keyManagementCopyPublicKeyTooltip),
      );
      await tester.pumpAndSettle();

      expect(clipboardPayload, equals(testNpub));
      expect(find.text(l10n.keyManagementPublicKeyCopied), findsOneWidget);
    });
  });
}
