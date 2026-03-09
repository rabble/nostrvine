// ABOUTME: Confirmation view for blocking a user
// ABOUTME: Shows explanation and cancel/block buttons

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/profile/more_sheet/bullet_point.dart';
import 'package:url_launcher/url_launcher.dart';

/// Confirmation view for blocking a user.
class BlockConfirmationView extends StatelessWidget {
  /// Creates a block confirmation view.
  const BlockConfirmationView({
    required this.displayName,
    required this.onCancel,
    required this.onConfirm,
    super.key,
  });

  /// The display name of the user to block.
  final String displayName;

  /// Called when the cancel button is pressed.
  final VoidCallback onCancel;

  /// Called when the block button is pressed.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        key: const ValueKey('confirmation'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const DivineSticker(sticker: DivineStickerName.blocked),
          const SizedBox(height: 32),
          // Title
          Text(
            'Block $displayName?',
            style: VineTheme.titleLargeFont(color: VineTheme.onSurface),
          ),
          const SizedBox(height: 8),
          // Explanation content
          Text(
            'When you block a user:',
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              spacing: 14,
              children: [
                BulletPoint('Their posts will not appear in your feeds.'),
                BulletPoint(
                  'They will be unable to view your profile, follow you, or view your posts.',
                ),
                BulletPoint('They will not be notified of this change.'),
                BulletPoint(
                  'You will still be able to view their profile.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Button row
          Column(
            spacing: 16,
            children: [
              DivineButton(
                label: 'Block $displayName',
                onPressed: onConfirm,
                expanded: true,
                type: DivineButtonType.error,
              ),
              DivineButton(
                label: 'Cancel',
                type: DivineButtonType.secondary,
                onPressed: onCancel,
                expanded: true,
              ),
              DivineButton(
                label: 'Learn More',
                type: DivineButtonType.link,
                onPressed: () =>
                    launchUrl(Uri.parse('https://divine.video/safety')),
                expanded: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
