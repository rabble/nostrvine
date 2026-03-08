// ABOUTME: Screen displayed when viewing a blocked or unavailable user's profile
// ABOUTME: Shows a simple message with back navigation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

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
      body: const Center(
        child: Text(
          'This account is not available',
          style: TextStyle(color: VineTheme.lightText, fontSize: 16),
        ),
      ),
    );
  }
}
