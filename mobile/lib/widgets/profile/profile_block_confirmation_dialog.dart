// ABOUTME: Confirmation dialog shown after successfully blocking a user
// ABOUTME: Displays block success message with link to safety information

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Confirmation dialog shown after successfully blocking a user
class ProfileBlockConfirmationDialog extends StatelessWidget {
  const ProfileBlockConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: Row(
      children: [
        const Icon(Icons.check_circle, color: VineTheme.vineGreen, size: 28),
        const SizedBox(width: 12),
        Text(
          context.l10n.profileUserBlockedTitle,
          style: const TextStyle(color: VineTheme.whiteText),
        ),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.profileUserBlockedContent,
          style: const TextStyle(color: VineTheme.whiteText, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.profileUserBlockedUnblockHint,
          style: const TextStyle(color: VineTheme.secondaryText, fontSize: 14),
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
                const Icon(
                  Icons.info_outline,
                  color: VineTheme.vineGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.profileLearnMore,
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'divine.video/safety',
                        style: TextStyle(
                          color: VineTheme.vineGreen,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.open_in_new,
                  color: VineTheme.vineGreen,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: context.pop,
        child: Text(
          context.l10n.profileCloseButton,
          style: const TextStyle(color: VineTheme.vineGreen),
        ),
      ),
    ],
  );
}
