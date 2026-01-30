// ABOUTME: Shared unfollow confirmation bottom sheet used across the app
// ABOUTME: Shows Cancel/Unfollow buttons and returns true if user confirms

import 'package:flutter/material.dart';
import 'package:divine_ui/divine_ui.dart';

/// Shows a confirmation bottom sheet for unfollowing a user.
///
/// Returns `true` if the user confirmed the unfollow, `false` or `null`
/// if cancelled (including tapping outside the sheet).
Future<bool?> showUnfollowConfirmation(
  BuildContext context, {
  required String displayName,
}) {
  return VineBottomSheet.show<bool>(
    context: context,
    scrollable: false,
    contentTitle: 'Unfollow $displayName?',
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
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
                  style: VineTheme.titleMediumFont(color: VineTheme.vineGreen),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: VineTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Unfollow',
                  style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
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
