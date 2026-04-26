// ABOUTME: Bottom sheet with long-press actions for DM conversations.
// ABOUTME: Provides Mute, Report, Block, and Remove conversation actions.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

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
    required bool isBlocked,
  }) {
    return VineBottomSheet.show<ConversationAction>(
      context: context,
      scrollable: false,
      expanded: false,
      body: Semantics(
        label: 'Conversation actions',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MuteActionTile(isMuted: isMuted),
            _ActionTile(
              icon: DivineIconName.flag,
              label: context.l10n.inboxActionReport(displayName),
              result: ConversationAction.report,
            ),
            _ActionTile(
              icon: DivineIconName.eyeSlash,
              label: isBlocked
                  ? context.l10n.inboxActionUnblock(displayName)
                  : context.l10n.inboxActionBlock(displayName),
              isDestructive: !isBlocked,
              result: ConversationAction.block,
            ),
            _ActionTile(
              icon: DivineIconName.trash,
              label: context.l10n.inboxActionRemove,
              isDestructive: true,
              showDivider: false,
              result: ConversationAction.remove,
            ),
          ],
        ),
      ),
    );
  }
}

class _MuteActionTile extends StatelessWidget {
  const _MuteActionTile({required this.isMuted});

  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: isMuted,
      label: context.l10n.inboxActionMute,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: VineTheme.outlineDisabled)),
        ),
        child: SwitchListTile(
          value: isMuted,
          activeThumbColor: VineTheme.whiteText,
          activeTrackColor: VineTheme.primary,
          inactiveThumbColor: VineTheme.onSurfaceDisabled,
          inactiveTrackColor: VineTheme.surfaceContainer,
          onChanged: (_) =>
              Navigator.of(context).pop(ConversationAction.toggleMute),
          title: Text(
            context.l10n.inboxActionMute,
            style: VineTheme.titleMediumFont(),
          ),
          secondary: const DivineIcon(
            icon: DivineIconName.bellSimple,
            color: VineTheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.result,
    this.isDestructive = false,
    this.showDivider = true,
  });

  final DivineIconName icon;
  final String label;
  final ConversationAction result;
  final bool isDestructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? VineTheme.error : VineTheme.onSurface;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(result),
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
      ),
    );
  }
}
