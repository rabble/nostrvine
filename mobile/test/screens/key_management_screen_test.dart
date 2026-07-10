// ABOUTME: Widget tests for KeyManagementScreen public key and export capability UI
// ABOUTME: Verifies public key copy plus Keycast local-vs-remote signing states

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
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

  int importFromNsecCallCount = 0;

  @override
  Future<AuthResult> importFromNsec(
    String nsec, {
    String? biometricPrompt,
  }) async {
    importFromNsecCallCount++;
    return const AuthResult(success: true);
  }
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

    Future<void> pumpSubject(
      WidgetTester tester, {
      bool restricted = false,
    }) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: const KeyManagementScreen(),
          mockAuthService: authService,
          additionalOverrides: [
            isKeyManagementRestrictedProvider.overrideWithValue(restricted),
          ],
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

    testWidgets(
      'hides nsec export and key import for a protected minor',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        // Local, exportable key: without the gate the copy-nsec action would
        // show, so this proves the gate — not canExportLocalNsec — hides it.
        authService = _FakeKeyManagementAuthService(
          currentNpub: testNpub,
          authenticationSource: AuthenticationSource.divineOAuth,
          canExportLocalNsec: true,
        );

        await pumpSubject(tester, restricted: true);

        expect(find.text(l10n.keyManagementRestrictedTitle), findsOneWidget);
        expect(find.text(l10n.keyManagementRestrictedBody), findsOneWidget);

        expect(
          find.text(l10n.keyManagementCopyNsec, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text(l10n.keyManagementBackupTitle, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text(l10n.keyManagementImportButton, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text(l10n.keyManagementImportTitle, skipOffstage: false),
          findsNothing,
        );
      },
    );

    testWidgets(
      'shows nsec export and key import for a normal account',
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
          find.text(l10n.keyManagementImportButton, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text(l10n.keyManagementRestrictedTitle), findsNothing);
      },
    );

    testWidgets(
      'does not import the key when the gate flips to restricted while the '
      'confirmation dialog is open',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final restrictedFlip = StateProvider<bool>((ref) => false);
        authService = _FakeKeyManagementAuthService(
          currentNpub: testNpub,
          authenticationSource: AuthenticationSource.importedKeys,
          canExportLocalNsec: true,
        );

        // Tall surface so the import button is fully hittable (the screen is a
        // long ListView; on the default 800x600 it sits at the viewport edge).
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // The import-confirm dialog pops via go_router's context.pop, so the
        // screen must be hosted inside a GoRouter, not a plain MaterialApp.
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const KeyManagementScreen(),
            ),
          ],
        );
        await tester.pumpWidget(
          testProviderScope(
            mockAuthService: authService,
            additionalOverrides: [
              isKeyManagementRestrictedProvider.overrideWith(
                (ref) => ref.watch(restrictedFlip),
              ),
            ],
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
              theme: ThemeData.dark(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start the import: enter an nsec and open the confirmation dialog.
        await tester.enterText(find.byType(TextField), 'nsec1${'0' * 58}');
        await tester.ensureVisible(
          find.text(l10n.keyManagementImportButton),
        );
        await tester.tap(find.text(l10n.keyManagementImportButton));
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.keyManagementConfirmImportTitle),
          findsOneWidget,
        );

        // Gate flips to restricted while the dialog is still open.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(KeyManagementScreen)),
        );
        container.read(restrictedFlip.notifier).state = true;
        await tester.pump();

        // Confirm the already-open dialog; the raw-key call must be gated.
        await tester.tap(find.text(l10n.keyManagementImportConfirm));
        await tester.pumpAndSettle();

        expect(authService.importFromNsecCallCount, isZero);
      },
    );
  });
}
