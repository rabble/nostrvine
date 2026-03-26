import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_app_bridge_policy.dart';
import 'package:openvine/services/nostr_app_bridge_service.dart';
import 'package:openvine/services/nostr_app_grant_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('NostrAppSandboxScreen', () {
    testWidgets(
      'does not call setBackgroundColor on macOS WebView initialization',
      (tester) async {
        WebViewPlatform.instance = _ThrowOnBackgroundColorWebViewPlatform();
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

        await tester.pumpWidget(
          MaterialApp(
            home: NostrAppSandboxScreen(app: _fixtureApp()),
          ),
        );
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shows a loading state before the integration finishes booting',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: NostrAppSandboxScreen(
              app: _fixtureApp(),
              sandboxBuilder: (_) => const SizedBox.shrink(),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading integration'), findsOneWidget);
        expect(
          find.text('Checking the approved integration before launch.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('blocks off-origin navigation for safety', (tester) async {
      void Function(Uri uri)? navigationHandler;

      await tester.pumpWidget(
        MaterialApp(
          home: NostrAppSandboxScreen(
            app: _fixtureApp(),
            sandboxBuilder: (_) => const SizedBox.shrink(),
            onNavigationHandlerReady: (handler) => navigationHandler = handler,
          ),
        ),
      );

      navigationHandler!(Uri.parse('https://evil.example/phish'));
      await tester.pump();

      expect(find.text('Blocked for safety'), findsOneWidget);
      expect(
        find.textContaining(
          'This integration tried to leave its approved origin',
        ),
        findsOneWidget,
      );
    });

    testWidgets('handles bridge messages and emits JavaScript responses', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final sharedPreferences = await SharedPreferences.getInstance();
      final grantStore = NostrAppGrantStore(
        sharedPreferences: sharedPreferences,
      );
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn('f' * 64);

      final bridgeService = NostrAppBridgeService(
        authService: authService,
        policy: NostrAppBridgePolicy(
          grantStore: grantStore,
          currentUserPubkey: 'f' * 64,
        ),
      );

      Future<void> Function(String message)? bridgeHandler;
      final executedScripts = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: NostrAppSandboxScreen(
            app: _fixtureApp(),
            sandboxBuilder: (_) => const SizedBox.shrink(),
            bridgeServiceOverride: bridgeService,
            javaScriptRunnerOverride: (script) async {
              executedScripts.add(script);
            },
            onBridgeMessageHandlerReady: (handler) => bridgeHandler = handler,
          ),
        ),
      );

      await bridgeHandler!(
        jsonEncode({
          'id': 'req-1',
          'method': 'getPublicKey',
          'args': <String, dynamic>{},
        }),
      );
      await tester.pump();

      expect(executedScripts, hasLength(1));
      expect(executedScripts.single, contains('req-1'));
      expect(executedScripts.single, contains('f' * 64));
    });
  });
}

NostrAppDirectoryEntry _fixtureApp() {
  return NostrAppDirectoryEntry(
    id: 'primal',
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

class _ThrowOnBackgroundColorWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _ThrowOnBackgroundColorWebViewController(params);
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

class _ThrowOnBackgroundColorWebViewController
    extends PlatformWebViewController {
  _ThrowOnBackgroundColorWebViewController(super.params)
    : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {
    throw UnimplementedError('opaque is not implemented on macOS');
  }

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
}
