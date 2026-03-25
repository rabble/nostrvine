// ABOUTME: Dedicated sandbox browser for vetted Nostr apps
// ABOUTME: Blocks navigation outside approved origins before bridge injection is added

import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/nostr_app_bridge_service.dart';
import 'package:openvine/widgets/apps/nostr_app_permission_prompt_sheet.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
    this.javaScriptRunnerOverride,
    this.onBridgeMessageHandlerReady,
    super.key,
  });

  final NostrAppDirectoryEntry app;
  final SandboxViewBuilder? sandboxBuilder;
  final ValueChanged<void Function(Uri uri)>? onNavigationHandlerReady;
  final NostrAppBridgeService? bridgeServiceOverride;
  final SandboxJavaScriptRunner? javaScriptRunnerOverride;
  final ValueChanged<Future<void> Function(String message)>?
  onBridgeMessageHandlerReady;

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
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(VineTheme.backgroundColor)
      ..setNavigationDelegate(
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

            final allowed = _handleNavigationAttempt(uri);
            return allowed
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..addJavaScriptChannel(
        NostrAppSandboxScreen.bridgeChannelName,
        onMessageReceived: (message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..loadRequest(launchUri);

    _webViewController = controller;
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

  Future<void> _injectBridge() async {
    final origin = _currentPageUri;
    if (origin == null || !_isAllowedOrigin(origin)) {
      return;
    }

    await _runJavaScript(_bridgeBootstrapScript);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: widget.app.name,
        showBackButton: true,
        onBackPressed: context.pop,
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
                    'Tried to leave the approved app origin.\n\n$_blockedUri',
              ),
            )
          else if (_isLoading)
            const Positioned.fill(
              child: _SandboxStatusCard(
                title: 'Loading app sandbox',
                subtitle: 'Checking the approved app origin before launch.',
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

const String _bridgeBootstrapScript = r'''
(() => {
  if (window.__divineNostrBridgeInstalled) {
    return;
  }

  const pending = new Map();
  let nextId = 0;

  const request = (method, args) => {
    const id = `divine-${++nextId}`;
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
    getPublicKey() {
      return request('getPublicKey', {});
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
})();
''';

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
