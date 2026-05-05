// ABOUTME: In-app WebView host for https://verifier.divine.video.
// ABOUTME: User completes external-account verification; verifier publishes the kind 0 update directly.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A factory hook that returns a fully-configured [WebViewController] for the
/// verifier WebView. Tests inject a fake controller; production uses
/// [VerifierWebViewScreen.defaultControllerFactory].
typedef VerifierWebViewControllerFactory = WebViewController Function(Uri url);

/// Hosts the external verifier inside a WebKit/WebView so users can complete
/// account verification without leaving the app.
///
/// The verifier handles signing via the user's existing flow
/// (login.divine.video, browser signer, bunker, NIP-46) and publishes the
/// kind 0 update directly to relays the app already reads from. There is no
/// postMessage bridge.
class VerifierWebViewScreen extends StatefulWidget {
  /// Creates the screen pointed at [url].
  const VerifierWebViewScreen({
    required this.url,
    super.key,
    this.controllerFactory = defaultControllerFactory,
  });

  /// go_router name for the verifier WebView route.
  static const routeName = 'verifier-webview';

  /// go_router path for the verifier WebView route.
  static const path = '/profile/verifier';

  /// Default controller factory used in production.
  static WebViewController defaultControllerFactory(Uri url) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(VineTheme.backgroundColor)
      ..loadRequest(url);
  }

  /// URL the WebView should load.
  final Uri url;

  /// Controller factory hook for tests.
  final VerifierWebViewControllerFactory controllerFactory;

  @override
  State<VerifierWebViewScreen> createState() => _VerifierWebViewScreenState();
}

class _VerifierWebViewScreenState extends State<VerifierWebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controllerFactory(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: l10n.verifierWebViewTitle,
        showBackButton: true,
        onBackPressed: () => context.pop(),
      ),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }
}
