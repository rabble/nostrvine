// ABOUTME: Widget tests for KeyManagementScreen public key and export capability UI
// ABOUTME: Verifies public key copy plus Keycast local-vs-remote signing states

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/services/auth_service.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  group(KeyManagementScreen, () {
    const testNpub =
        'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz';

    late MockAuthService authService;

    setUp(() {
      authService = createMockAuthService();
      when(() => authService.currentNpub).thenReturn(testNpub);
      when(
        () => authService.authenticationSource,
      ).thenReturn(AuthenticationSource.importedKeys);
      when(() => authService.canExportLocalNsec).thenReturn(false);
      when(() => authService.exportNsec()).thenAnswer((_) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
    });

    Future<void> pumpSubject(WidgetTester tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: const KeyManagementScreen(),
          mockAuthService: authService,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders the public key label', (tester) async {
      await pumpSubject(tester);
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.keyManagementYourPublicKeyLabel), findsOneWidget);
    });

    testWidgets('renders the user npub somewhere on the screen', (
      tester,
    ) async {
      await pumpSubject(tester);
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

      await pumpSubject(tester);
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.byTooltip(l10n.keyManagementCopyPublicKeyTooltip));
      await tester.pumpAndSettle();

      expect(clipboardPayload, equals(testNpub));
      expect(find.text(l10n.keyManagementPublicKeyCopied), findsOneWidget);
    });

    testWidgets(
      'shows private key copy action when Keycast account has a local nsec',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        when(
          () => authService.authenticationSource,
        ).thenReturn(AuthenticationSource.divineOAuth);
        when(() => authService.canExportLocalNsec).thenReturn(true);

        await pumpSubject(tester);

        expect(
          find.text(l10n.keyManagementCopyNsec, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text(
            l10n.keyManagementKeycastRemoteSigning,
            skipOffstage: false,
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'explains missing local nsec instead of showing copy action for RPC-only Keycast account',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        when(
          () => authService.authenticationSource,
        ).thenReturn(AuthenticationSource.divineOAuth);
        when(() => authService.canExportLocalNsec).thenReturn(false);

        await pumpSubject(tester);

        expect(
          find.text(l10n.keyManagementCopyNsec, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text(
            l10n.keyManagementKeycastRemoteSigning,
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        verifyNever(() => authService.exportNsec());
      },
    );
  });
}
