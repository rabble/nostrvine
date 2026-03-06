// ABOUTME: Confirmation view for unblocking a user
// ABOUTME: Shows explanation and cancel/unblock buttons

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/profile/more_sheet/bullet_point.dart';
import 'package:url_launcher/url_launcher.dart';

/// Confirmation view for unblocking a user.
class UnblockConfirmationView extends StatelessWidget {
  /// Creates an unblock confirmation view.
  const UnblockConfirmationView({
    required this.displayName,
    required this.onCancel,
    required this.onConfirm,
    super.key,
  });

  /// The display name of the user to unblock.
  final String displayName;

  /// Called when the cancel button is pressed.
  final VoidCallback onCancel;

  /// Called when the unblock button is pressed.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        key: const ValueKey('unblock_confirmation'),
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            'Unblock $displayName?',
            style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
          ),
          const SizedBox(height: 16),
          // Explanation content
          Text(
            'When you unblock this user:',
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          const Column(
            spacing: 14,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BulletPoint('Their posts will appear in your feeds.'),
              BulletPoint(
                'They will be able to view your profile, follow you, and view your posts.',
              ),
              BulletPoint('They will not be notified of this change.'),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://divine.video/safety')),
            child: Text.rich(
              TextSpan(
                text: 'Learn more at ',
                style: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: 'divine.video/safety',
                    style: VineTheme.bodyLargeFont(color: VineTheme.onSurface)
                        .copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: VineTheme.vineGreen,
                          decorationThickness: 2,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Button row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              spacing: 16,
              children: [
                Expanded(
                  child: DivineButton(
                    label: 'Cancel',
                    onPressed: onCancel,
                    type: DivineButtonType.secondary,
                  ),
                ),
                Expanded(
                  child: DivineButton(
                    label: 'Unblock',
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
