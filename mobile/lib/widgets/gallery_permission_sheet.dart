// ABOUTME: Bottom sheet shown when gallery/camera-roll permission is denied.
// ABOUTME: Offers to open system settings or skip gallery saves permanently.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/divine_primary_button.dart';
import 'package:openvine/widgets/divine_secondary_button.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key that, when `true`, suppresses the gallery-permission
/// sheet and silently skips gallery saves.
const _kGalleryPermissionDismissedKey = 'gallery_permission_dismissed_forever';

/// Result of showing the gallery-permission bottom sheet.
enum GalleryPermissionChoice {
  /// User tapped "Open Settings" and may have granted permission.
  openedSettings,

  /// User tapped "Don't Ask Again" — skip gallery saves from now on.
  dismissedForever,

  /// User tapped "Not Now" or swiped away — skip this time only.
  skipped,
}

/// Returns `true` when the user has previously chosen "Don't Ask Again".
Future<bool> isGalleryPermissionDismissedForever() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kGalleryPermissionDismissedKey) ?? false;
}

/// Shows a bottom sheet explaining that gallery permission is needed.
///
/// Returns a [GalleryPermissionChoice] describing the user's decision.
/// If the user chose [GalleryPermissionChoice.openedSettings] and
/// subsequently granted access, the caller should retry the save.
Future<GalleryPermissionChoice> showGalleryPermissionSheet(
  BuildContext context, {
  required PermissionsService permissionsService,
}) async {
  final destination = GallerySaveService.destinationName;

  final result = await VineBottomSheet.show<GalleryPermissionChoice>(
    context: context,
    scrollable: false,
    children: [
      _GalleryPermissionSheetContent(
        destination: destination,
        onOpenSettings: () async {
          await permissionsService.openAppSettings();
          if (context.mounted) {
            Navigator.of(
              context,
            ).pop(GalleryPermissionChoice.openedSettings);
          }
        },
        onDismissForever: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_kGalleryPermissionDismissedKey, true);
          if (context.mounted) {
            Navigator.of(
              context,
            ).pop(GalleryPermissionChoice.dismissedForever);
          }
        },
        onSkip: () {
          Navigator.of(context).pop(GalleryPermissionChoice.skipped);
        },
      ),
    ],
  );

  return result ?? GalleryPermissionChoice.skipped;
}

class _GalleryPermissionSheetContent extends StatelessWidget {
  const _GalleryPermissionSheetContent({
    required this.destination,
    required this.onOpenSettings,
    required this.onDismissForever,
    required this.onSkip,
  });

  final String destination;
  final VoidCallback onOpenSettings;
  final VoidCallback onDismissForever;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const DivineSticker(
            sticker: DivineStickerName.alert,
            size: 96,
          ),

          const SizedBox(height: 16),
          Text(
            // TODO(l10n): Replace with context.l10n when localization
            // is added.
            '$destination Access Needed',
            style: VineTheme.headlineSmallFont(),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),
          Text(
            // TODO(l10n): Replace with context.l10n when localization
            // is added.
            'To save a copy of your videos, allow '
            '$destination access in Settings.',
            style: VineTheme.bodyLargeFont(
              color: VineTheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),
          DivinePrimaryButton(
            // TODO(l10n): Replace with context.l10n when localization
            // is added.
            label: 'Open Settings',
            onPressed: onOpenSettings,
          ),

          const SizedBox(height: 16),
          DivineSecondaryButton(
            // TODO(l10n): Replace with context.l10n when localization
            // is added.
            label: 'Not Now',
            onPressed: onSkip,
          ),

          const SizedBox(height: 12),
          TextButton(
            onPressed: onDismissForever,
            child: Text(
              // TODO(l10n): Replace with context.l10n when localization
              // is added.
              "Don't Ask Again",
              style: VineTheme.labelLargeFont(
                color: VineTheme.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
