// ABOUTME: Confirmation view for blocking a user
// ABOUTME: Shows explanation and cancel/block buttons

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bullet_point.dart';

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
    return Column(
      key: const ValueKey('confirmation'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Block $displayName?',
              style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
            ),
          ),
        ),
        // Explanation content
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'When you block a user:',
                style: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              const BulletPoint('Their posts will not appear in your feeds.'),
              const BulletPoint(
                'They will be unable to view your profile, follow you, or view your posts.',
              ),
              const BulletPoint('They will not be notified of this change.'),
              const BulletPoint(
                'You will still be able to view their profile.',
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () =>
                    launchUrl(Uri.parse('https://divine.video/safety')),
                child: Text.rich(
                  TextSpan(
                    text: 'Learn more at ',
                    style: VineTheme.bodyLargeFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(
                        text: 'divine.video/safety',
                        style:
                            VineTheme.bodyLargeFont(
                              color: VineTheme.onSurface,
                            ).copyWith(
                              decoration: TextDecoration.underline,
                              decorationColor: VineTheme.vineGreen,
                              decorationThickness: 2,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Button row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              // Cancel button
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: VineTheme.surfaceContainer,
                    foregroundColor: VineTheme.vineGreen,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    side: const BorderSide(
                      color: VineTheme.outlineMuted,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: VineTheme.titleMediumFont(
                      color: VineTheme.vineGreen,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Block button
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.error,
                    foregroundColor: VineTheme.onErrorContainer,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Block',
                    style: VineTheme.titleMediumFont(
                      color: VineTheme.onErrorContainer,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
