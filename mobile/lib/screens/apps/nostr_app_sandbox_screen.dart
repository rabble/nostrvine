// ABOUTME: Dedicated sandbox browser for vetted Nostr apps
// ABOUTME: Blocks navigation outside approved origins before bridge injection is added

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef SandboxViewBuilder =
    Widget Function(
      void Function(Uri uri) onNavigationAttempt,
    );

class NostrAppSandboxScreen extends ConsumerStatefulWidget {
  static const routeName = 'nostr-app-sandbox';
  static const path = '/apps/:appId/sandbox';

  const NostrAppSandboxScreen({
    required this.app,
    this.sandboxBuilder,
    this.onNavigationHandlerReady,
    super.key,
  });

  final NostrAppDirectoryEntry app;
  final SandboxViewBuilder? sandboxBuilder;
  final ValueChanged<void Function(Uri uri)>? onNavigationHandlerReady;

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

  @override
  void initState() {
    super.initState();
    widget.onNavigationHandlerReady?.call(_handleNavigationAttempt);

    if (widget.sandboxBuilder != null) {
      return;
    }

    final launchUri = Uri.parse(widget.app.launchUrl);
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(VineTheme.backgroundColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (_) {
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
                    'Tried to leave the approved app origin.\n\n${_blockedUri.toString()}',
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
