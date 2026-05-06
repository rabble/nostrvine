// ABOUTME: Flutter web iframe screen that hosts a first-party Divine integrated
// ABOUTME: app (verifyer.divine.video, badges.divine.video) inline. The embedded
// ABOUTME: app's window.nostr is proxied to Divine's WebSigner via postMessage,
// ABOUTME: so users don't have to log in twice.

// This file is selected by a conditional export in
// `web_iframe_sandbox_screen.dart` only when `dart.library.js_interop`
// is available, so dart:html and dart:ui_web are safe to import
// unconditionally here.
// TODO(#3933): migrate to package:web + dart:js_interop once codebase moves.
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/services/web_auth_service.dart';
import 'package:openvine/services/web_iframe_nostr_bridge.dart';

/// Hosts a first-party Divine integrated app in an `<iframe>` on Flutter
/// web. The iframe's window.nostr is fulfilled by [WebIframeNostrBridge]
/// against the host's [WebAuthService] signer, so the embedded app uses
/// the user's existing Divine session over postMessage and skips its
/// own login flow.
class WebIframeSandboxScreen extends StatefulWidget {
  const WebIframeSandboxScreen({required this.app, super.key});

  static const String routeName = 'web-iframe-sandbox';
  static const String path = '/apps/:appId/web-sandbox';

  static String pathForAppId(String appId) =>
      '/apps/${Uri.encodeComponent(appId)}/web-sandbox';

  final NostrAppDirectoryEntry app;

  @override
  State<WebIframeSandboxScreen> createState() => _WebIframeSandboxScreenState();
}

class _WebIframeSandboxScreenState extends State<WebIframeSandboxScreen> {
  late final String _viewType;
  late final WebIframeNostrBridge _bridge;

  @override
  void initState() {
    super.initState();
    _viewType = 'divine-iframe-sandbox-${widget.app.id}';
    final childOrigin = Uri.parse(widget.app.launchUrl).origin;
    _bridge = WebIframeNostrBridge(
      allowedChildOrigin: childOrigin,
      authService: WebAuthService(),
    );
    if (kIsWeb) {
      _registerViewFactory();
      _bridge.start();
    }
  }

  void _registerViewFactory() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = widget.app.launchUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'clipboard-read; clipboard-write';
      // Wire the bridge's reply path to this specific iframe's contentWindow
      // so replies don't leak to other frames on the page.
      _bridge.postReplyOverride = (message, targetOrigin) {
        final target = iframe.contentWindow;
        if (target != null) {
          target.postMessage(message, targetOrigin);
        }
      };
      return iframe;
    });
  }

  @override
  void dispose() {
    _bridge.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: DiVineAppBar(
        title: widget.app.name,
        backgroundMode: DiVineAppBarBackgroundMode.transparent,
        showBackButton: true,
      ),
      body: kIsWeb
          ? HtmlElementView(viewType: _viewType)
          : const _UnsupportedPlatformMessage(),
    );
  }
}

class _UnsupportedPlatformMessage extends StatelessWidget {
  const _UnsupportedPlatformMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'This integrated app is only available on Flutter web.',
          textAlign: TextAlign.center,
          style: TextStyle(color: VineTheme.lightText),
        ),
      ),
    );
  }
}
