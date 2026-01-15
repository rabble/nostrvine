// ABOUTME: Confirmation dialog shown after successfully blocking a user
// ABOUTME: Displays block success message with link to safety information

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Confirmation dialog shown after successfully blocking a user
class ProfileBlockConfirmationDialog extends StatelessWidget {
  const ProfileBlockConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: Row(
      children: [
        Icon(Icons.check_circle, color: VineTheme.vineGreen, size: 28),
        const SizedBox(width: 12),
        const Text(
          'User Blocked',
          style: TextStyle(color: VineTheme.whiteText),
        ),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'You won\'t see content from this user in your feeds.',
          style: TextStyle(color: VineTheme.whiteText, fontSize: 16),
        ),
        const SizedBox(height: 16),
        const Text(
          'You can unblock them anytime from their profile or in Settings > Safety.',
          style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: () async {
            final uri = Uri.parse('https://divine.video/safety');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VineTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VineTheme.vineGreen),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: VineTheme.vineGreen, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Learn More',
                        style: TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'divine.video/safety',
                        style: TextStyle(
                          color: VineTheme.vineGreen,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, color: VineTheme.vineGreen, size: 18),
              ],
            ),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: context.pop,
        child: Text('Close', style: TextStyle(color: VineTheme.vineGreen)),
      ),
    ],
  );
}
