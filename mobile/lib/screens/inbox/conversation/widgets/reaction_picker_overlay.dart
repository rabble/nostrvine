// ABOUTME: Combined long-press overlay for a DM bubble: quick reaction
// ABOUTME: row above the message actions. Single gesture, single surface.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_actions_sheet.dart';

/// Default emoji set for the quick-row. Excludes 🙏 per user-memory
/// rule "Swap 🙏 → 🫶 always" — 🔥 takes its place because it reads
/// especially well on short-form video content.
const List<String> kDefaultDmReactionEmojis = [
  '❤️',
  '😂',
  '🔥',
  '😮',
  '😢',
  '👍',
];

/// Outcome of a [ReactionPickerOverlay] dismissal.
class ReactionPickerResult {
  /// Construct an outcome.
  const ReactionPickerResult({
    this.emoji,
    this.openFullPicker = false,
    this.action,
  });

  /// Emoji the user selected from the quick row. `null` when the user
  /// instead chose an action or tapped the "+" expander.
  final String? emoji;

  /// The user tapped "+" to open the full picker. The caller is
  /// responsible for opening the picker; this overlay is dismissed.
  final bool openFullPicker;

  /// The user selected one of the carry-over actions (Copy, Delete, etc.).
  final MessageAction? action;
}

/// Shows the combined picker + actions overlay anchored on screen.
///
/// Returns a [ReactionPickerResult] describing the user's choice, or
/// `null` if dismissed without selection.
class ReactionPickerOverlay {
  /// Show the overlay and await user selection. Triggers a medium
  /// haptic on open.
  static Future<ReactionPickerResult?> show({
    required BuildContext context,
    required bool isSent,
    bool showPicker = true,
    bool isVideoShare = false,
    List<String> emojis = kDefaultDmReactionEmojis,
  }) async {
    unawaited(HapticFeedback.mediumImpact());
    final l10n = context.l10n;

    return showModalBottomSheet<ReactionPickerResult>(
      context: context,
      backgroundColor: VineTheme.surfaceBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(VineTheme.bottomSheetBorderRadius),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showPicker)
                  _QuickRow(
                    emojis: emojis,
                    openLabel: l10n.dmReactionAddCustomA11yLabel,
                    onEmojiTap: (emoji) => Navigator.of(sheetContext).pop(
                      ReactionPickerResult(emoji: emoji),
                    ),
                    onMoreTap: () => Navigator.of(sheetContext).pop(
                      const ReactionPickerResult(openFullPicker: true),
                    ),
                  ),
                if (showPicker) const SizedBox(height: 8),
                _ActionList(
                  isSent: isSent,
                  isVideoShare: isVideoShare,
                  onSelected: (action) => Navigator.of(sheetContext).pop(
                    ReactionPickerResult(action: action),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({
    required this.emojis,
    required this.openLabel,
    required this.onEmojiTap,
    required this.onMoreTap,
  });

  final List<String> emojis;
  final String openLabel;
  final ValueChanged<String> onEmojiTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final emoji in emojis)
            _EmojiButton(
              emoji: emoji,
              onTap: () => onEmojiTap(emoji),
            ),
          _MoreButton(label: openLabel, onTap: onMoreTap),
        ],
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: emoji,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        child: Material(
          color: VineTheme.iconButtonBackground,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: DivineIcon(
                icon: DivineIconName.plus,
                color: VineTheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionList extends StatelessWidget {
  const _ActionList({
    required this.isSent,
    required this.isVideoShare,
    required this.onSelected,
  });

  final bool isSent;
  final bool isVideoShare;
  final ValueChanged<MessageAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tiles = <Widget>[
      _ActionTile(
        icon: Icons.copy,
        label: l10n.dmMessageActionCopyText,
        onTap: () => onSelected(MessageAction.copy),
      ),
      if (isVideoShare)
        _ActionTile(
          icon: Icons.link,
          label: l10n.dmMessageActionCopyVideoUrl,
          onTap: () => onSelected(MessageAction.copyVideoUrl),
        ),
      if (isSent)
        _ActionTile(
          icon: Icons.delete_outline,
          label: l10n.dmMessageActionDeleteForEveryone,
          onTap: () => onSelected(MessageAction.delete),
          color: VineTheme.error,
        ),
      if (!isSent)
        _ActionTile(
          icon: Icons.flag_outlined,
          label: l10n.dmMessageActionReport,
          onTap: () => onSelected(MessageAction.report),
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: tiles,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? VineTheme.onSurface),
      title: Text(
        label,
        style: VineTheme.bodyLargeFont(
          color: color ?? VineTheme.onSurface,
        ),
      ),
      onTap: onTap,
    );
  }
}
