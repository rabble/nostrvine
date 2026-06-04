// ABOUTME: Fallback screen shown when a sandbox app ID cannot be
// ABOUTME: resolved from the approved-integrations directory.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';

class MissingSandboxAppScreen extends StatelessWidget {
  const MissingSandboxAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.appsSandboxUnavailableTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.appsSandboxUnavailableBody,
            textAlign: TextAlign.center,
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
