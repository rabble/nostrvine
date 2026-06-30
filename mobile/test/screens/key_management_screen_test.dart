// ABOUTME: Widget tests for KeyManagementScreen public key and export capability UI
// ABOUTME: Verifies public key copy plus Keycast local-vs-remote signing states

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/services/auth_service.dart';

import '../helpers/test_provider_overrides.dart';

class _FakeKeyManagementAuthService extends Fake implements AuthService {
  _FakeKeyManagementAuthService({
    required this.currentNpub,
    required this.authenticationSource,
    required this.canExportLocalNsec,
  });

  @override
  final String currentNpub;

  @override
  final AuthenticationSource authenticationSource;

  @override
  final bool canExportLocalNsec;

  @override
  bool get isAuthenticated => true;

  @override
  AuthState get authState => AuthState.authenticated;

  @override
  Stream<AuthState> get authStateStream => const Stream<AuthState>.empty();

  @override
  String? get currentPublicKeyHex => null;

  @override
  bool get isNip07Available => false;

  @override
  Future<String?> exportNsec({String? biometricPrompt}) async => null;
}

void main() {
  group(KeyManagementScreen, () {
    setUpAll(() async {
      await loadAppFonts();
    });

    const testNpub =
        'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz';

    late _FakeKeyManagementAuthService authService;

    setUp(() {
      authService = _FakeKeyManagementAuthService(
        currentNpub: testNpub,
        authenticationSource: AuthenticationSource.importedKeys,
        canExportLocalNsec: false,
      );
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
        authService = _FakeKeyManagementAuthService(
          currentNpub: testNpub,
          authenticationSource: AuthenticationSource.divineOAuth,
          canExportLocalNsec: true,
        );

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
        authService = _FakeKeyManagementAuthService(
          currentNpub: testNpub,
          authenticationSource: AuthenticationSource.divineOAuth,
          canExportLocalNsec: false,
        );

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
      },
    );
  });
}
