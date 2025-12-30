// ABOUTME: Screen displayed when viewing a blocked or unavailable user's profile
// ABOUTME: Shows a simple message with back navigation

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Screen shown when viewing a blocked or unavailable user's profile.
class BlockedUserScreen extends StatelessWidget {
  const BlockedUserScreen({required this.onBack, super.key});

  /// Callback when back button is pressed.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBack,
        ),
      ),
      body: const Center(
        child: Text(
          'This account is not available',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ),
    );
  }
}
