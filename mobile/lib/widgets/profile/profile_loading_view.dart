// ABOUTME: Loading state widget for profile screens
// ABOUTME: Shows animated loading indicator with helpful message

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Loading view displayed while profile data is being fetched.
class ProfileLoadingView extends StatelessWidget {
  const ProfileLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(color: VineTheme.vineGreen),
          SizedBox(height: 24),
          Text(
            'Loading profile...',
            style: TextStyle(
              color: VineTheme.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
