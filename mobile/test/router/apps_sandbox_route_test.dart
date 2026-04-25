import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../helpers/test_provider_overrides.dart';

class _MockNostrAppDirectoryService extends Mock
    implements NostrAppDirectoryService {}

void main() {
  setUpAll(() {
    WebViewPlatform.instance = _FakeWebViewPlatform();
  });

  testWidgets('${NostrAppSandboxScreen.path} route works', (tester) async {
    SharedPreferences.setMockInitialValues({
      'current_user_pubkey_hex': 'f' * 64,
      'following_list_${'f' * 64}': '["npub1followed"]',
    });
    final sharedPreferences = await SharedPreferences.getInstance();
    final mockAuth = createMockAuthService();
    when(() => mockAuth.isAuthenticated).thenReturn(true);
    when(() => mockAuth.currentPublicKeyHex).thenReturn('f' * 64);
    when(() => mockAuth.authState).thenReturn(AuthState.authenticated);
    when(
      () => mockAuth.authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());

    final container = ProviderContainer(
      overrides: [
        ...getStandardTestOverrides(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: mockAuth,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: container.read(goRouterProvider),
        ),
      ),
    );

    final router = container.read(goRouterProvider);
    router.go(
      NostrAppSandboxScreen.pathForAppId('primal-app'),
      extra: _sandboxApp(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      router.routeInformationProvider.value.uri.toString(),
      NostrAppSandboxScreen.pathForAppId('primal-app'),
    );
  });

  testWidgets(
    'resolves the sandbox route from the directory when extra is absent',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'current_user_pubkey_hex': 'f' * 64,
        'following_list_${'f' * 64}': '["npub1followed"]',
      });
      final sharedPreferences = await SharedPreferences.getInstance();
      final mockAuth = createMockAuthService();
      final mockDirectoryService = _MockNostrAppDirectoryService();
      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(() => mockAuth.currentPublicKeyHex).thenReturn('f' * 64);
      when(() => mockAuth.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuth.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      when(
        mockDirectoryService.fetchApprovedApps,
      ).thenAnswer((_) async => [_sandboxApp()]);

      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(
            mockSharedPreferences: sharedPreferences,
            mockAuthService: mockAuth,
          ),
          nostrAppDirectoryServiceProvider.overrideWithValue(
            mockDirectoryService,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go(NostrAppSandboxScreen.pathForAppId('primal-app'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sandbox unavailable'), findsNothing);
      expect(find.text('Primal'), findsOneWidget);
    },
  );

  testWidgets(
    'shows integration unavailable messaging when the app cannot be resolved',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'current_user_pubkey_hex': 'f' * 64,
        'following_list_${'f' * 64}': '["npub1followed"]',
      });
      final sharedPreferences = await SharedPreferences.getInstance();
      final mockAuth = createMockAuthService();
      final mockDirectoryService = _MockNostrAppDirectoryService();
      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(() => mockAuth.currentPublicKeyHex).thenReturn('f' * 64);
      when(() => mockAuth.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuth.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      when(
        mockDirectoryService.fetchApprovedApps,
      ).thenAnswer((_) async => const []);

      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(
            mockSharedPreferences: sharedPreferences,
            mockAuthService: mockAuth,
          ),
          nostrAppDirectoryServiceProvider.overrideWithValue(
            mockDirectoryService,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go(NostrAppSandboxScreen.pathForAppId('missing-app'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Integration unavailable'), findsOneWidget);
      expect(
        find.text(
          'Open approved integrations from the Integrated Apps tab so Divine can apply the right access policy.',
        ),
        findsOneWidget,
      );
    },
  );
}

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _FakeWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakeWebViewWidget(params);
  }

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) {
    return _FakeCookieManager(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return _FakeNavigationDelegate(params);
  }
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<String?> currentUrl() async => 'https://primal.net/app';
}

class _FakeCookieManager extends PlatformWebViewCookieManager {
  _FakeCookieManager(super.params) : super.implementation();
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}

  @override
  Future<void> setOnHttpAuthRequest(HttpAuthRequestCallback handler) async {}

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}
}

NostrAppDirectoryEntry _sandboxApp() {
  return NostrAppDirectoryEntry(
    id: 'primal-app',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages',
    description: 'A vetted Nostr client for timelines and DMs.',
    iconUrl: 'https://cdn.divine.video/primal.png',
    launchUrl: 'https://primal.net/app',
    allowedOrigins: const ['https://primal.net'],
    allowedMethods: const ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: const [1],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.parse('2026-03-24T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-25T08:00:00Z'),
  );
}
