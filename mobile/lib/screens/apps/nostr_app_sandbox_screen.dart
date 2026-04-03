// ABOUTME: Dedicated integration container for approved third-party apps
// ABOUTME: Blocks navigation outside approved origins before bridge injection is added

import 'dart:async';
import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/apps/nostr_app_permission_prompt_sheet.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/src/common/web_kit.g.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

typedef SandboxViewBuilder =
    Widget Function(
      void Function(Uri uri) onNavigationAttempt,
    );
typedef SandboxJavaScriptRunner = Future<void> Function(String script);

class NostrAppSandboxScreen extends ConsumerStatefulWidget {
  static const routeName = 'nostr-app-sandbox';
  static const path = '/apps/:appId/sandbox';
  static const bridgeChannelName = 'divineSandboxBridge';

  const NostrAppSandboxScreen({
    required this.app,
    this.sandboxBuilder,
    this.onNavigationHandlerReady,
    this.bridgeServiceOverride,
    this.bootstrapHttpClientOverride,
    this.javaScriptRunnerOverride,
    this.onBridgeMessageHandlerReady,
    this.currentUserPubkeyOverride,
    super.key,
  });

  final NostrAppDirectoryEntry app;
  final SandboxViewBuilder? sandboxBuilder;
  final ValueChanged<void Function(Uri uri)>? onNavigationHandlerReady;
  final NostrAppBridgeService? bridgeServiceOverride;
  final http.Client? bootstrapHttpClientOverride;
  final SandboxJavaScriptRunner? javaScriptRunnerOverride;
  final ValueChanged<Future<void> Function(String message)>?
  onBridgeMessageHandlerReady;
  @visibleForTesting
  final String? currentUserPubkeyOverride;

  static String pathForAppId(String appId) =>
      '/apps/${Uri.encodeComponent(appId)}/sandbox';

  @override
  ConsumerState<NostrAppSandboxScreen> createState() =>
      _NostrAppSandboxScreenState();
}

class _NostrAppSandboxScreenState extends ConsumerState<NostrAppSandboxScreen> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  Uri? _blockedUri;
  Uri? _currentPageUri;
  http.Client? _ownedBootstrapHttpClient;

  String? get _currentUserPubkey =>
      widget.currentUserPubkeyOverride ??
      ref.read(authServiceProvider).currentPublicKeyHex;

  @override
  void initState() {
    super.initState();
    _currentPageUri = Uri.parse(widget.app.launchUrl);
    widget.onNavigationHandlerReady?.call(_handleNavigationAttempt);
    widget.onBridgeMessageHandlerReady?.call(_handleBridgeMessage);

    if (widget.sandboxBuilder != null) {
      return;
    }

    final launchUri = Uri.parse(widget.app.launchUrl);
    final controller = _createWebViewController();
    _webViewController = controller;
    unawaited(_configureAndLoadController(controller, launchUri));
  }

  @override
  void dispose() {
    _ownedBootstrapHttpClient?.close();
    super.dispose();
  }

  bool _handleNavigationAttempt(Uri uri) {
    if (_isAllowedOrigin(uri)) {
      if (_blockedUri != null && mounted) {
        setState(() {
          _blockedUri = null;
        });
      }
      return true;
    }

    if (!mounted) return false;
    setState(() {
      _blockedUri = uri;
      _isLoading = false;
    });
    return false;
  }

  bool _isAllowedOrigin(Uri uri) {
    return widget.app.allowedOrigins.any((allowedOrigin) {
      final parsedAllowed = Uri.tryParse(allowedOrigin);
      return parsedAllowed != null && parsedAllowed.origin == uri.origin;
    });
  }

  NostrAppBridgeService get _bridgeService =>
      widget.bridgeServiceOverride ?? ref.read(nostrAppBridgeServiceProvider);

  http.Client get _bootstrapHttpClient =>
      widget.bootstrapHttpClientOverride ??
      (_ownedBootstrapHttpClient ??= http.Client());

  WebViewController _createWebViewController() {
    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params =
          WebKitWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(
            params,
          );
    }

    return WebViewController.fromPlatformCreationParams(params);
  }

  Future<void> _configureAndLoadController(
    WebViewController controller,
    Uri launchUri,
  ) async {
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      await controller.setBackgroundColor(VineTheme.backgroundColor);
    }

    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          _currentPageUri = Uri.tryParse(url) ?? _currentPageUri;
          if (!mounted) return;
          setState(() {
            _isLoading = true;
          });
        },
        onPageFinished: (url) async {
          _currentPageUri = Uri.tryParse(url) ?? _currentPageUri;
          await _injectBridge();
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
        },
        onWebResourceError: (_) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null) {
            return NavigationDecision.prevent;
          }

          if (!_handleNavigationAttempt(uri)) {
            return NavigationDecision.prevent;
          }

          if (_shouldBootstrapNavigation(request, uri)) {
            unawaited(_loadSandboxPage(uri));
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ),
    );

    await controller.addJavaScriptChannel(
      NostrAppSandboxScreen.bridgeChannelName,
      onMessageReceived: (message) {
        _handleBridgeMessage(message.message);
      },
    );

    await _installDocumentStartBridgeIfSupported(controller);
    await _loadSandboxPage(launchUri);
  }

  bool _shouldBootstrapNavigation(NavigationRequest request, Uri uri) {
    return defaultTargetPlatform == TargetPlatform.android &&
        request.isMainFrame &&
        _isAllowedOrigin(uri);
  }

  Future<void> _loadSandboxPage(Uri uri) async {
    final controller = _webViewController;
    if (controller == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _blockedUri = null;
      });
    }

    final bootstrap = await _prepareBootstrapHtml(uri);
    if (bootstrap != null) {
      _currentPageUri = bootstrap.baseUri;
      await controller.loadHtmlString(
        bootstrap.html,
        baseUrl: bootstrap.baseUri.toString(),
      );
      return;
    }

    _currentPageUri = uri;
    await controller.loadRequest(uri);
  }

  Future<void> _installDocumentStartBridgeIfSupported(
    WebViewController controller,
  ) async {
    final platformController = controller.platform;
    if (platformController is! WebKitWebViewController) {
      return;
    }

    final nativeWebView = PigeonInstanceManager.instance
        .getInstanceWithWeakReference<WKWebView>(
          platformController.webViewIdentifier,
        );
    if (nativeWebView == null) {
      return;
    }

    final WKWebViewConfiguration configuration;
    switch (nativeWebView) {
      case UIViewWKWebView():
        configuration = nativeWebView.configuration;
      case NSViewWKWebView():
        configuration = nativeWebView.configuration;
      default:
        return;
    }

    final contentController = await configuration.getUserContentController();
    final fullScript = buildBridgeBootstrapScript(
      pubkey: _currentUserPubkey,
      autoLoginScript: widget.app.autoLoginScript,
    );
    final userScript = WKUserScript(
      source: fullScript,
      injectionTime: UserScriptInjectionTime.atDocumentStart,
      isForMainFrameOnly: false,
    );

    await contentController.addUserScript(userScript);
  }

  Future<_BootstrappedSandboxPage?> _prepareBootstrapHtml(Uri uri) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      final response = await _bootstrapHttpClient.get(
        uri,
        headers: const {'accept': 'text/html,application/xhtml+xml'},
      );
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.body.isEmpty) {
        return null;
      }

      final resolvedUri = response.request?.url ?? uri;
      if (!_isAllowedOrigin(resolvedUri)) {
        return null;
      }

      return _BootstrappedSandboxPage(
        baseUri: resolvedUri,
        html: injectBridgeBootstrapIntoHtml(
          response.body,
          pubkey: _currentUserPubkey,
          autoLoginScript: widget.app.autoLoginScript,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _injectBridge() async {
    final origin = _currentPageUri;
    if (origin == null || !_isAllowedOrigin(origin)) {
      return;
    }

    final fullScript = buildBridgeBootstrapScript(
      pubkey: _currentUserPubkey,
      autoLoginScript: widget.app.autoLoginScript,
    );
    await _runJavaScript(fullScript);
  }

  Future<void> _handleBridgeMessage(String message) async {
    String responseId = 'unknown';

    try {
      final payload = jsonDecode(message);
      if (payload is! Map) {
        throw const FormatException('Bridge payload must be a JSON object');
      }

      final request = payload.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      responseId = request['id']?.toString() ?? 'unknown';
      final method = request['method']?.toString();
      final args = request['args'];

      if (method == null || method.isEmpty) {
        throw const FormatException('Bridge method is required');
      }
      if (args is! Map) {
        throw const FormatException('Bridge args must be an object');
      }

      final origin = _currentPageUri ?? Uri.parse(widget.app.launchUrl);
      final result = await _bridgeService.handleRequest(
        app: widget.app,
        origin: origin,
        method: method,
        args: args.map((key, value) => MapEntry(key.toString(), value)),
        promptForPermission: _showPermissionPrompt,
      );

      await _emitBridgeResponse(
        id: responseId,
        result: result,
      );
    } catch (error) {
      await _emitBridgeResponse(
        id: responseId,
        result: BridgeResult.error(
          'invalid_request',
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<bool> _showPermissionPrompt(BridgePermissionRequest request) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: NostrAppPermissionPromptSheet(
            appName: request.app.name,
            origin: request.origin.origin,
            method: request.method,
            capability: request.capability,
            eventKind: request.eventKind,
            onAllow: () => Navigator.of(bottomSheetContext).pop(true),
            onCancel: () => Navigator.of(bottomSheetContext).pop(false),
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _emitBridgeResponse({
    required String id,
    required BridgeResult result,
  }) async {
    final payload = {
      'id': id,
      'success': result.success,
      if (result.success) 'result': result.data,
      if (!result.success)
        'error': {
          'code': result.errorCode ?? 'bridge_error',
          if (result.errorMessage != null) 'message': result.errorMessage,
        },
    };

    final encodedPayload = jsonEncode(payload);
    await _runJavaScript(
      'window.__divineNostrBridge?.handleResponse($encodedPayload);',
    );
  }

  Future<void> _runJavaScript(String script) async {
    final overrideRunner = widget.javaScriptRunnerOverride;
    if (overrideRunner != null) {
      await overrideRunner(script);
      return;
    }

    final controller = _webViewController;
    if (controller == null) {
      return;
    }

    await controller.runJavaScript(script);
  }

  Future<void> _handleBackPressed() async {
    final controller = _webViewController;
    if (controller != null) {
      final canGoBack = await controller.canGoBack();
      if (canGoBack) {
        await controller.goBack();
        return;
      }
    }

    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: widget.app.name,
        showBackButton: true,
        onBackPressed: () {
          unawaited(_handleBackPressed());
        },
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(child: _buildSandboxBody()),
          if (_blockedUri != null)
            Positioned.fill(
              child: _SandboxStatusCard(
                title: 'Blocked for safety',
                subtitle:
                    'This integration tried to leave its approved origin.\n\n$_blockedUri',
              ),
            )
          else if (_isLoading)
            const Positioned.fill(
              child: _SandboxStatusCard(
                title: 'Loading integration',
                subtitle: 'Checking the approved integration before launch.',
                showSpinner: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSandboxBody() {
    if (widget.sandboxBuilder != null) {
      return widget.sandboxBuilder!(_handleNavigationAttempt);
    }

    final controller = _webViewController;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return WebViewWidget(controller: controller);
  }
}

/// Builds the bridge bootstrap JavaScript with optional eager pubkey,
/// provider metadata, ready-event dispatch, and per-app auto-login.
@visibleForTesting
String buildBridgeBootstrapScript({
  String? pubkey,
  String? autoLoginScript,
}) {
  final escapedPubkey = pubkey != null && pubkey.isNotEmpty
      ? _escapeJs(pubkey)
      : '';
  final loginJs = autoLoginScript != null && autoLoginScript.isNotEmpty
      ? autoLoginScript.replaceAll('{{PUBKEY}}', escapedPubkey)
      : '';

  return '''
(() => {
  if (window.__divineNostrBridgeInstalled) {
    return;
  }

  const pending = new Map();
  let nextId = 0;

  const request = (method, args) => {
    const id = `divine-\${++nextId}`;
    const payload = JSON.stringify({
      id,
      method,
      args: args ?? {},
    });

    return new Promise((resolve, reject) => {
      pending.set(id, { resolve, reject });
      divineSandboxBridge.postMessage(payload);
    });
  };

  window.__divineNostrBridge = {
    handleResponse(response) {
      const pendingRequest = pending.get(response.id);
      if (!pendingRequest) {
        return;
      }

      pending.delete(response.id);

      if (response.success) {
        pendingRequest.resolve(response.result);
        return;
      }

      const error = response.error || { code: 'bridge_error' };
      const exception = new Error(error.message || error.code);
      exception.code = error.code;
      pendingRequest.reject(exception);
    },
  };

  window.nostr = {
    _pubkey: '$escapedPubkey' || null,
    _metadata: {
      name: 'diVine',
      version: '1.0',
      supports: ['nip04', 'nip44'],
    },
    getPublicKey() {
      if (this._pubkey) return Promise.resolve(this._pubkey);
      return request('getPublicKey', {});
    },
    getRelays() {
      return request('getRelays', {});
    },
    signEvent(event) {
      return request('signEvent', { event });
    },
    nip44: {
      encrypt(pubkey, plaintext) {
        return request('nip44.encrypt', { pubkey, plaintext });
      },
      decrypt(pubkey, ciphertext) {
        return request('nip44.decrypt', { pubkey, ciphertext });
      },
    },
  };

  window.__divineNostrBridgeInstalled = true;

  // Auto-login: seed localStorage so the app recognises the session.
  try { $loginJs } catch (_) {}

  // Signal that a NIP-07 signer is available.
  window.dispatchEvent(new Event('nostr:ready'));
  document.dispatchEvent(new CustomEvent('nlAuth', {
    detail: { type: 'login', method: 'extension' },
  }));
})();
''';
}

/// Escapes a string for safe embedding inside a JS single-quoted
/// literal.
String _escapeJs(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('`', r'\`')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
}

class _SandboxStatusCard extends StatelessWidget {
  const _SandboxStatusCard({
    required this.title,
    required this.subtitle,
    this.showSpinner = false,
  });

  final String title;
  final String subtitle;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: VineTheme.outlineMuted),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSpinner) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                ] else ...[
                  const Icon(
                    Icons.shield_outlined,
                    color: VineTheme.vineGreen,
                    size: 28,
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: VineTheme.headlineSmallFont(
                    color: VineTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: VineTheme.bodyLargeFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrappedSandboxPage {
  const _BootstrappedSandboxPage({
    required this.baseUri,
    required this.html,
  });

  final Uri baseUri;
  final String html;
}

@visibleForTesting
String injectBridgeBootstrapIntoHtml(
  String html, {
  String? pubkey,
  String? autoLoginScript,
}) {
  final script = buildBridgeBootstrapScript(
    pubkey: pubkey,
    autoLoginScript: autoLoginScript,
  );
  final bridgeMarkup = '<!-- divine-nostr-bridge --><script>$script</script>';
  final insertionPoints = <RegExp>[
    RegExp('<head[^>]*>', caseSensitive: false),
    RegExp('<!doctype[^>]*>', caseSensitive: false),
    RegExp('<html[^>]*>', caseSensitive: false),
    RegExp('<body[^>]*>', caseSensitive: false),
  ];

  for (final insertionPoint in insertionPoints) {
    final match = insertionPoint.firstMatch(html);
    if (match != null) {
      return html.replaceRange(match.end, match.end, bridgeMarkup);
    }
  }

  return '$bridgeMarkup$html';
}
