// ABOUTME: Empty conversation state showing participant profile card.
// ABOUTME: Matches Figma "new message" component with avatar, name, NIP-05,
// ABOUTME: and "View profile" button.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Profile card shown when a conversation has no messages yet.
///
/// Displays a large avatar, display name, optional NIP-05 identifier,
/// and a "View profile" button.
class EmptyConversation extends StatelessWidget {
  const EmptyConversation({
    required this.displayName,
    this.imageUrl,
    this.nip05,
    this.onViewProfile,
    super.key,
  });

  final String displayName;
  final String? imageUrl;
  final String? nip05;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
      child: Column(
        children: [
          // Avatar
          UserAvatar(imageUrl: imageUrl, name: displayName, size: 96),
          const SizedBox(height: 32),
          // User info
          Text(
            displayName,
            style: VineTheme.titleLargeFont(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (nip05 != null && nip05!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              nip05!,
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          // View profile button
          _ViewProfileButton(onTap: onViewProfile),
        ],
      ),
    );
  }
}

class _ViewProfileButton extends StatelessWidget {
  const _ViewProfileButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          border: Border.all(color: VineTheme.outlineMuted, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'View profile',
          style: VineTheme.titleMediumFont(color: VineTheme.primary),
        ),
      ),
    );
  }
}
