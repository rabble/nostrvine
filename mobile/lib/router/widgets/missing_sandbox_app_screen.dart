// ABOUTME: Fallback screen shown when a sandbox app ID cannot be
// ABOUTME: resolved from the approved-integrations directory.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MissingSandboxAppScreen extends StatelessWidget {
  const MissingSandboxAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: 'Integration unavailable',
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Open approved integrations from the '
            'Integrated Apps tab so Divine can '
            'apply the right access policy.',
            textAlign: TextAlign.center,
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
