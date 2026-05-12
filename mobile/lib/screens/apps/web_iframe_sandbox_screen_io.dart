// ABOUTME: Native-platform stub for the web iframe sandbox screen.
// ABOUTME: Conditional import keeps dart:html / dart:ui_web off non-web builds.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';

class WebIframeSandboxScreen extends StatelessWidget {
  const WebIframeSandboxScreen({required this.app, super.key});

  static const String routeName = 'web-iframe-sandbox';
  static const String path = '/apps/:appId/web-sandbox';

  static String pathForAppId(String appId) =>
      '/apps/${Uri.encodeComponent(appId)}/web-sandbox';

  final NostrAppDirectoryEntry app;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      body: Center(
        child: Text(
          'WebIframeSandboxScreen is web-only',
          style: TextStyle(color: VineTheme.lightText),
        ),
      ),
    );
  }
}
