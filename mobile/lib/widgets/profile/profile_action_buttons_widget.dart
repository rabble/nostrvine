// ABOUTME: Action buttons widget for profile page (edit, library, follow)
// ABOUTME: Shows different buttons for own profile vs other user profiles

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/widgets/profile/follow_from_profile_button.dart';

/// Action buttons shown on profile page
/// Different buttons shown for own profile vs other user profiles
class ProfileActionButtons extends StatelessWidget {
  const ProfileActionButtons({
    required this.userIdHex,
    required this.isOwnProfile,
    this.displayName,
    this.onEditProfile,
    this.onOpenClips,
    this.onOpenAnalytics,
    this.onBlockedTap,
    super.key,
  });

  final String userIdHex;
  final bool isOwnProfile;

  /// Display name for unfollow confirmation (required when not own profile).
  final String? displayName;
  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenClips;
  final VoidCallback? onOpenAnalytics;

  /// Callback when the Blocked button is tapped.
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    child: Row(
      children: [
        if (isOwnProfile) ...[
          Expanded(
            child: ElevatedButton(
              onPressed: onEditProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icon/content-controls/pencil.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      VineTheme.onPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Edit',
                      style: VineTheme.titleMediumFont(
                        color: VineTheme.onPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              key: const Key('library-button'),
              onPressed: onOpenClips,
              style: OutlinedButton.styleFrom(
                backgroundColor: VineTheme.surfaceContainer,
                foregroundColor: VineTheme.vineGreen,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                side: const BorderSide(color: VineTheme.outlineMuted, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icon/FilmSlate.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      VineTheme.vineGreen,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Library',
                      style: VineTheme.titleMediumFont(
                        color: VineTheme.vineGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            height: 48,
            child: OutlinedButton(
              onPressed: onOpenAnalytics,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: VineTheme.surfaceContainer,
                foregroundColor: VineTheme.whiteText,
                side: const BorderSide(color: VineTheme.outlineMuted, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Icon(Icons.analytics_outlined, size: 20),
            ),
          ),
        ] else ...[
          Expanded(
            child: FollowFromProfileButton(
              pubkey: userIdHex,
              displayName: displayName ?? 'user',
              onBlockedTap: onBlockedTap,
            ),
          ),
        ],
      ],
    ),
  );
}
