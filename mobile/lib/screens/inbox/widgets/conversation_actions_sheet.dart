// ABOUTME: Bottom sheet with long-press actions for DM conversations.
// ABOUTME: Provides Mute, Report, Block, and Remove conversation actions.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Actions available from the conversation long-press sheet.
enum ConversationAction {
  /// Toggle mute notifications for this conversation.
  toggleMute,

  /// Report the other participant.
  report,

  /// Block the other participant.
  block,

  /// Remove (delete) the conversation locally.
  remove,
}

/// Shows a bottom sheet with contextual actions for a DM conversation.
///
/// Matches the Figma "conversation list - long press" design (node 10183:132451).
/// Returns the chosen [ConversationAction] or `null` if dismissed.
class ConversationActionsSheet {
  static Future<ConversationAction?> show(
    BuildContext context, {
    required String displayName,
    required bool isMuted,
  }) {
    return VineBottomSheet.show<ConversationAction>(
      context: context,
      scrollable: false,
      expanded: false,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MuteActionTile(
            isMuted: isMuted,
            onTap: () => context.pop(ConversationAction.toggleMute),
          ),
          _ActionTile(
            icon: DivineIconName.flag,
            label: 'Report $displayName',
            onTap: () => context.pop(ConversationAction.report),
          ),
          _ActionTile(
            icon: DivineIconName.eyeSlash,
            label: 'Block $displayName',
            isDestructive: true,
            onTap: () => context.pop(ConversationAction.block),
          ),
          _ActionTile(
            icon: DivineIconName.trash,
            label: 'Remove conversation',
            isDestructive: true,
            showDivider: false,
            onTap: () => context.pop(ConversationAction.remove),
          ),
        ],
      ),
    );
  }
}

class _MuteActionTile extends StatelessWidget {
  const _MuteActionTile({
    required this.isMuted,
    required this.onTap,
  });

  final bool isMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: VineTheme.outlineDisabled),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            spacing: 16,
            children: [
              const DivineIcon(
                icon: DivineIconName.bellSimple,
                color: VineTheme.onSurface,
              ),
              Expanded(
                child: Text(
                  'Mute conversation',
                  style: VineTheme.titleMediumFont(),
                ),
              ),
              _MuteSwitch(isMuted: isMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visual-only switch indicator matching Figma's Material 3 switch.
///
/// The actual toggle happens when the parent tile is tapped — this widget
/// only displays the current state.
class _MuteSwitch extends StatelessWidget {
  const _MuteSwitch({required this.isMuted});

  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 32,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isMuted ? VineTheme.primary : VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: isMuted ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: VineTheme.onSurface,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.showDivider = true,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? VineTheme.error : VineTheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: VineTheme.outlineDisabled),
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            spacing: 16,
            children: [
              DivineIcon(icon: icon, color: color),
              Expanded(
                child: Text(
                  label,
                  style: VineTheme.titleMediumFont(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
