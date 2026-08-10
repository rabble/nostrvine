// ABOUTME: Explains compact profile badges that appear beside display names.
// ABOUTME: Keeps profile-badge copy separate from video verification modals.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

enum ProfileBadgeExplanationType { ogViner, profileCheckmark }

/// Opens the explainer for a compact profile badge.
///
/// This is only for profile-header actions, where the caller is on a full route
/// rather than inside an existing bottom sheet. Inline name-row badges stay
/// non-interactive because their visual box is intentionally smaller than a
/// 48 dp touch target and many of those rows already navigate to the profile.
Future<void> showProfileBadgeExplanationSheet(
  BuildContext context,
  ProfileBadgeExplanationType type,
) {
  return context.showVideoPausingVineBottomSheet<void>(
    scrollable: false,
    expanded: false,
    contentTitle: type.title(context.l10n),
    children: [_ProfileBadgeExplanationContent(type: type)],
  );
}

class _ProfileBadgeExplanationContent extends StatelessWidget {
  const _ProfileBadgeExplanationContent({required this.type});

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
      ProfileBadgeExplanationType.ogViner => l10n.ogVinerBadgeLabel,
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
