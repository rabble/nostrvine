// ABOUTME: Screen displayed when viewing a blocked or unavailable user's profile
// ABOUTME: Shows a simple message with back navigation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

/// Screen shown when viewing a blocked or unavailable user's profile.
class BlockedUserScreen extends StatelessWidget {
  const BlockedUserScreen({required this.onBack, super.key});

  /// Callback when back button is pressed.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: '',
        showBackButton: true,
        onBackPressed: onBack,
        backgroundMode: DiVineAppBarBackgroundMode.transparent,
      ),
      body: Center(
        child: Text(
          context.l10n.profileBlockedAccountNotAvailable,
          style: const TextStyle(color: VineTheme.lightText, fontSize: 16),
        ),
      ),
    );
  }
}
