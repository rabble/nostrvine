// ABOUTME: Segmented toggle widget for Inbox screen (Messages/Notifications)
// ABOUTME: Pill-shaped container with active/inactive button states and badge

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A segmented toggle for switching between Messages and Notifications
/// in the Inbox screen.
///
/// Renders a pill-shaped container with two equal-width buttons.
/// The active button has a green background with dark text, while the
/// inactive button has no background with muted text.
class InboxTabToggle extends StatelessWidget {
  /// Creates an [InboxTabToggle].
  ///
  /// [selectedIndex] determines which tab is active:
  /// - 0 = Messages
  /// - 1 = Notifications
  ///
  /// [onChanged] is called when the user taps a tab.
  ///
  /// [notificationBadgeCount] optionally shows a red badge with the
  /// unread count on the Notifications button when Messages is active.
  const InboxTabToggle({
    required this.selectedIndex,
    required this.onChanged,
    this.notificationBadgeCount = 0,
    this.messagesBadgeCount = 0,
    super.key,
  });

  /// Which tab is currently selected (0 = Messages, 1 = Notifications).
  final int selectedIndex;

  /// Called when the user taps a tab button.
  final ValueChanged<int> onChanged;

  /// Number of unread notifications to display as a badge on the
  /// Notifications button. Only shown when Messages tab is active.
  final int notificationBadgeCount;

  /// Number of unread DM conversations to display as a badge on the
  /// Messages button. Only shown when Notifications tab is active.
  final int messagesBadgeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VineTheme.navGreen,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: _ToggleContainer(
        selectedIndex: selectedIndex,
        onChanged: onChanged,
        notificationBadgeCount: notificationBadgeCount,
        messagesBadgeCount: messagesBadgeCount,
      ),
    );
  }
}

class _ToggleContainer extends StatelessWidget {
  const _ToggleContainer({
    required this.selectedIndex,
    required this.onChanged,
    required this.notificationBadgeCount,
    required this.messagesBadgeCount,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final int notificationBadgeCount;
  final int messagesBadgeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VineTheme.outlineMuted, width: 2),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _BadgeToggleButton(
              label: 'Messages',
              isActive: selectedIndex == 0,
              badgeCount: messagesBadgeCount,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _BadgeToggleButton(
              label: 'Notifications',
              isActive: selectedIndex == 1,
              badgeCount: notificationBadgeCount,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeToggleButton extends StatelessWidget {
  const _BadgeToggleButton({
    required this.label,
    required this.isActive,
    required this.badgeCount,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label tab',
      button: true,
      selected: isActive,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? VineTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: VineTheme.titleMediumFont(
                  color: isActive
                      ? VineTheme.onPrimaryButton
                      : VineTheme.onSurfaceMuted,
                  fontSize: 16,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                _Badge(count: badgeCount),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final displayText = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: VineTheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        displayText,
        style: VineTheme.labelSmallFont(),
      ),
    );
  }
}
