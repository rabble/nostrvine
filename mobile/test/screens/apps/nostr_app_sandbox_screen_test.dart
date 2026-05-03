import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  group('NostrAppSandboxScreen', () {
    testWidgets(
      'does not call setBackgroundColor on macOS WebView initialization',
      (tester) async {
        WebViewPlatform.instance = _ThrowOnBackgroundColorWebViewPlatform();
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureApp(),
              currentUserPubkeyOverride: 'f' * 64,
            ),
          ),
        );
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('back button uses browser history before leaving the app', (
      tester,
    ) async {
      final platform = _HistoryAwareWebViewPlatform(canGoBackInitially: true);
      WebViewPlatform.instance = platform;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NostrAppSandboxScreen(
            app: _fixtureApp(),
            currentUserPubkeyOverride: 'f' * 64,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DiVineAppBarIconButton));
      await tester.pump();

      expect(platform.controller.goBackCallCount, 1);
    });

    testWidgets('bootstraps the initial Android page through injected HTML', (
      tester,
    ) async {
      final platform = _BootstrapAwareWebViewPlatform();
      WebViewPlatform.instance = platform;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final bootstrapClient = MockClient(
        (_) async => http.Response(
          '<!doctype html><html><head><script src="/app.js"></script></head><body></body></html>',
          200,
          request: http.Request('GET', Uri.parse(_fixtureApp().launchUrl)),
          headers: const {'content-type': 'text/html'},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NostrAppSandboxScreen(
            app: _fixtureApp(),
            bootstrapHttpClientOverride: bootstrapClient,
            currentUserPubkeyOverride: 'f' * 64,
          ),
        ),
      );
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;

      expect(platform.controller.loadRequestCallCount, 0);
      expect(platform.controller.loadedHtml, hasLength(1));
    });

    testWidgets(
      'includes the Divine bridge script in the initial Android bootstrap HTML',
      (tester) async {
        final platform = _BootstrapAwareWebViewPlatform();
        WebViewPlatform.instance = platform;
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final bootstrapClient = MockClient(
          (_) async => http.Response(
            '<!doctype html><html><head><script src="/app.js"></script></head><body></body></html>',
            200,
            request: http.Request('GET', Uri.parse(_fixtureApp().launchUrl)),
            headers: const {'content-type': 'text/html'},
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureApp(),
              bootstrapHttpClientOverride: bootstrapClient,
              currentUserPubkeyOverride: 'f' * 64,
            ),
          ),
        );
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;

        expect(platform.controller.loadedHtml, hasLength(1));
        expect(
          platform.controller.loadedHtml.single,
          contains('window.__divineNostrBridgeInstalled'),
        );
      },
    );

    testWidgets(
      'bootstraps Android HTML app shells even when the route returns 404',
      (tester) async {
        final platform = _BootstrapAwareWebViewPlatform();
        WebViewPlatform.instance = platform;
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final bootstrapClient = MockClient(
          (_) async => http.Response(
            '<!doctype html><html><head></head><body>App shell</body></html>',
            404,
            request: http.Request(
              'GET',
              Uri.parse('https://badges.divine.video/me'),
            ),
            headers: const {'content-type': 'text/html; charset=utf-8'},
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureBadgesApp(),
              bootstrapHttpClientOverride: bootstrapClient,
              currentUserPubkeyOverride: 'f' * 64,
            ),
          ),
        );
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;

        expect(platform.controller.loadRequestCallCount, 0);
        expect(platform.controller.loadedHtml, hasLength(1));
        expect(
          platform.controller.loadedHtml.single,
          contains('window.__divineNostrBridgeInstalled'),
        );
      },
    );

    testWidgets(
      'shows a loading state before the integration finishes booting',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
      final bridgeService = NostrAppBridgeService(
        authProvider: _FakeAuthProvider(),
        policy: NostrAppBridgePolicy(
          grantStore: grantStore,
          currentUserPubkey: 'f' * 64,
        ),
        signerFactory: _FakeNostrSigner.new,
      );

      Future<void> Function(String message)? bridgeHandler;
      final executedScripts = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NostrAppSandboxScreen(
            app: _fixtureApp(),
            sandboxBuilder: (_) => const SizedBox.shrink(),
            bridgeServiceOverride: bridgeService,
            javaScriptRunnerOverride: (script) async {
              executedScripts.add(script);
            },
            onBridgeMessageHandlerReady: (handler) => bridgeHandler = handler,
            bridgeNonceOverride: 'test-nonce',
          ),
        ),
      );

      await bridgeHandler!(
        jsonEncode({
          'id': 'req-1',
          'method': 'getPublicKey',
          'args': <String, dynamic>{},
          'nonce': 'test-nonce',
        }),
      );
      await tester.pump();

      expect(executedScripts, hasLength(1));
      expect(executedScripts.single, contains('req-1'));
      expect(executedScripts.single, contains('f' * 64));
    });

    testWidgets('rejects bridge messages with no nonce as unauthorized', (
      tester,
    ) async {
      Future<void> Function(String message)? bridgeHandler;
      final executedScripts = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NostrAppSandboxScreen(
            app: _fixtureApp(),
            sandboxBuilder: (_) => const SizedBox.shrink(),
            javaScriptRunnerOverride: (script) async {
              executedScripts.add(script);
            },
            onBridgeMessageHandlerReady: (handler) => bridgeHandler = handler,
            bridgeNonceOverride: 'expected-nonce',
            currentUserPubkeyOverride: 'f' * 64,
          ),
        ),
      );

      await bridgeHandler!(
        jsonEncode({
          'id': 'subframe-1',
          'method': 'signEvent',
          'args': <String, dynamic>{
            'event': {'kind': 1},
          },
          // Note: no 'nonce' field — simulates an iframe calling
          // divineSandboxBridge.postMessage directly without the
          // main-frame bootstrap context.
        }),
      );
      await tester.pump();

      expect(executedScripts, hasLength(1));
      expect(executedScripts.single, contains('subframe-1'));
      expect(executedScripts.single, contains('subframe_or_unauthorized'));
      expect(
        executedScripts.single,
        isNot(contains('"success":true')),
      );
    });

    testWidgets(
      'rejects bridge messages with a mismatched nonce as unauthorized',
      (tester) async {
        Future<void> Function(String message)? bridgeHandler;
        final executedScripts = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureApp(),
              sandboxBuilder: (_) => const SizedBox.shrink(),
              javaScriptRunnerOverride: (script) async {
                executedScripts.add(script);
              },
              onBridgeMessageHandlerReady: (handler) => bridgeHandler = handler,
              bridgeNonceOverride: 'expected-nonce',
              currentUserPubkeyOverride: 'f' * 64,
            ),
          ),
        );

        await bridgeHandler!(
          jsonEncode({
            'id': 'subframe-2',
            'method': 'getPublicKey',
            'args': <String, dynamic>{},
            'nonce': 'attacker-guessed-nonce',
          }),
        );
        await tester.pump();

        expect(executedScripts, hasLength(1));
        expect(executedScripts.single, contains('subframe-2'));
        expect(executedScripts.single, contains('subframe_or_unauthorized'));
      },
    );

    testWidgets(
      'rejects nip44.decrypt bridge messages with a mismatched nonce as unauthorized',
      (tester) async {
        Future<void> Function(String message)? bridgeHandler;
        final executedScripts = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureApp(),
              sandboxBuilder: (_) => const SizedBox.shrink(),
              javaScriptRunnerOverride: (script) async {
                executedScripts.add(script);
              },
              onBridgeMessageHandlerReady: (handler) => bridgeHandler = handler,
              bridgeNonceOverride: 'expected-nonce',
              currentUserPubkeyOverride: 'f' * 64,
            ),
          ),
        );

        await bridgeHandler!(
          jsonEncode({
            'id': 'subframe-3',
            'method': 'nip44.decrypt',
            'args': <String, dynamic>{
              'pubkey': 'f' * 64,
              'ciphertext': 'ciphertext',
            },
            'nonce': 'attacker-guessed-nonce',
          }),
        );
        await tester.pump();

        expect(executedScripts, hasLength(1));
        expect(executedScripts.single, contains('subframe-3'));
        expect(executedScripts.single, contains('subframe_or_unauthorized'));
      },
    );

    group('bridge bootstrap script', () {
      test('includes eager pubkey when provided', () {
        final script = buildBridgeBootstrapScript(
          nonce: 'n',
          pubkey: 'abc123',
        );
        expect(script, contains("_pubkey: 'abc123'"));
      });

      test('sets pubkey to null when not provided', () {
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(script, contains("_pubkey: '' || null"));
      });

      test('includes provider metadata', () {
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(script, contains("name: 'diVine'"));
        expect(script, contains("'nip04', 'nip44'"));
      });

      test('dispatches nostr:ready event', () {
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(
          script,
          contains("window.dispatchEvent(new Event('nostr:ready'))"),
        );
      });

      test('dispatches nlAuth event for nostr-login compat', () {
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(
          script,
          contains("document.dispatchEvent(new CustomEvent('nlAuth'"),
        );
      });

      test('injects auto-login script with pubkey substituted', () {
        final script = buildBridgeBootstrapScript(
          nonce: 'n',
          pubkey: 'deadbeef',
          autoLoginScript: "localStorage.setItem('pubkey', '{{PUBKEY}}');",
        );
        expect(script, contains("localStorage.setItem('pubkey', 'deadbeef')"));
        expect(script, isNot(contains('{{PUBKEY}}')));
      });

      test('skips auto-login when script is null', () {
        final script = buildBridgeBootstrapScript(nonce: 'n', pubkey: 'abc');
        expect(script, isNot(contains('localStorage.setItem')));
      });

      test('escapes single quotes in pubkey', () {
        final script = buildBridgeBootstrapScript(nonce: 'n', pubkey: "a'b");
        expect(script, contains(r"_pubkey: 'a\'b'"));
      });

      test('escapes backslashes in pubkey', () {
        final script = buildBridgeBootstrapScript(nonce: 'n', pubkey: r'a\b');
        expect(script, contains(r"_pubkey: 'a\\b'"));
      });

      test('escapes backticks in pubkey', () {
        final script = buildBridgeBootstrapScript(nonce: 'n', pubkey: 'a`b');
        expect(script, contains(r"_pubkey: 'a\`b'"));
      });

      test('escapes newlines in pubkey', () {
        final script = buildBridgeBootstrapScript(nonce: 'n', pubkey: 'a\nb');
        expect(script, contains(r"_pubkey: 'a\nb'"));
      });

      test('refuses to install in non-main frames', () {
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(script, contains('window.top !== window.self'));
      });

      test('embeds the per-mount nonce in the bootstrap closure', () {
        final script = buildBridgeBootstrapScript(nonce: 'NONCE-XYZ');
        expect(
          script,
          contains("const __divineBridgeNonce = 'NONCE-XYZ';"),
        );
      });

      test('includes the nonce on every outgoing bridge request', () {
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(script, contains('nonce: __divineBridgeNonce'));
      });

      test('escapes single quotes in the nonce', () {
        final script = buildBridgeBootstrapScript(nonce: "a'b");
        expect(
          script,
          contains(r"const __divineBridgeNonce = 'a\'b';"),
        );
      });
    });

    group('injectBridgeBootstrapIntoHtml', () {
      test('inserts bridge after head tag', () {
        final html = injectBridgeBootstrapIntoHtml(
          '<html><head></head><body></body></html>',
          nonce: 'n',
          pubkey: 'abc',
        );
        expect(html, contains('<!-- divine-nostr-bridge -->'));
        expect(html, contains('__divineNostrBridgeInstalled'));
        expect(html, contains("_pubkey: 'abc'"));
      });

      test('includes auto-login in injected HTML', () {
        final html = injectBridgeBootstrapIntoHtml(
          '<html><head></head><body></body></html>',
          nonce: 'n',
          pubkey: 'abc',
          autoLoginScript: "localStorage.setItem('loginType', 'extension');",
        );
        expect(
          html,
          contains("localStorage.setItem('loginType', 'extension')"),
        );
      });

      test('forwards the nonce into the embedded bootstrap script', () {
        final html = injectBridgeBootstrapIntoHtml(
          '<html><head></head><body></body></html>',
          nonce: 'NONCE-XYZ',
          pubkey: 'abc',
        );
        expect(
          html,
          contains("const __divineBridgeNonce = 'NONCE-XYZ';"),
        );
      });
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
    allowedMethods: const ['getPublicKey', 'getRelays', 'signEvent'],
    allowedSignEventKinds: const [1],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.parse('2026-03-24T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-25T08:00:00Z'),
  );
}

NostrAppDirectoryEntry _fixtureBadgesApp() {
  return NostrAppDirectoryEntry(
    id: 'bundled-badges',
    slug: 'badges',
    name: 'Divine Badges',
    tagline: 'Manage Nostr badge awards',
    description: 'Accept, reject, and issue Divine badges.',
    iconUrl: 'https://badges.divine.video/favicon.ico',
    launchUrl: 'https://badges.divine.video/me',
    allowedOrigins: const ['https://badges.divine.video'],
    allowedMethods: const ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: const [3, 8, 10002, 10008, 30008, 30009],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 15,
    createdAt: DateTime.parse('2026-05-02T00:00:00Z'),
    updatedAt: DateTime.parse('2026-05-02T00:00:00Z'),
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

class _HistoryAwareWebViewPlatform extends WebViewPlatform {
  _HistoryAwareWebViewPlatform({required this.canGoBackInitially});

  final bool canGoBackInitially;
  late final _HistoryAwareWebViewController controller;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    controller = _HistoryAwareWebViewController(
      params,
      canGoBackInitially: canGoBackInitially,
    );
    return controller;
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

class _BootstrapAwareWebViewPlatform extends WebViewPlatform {
  late final _BootstrapAwareWebViewController controller;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    controller = _BootstrapAwareWebViewController(params);
    return controller;
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

class _HistoryAwareWebViewController extends PlatformWebViewController {
  _HistoryAwareWebViewController(
    super.params, {
    required this.canGoBackInitially,
  }) : super.implementation();

  final bool canGoBackInitially;
  int goBackCallCount = 0;

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

  @override
  Future<bool> canGoBack() async => canGoBackInitially;

  @override
  Future<void> goBack() async {
    goBackCallCount += 1;
  }
}

class _BootstrapAwareWebViewController extends PlatformWebViewController {
  _BootstrapAwareWebViewController(super.params) : super.implementation();

  int loadRequestCallCount = 0;
  final loadedHtml = <String>[];

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
  Future<void> loadRequest(LoadRequestParams params) async {
    loadRequestCallCount += 1;
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    loadedHtml.add(html);
  }

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

class _FakeAuthProvider implements BridgeAuthProvider {
  @override
  String? get currentPublicKeyHex => 'f' * 64;

  @override
  List<BridgeRelay> get userRelays => const [];

  @override
  Future<BridgeSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
    int? createdAt,
  }) async {
    final event = Event('f' * 64, kind, tags, content, createdAt: createdAt);
    return BridgeSignedEvent(json: event.toJson());
  }
}

class _FakeNostrSigner implements NostrSigner {
  @override
  void close() {}

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async => null;

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async => null;

  @override
  Future<String?> getPublicKey() async => 'f' * 64;

  @override
  Future<Map<dynamic, dynamic>?> getRelays() async => null;

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async => null;

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async => null;

  @override
  Future<Event?> signEvent(Event event) async => event;
}
