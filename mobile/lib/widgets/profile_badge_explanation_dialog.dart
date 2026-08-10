// ABOUTME: Explains compact profile badges that appear beside display names.
// ABOUTME: Keeps profile-badge copy separate from video verification modals.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

enum ProfileBadgeExplanationType { ogViner, profileCheckmark }

/// Opens the explainer for a compact profile badge.
///
/// Uses [showVideoPausingVineBottomSheet] because both badges also render
/// inside the video feed, over a playing video: the pause-aware wrapper is
/// what flips `OverlayVisibility.setBottomSheetOpen`, and without it the
/// video keeps playing behind the sheet. It also defaults `useRootNavigator`
/// to true, so the sheet covers the shell's tab bar instead of opening
/// underneath it.
Future<void> showProfileBadgeExplanationDialog(
  BuildContext context,
  ProfileBadgeExplanationType type,
) {
  return context.showVideoPausingVineBottomSheet<void>(
    scrollable: false,
    expanded: false,
    contentTitle: type.title(context.l10n),
    children: [ProfileBadgeExplanationContent(type: type)],
  );
}

class ProfileBadgeExplanationContent extends StatelessWidget {
  const ProfileBadgeExplanationContent({required this.type, super.key});

  final ProfileBadgeExplanationType type;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DivineIcon(icon: type.icon, color: type.iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  type.body(l10n),
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: DivineButton(
              label: l10n.commonClose,
              onPressed: () => Navigator.of(context).pop(),
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
            ),
          ),
        ],
      ),
    );
  }
}

extension on ProfileBadgeExplanationType {
  String title(AppLocalizations l10n) {
    return switch (this) {
      ProfileBadgeExplanationType.ogViner => l10n.profileBadgeOgVinerTitle,
      ProfileBadgeExplanationType.profileCheckmark =>
        l10n.profileBadgeCheckmarkTitle,
    };
  }

  String body(AppLocalizations l10n) {
    return switch (this) {
      ProfileBadgeExplanationType.ogViner => l10n.profileBadgeOgVinerBody,
      ProfileBadgeExplanationType.profileCheckmark =>
        l10n.profileBadgeCheckmarkBody,
    };
  }

  DivineIconName get icon {
    return switch (this) {
      ProfileBadgeExplanationType.ogViner => DivineIconName.videoCamera,
      ProfileBadgeExplanationType.profileCheckmark => DivineIconName.check,
    };
  }

  Color get iconColor {
    return switch (this) {
      ProfileBadgeExplanationType.ogViner => VineTheme.primary,
      ProfileBadgeExplanationType.profileCheckmark => VineTheme.info,
    };
  }
}
