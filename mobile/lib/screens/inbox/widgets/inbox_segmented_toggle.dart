// ABOUTME: Messages/Notifications segmented toggle for the inbox screen.
// ABOUTME: Matches the Figma design with primary green active state,
// ABOUTME: muted inactive state, and a notification badge on the left tab.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// The two tabs available in the inbox segmented toggle.
enum InboxTab { messages, notifications }

/// A segmented toggle that switches between Messages and Notifications.
///
/// Matches the Figma design: rounded container with `surfaceContainer` bg,
/// `outlineMuted` 2px border, 20px radius. Active segment uses `primary` bg
/// with `onPrimaryButton` text; inactive uses `onSurfaceMuted` text.
class InboxSegmentedToggle extends StatelessWidget {
  const InboxSegmentedToggle({
    required this.selected,
    required this.onChanged,
    this.notificationCount = 0,
    super.key,
  });

  final InboxTab selected;
  final ValueChanged<InboxTab> onChanged;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        border: Border.all(color: VineTheme.outlineMuted, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: 'Notifications',
              isSelected: selected == InboxTab.notifications,
              onTap: () => onChanged(InboxTab.notifications),
              badgeCount: notificationCount,
            ),
          ),
          Expanded(
            child: _ToggleButton(
              label: 'Messages',
              isSelected: selected == InboxTab.messages,
              onTap: () => onChanged(InboxTab.messages),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? VineTheme.primary : VineTheme.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: VineTheme.innerShadow,
                        blurRadius: 1,
                        offset: Offset(1, 1),
                      ),
                      BoxShadow(
                        color: VineTheme.innerShadow,
                        blurRadius: 0.6,
                        offset: Offset(0.4, 0.4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    label,
                    style: VineTheme.titleMediumFont(
                      color: isSelected
                          ? VineTheme.onPrimaryButton
                          : VineTheme.onSurfaceMuted,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -24,
                      child: _NotificationBadge(count: badgeCount),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: VineTheme.error,
        borderRadius: BorderRadius.all(Radius.circular(1000)),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: VineTheme.labelSmallFont(),
      ),
    );
  }
}
