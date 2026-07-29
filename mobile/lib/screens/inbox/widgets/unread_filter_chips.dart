// ABOUTME: All/Unread filter chip row for the inbox Messages tab.
// ABOUTME: Lets the user narrow the conversation list to unread threads.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

/// Filter chip row shown above the conversation list.
///
/// [unreadOnly] selects the active chip; tapping the inactive chip calls
/// [onUnreadOnlyChanged] with the new value. Tapping the already-active
/// chip is a no-op.
class UnreadFilterChips extends StatelessWidget {
  const UnreadFilterChips({
    required this.unreadOnly,
    required this.onUnreadOnlyChanged,
    super.key,
  });

  /// Whether the Unread chip is currently selected.
  final bool unreadOnly;

  /// Called with the new filter value when the selection changes.
  final ValueChanged<bool> onUnreadOnlyChanged;

  @override
  Widget build(BuildContext context) {
    // Deliberately no MediaQuery.withNoTextScaling: these are controls to read
    // and tap, not fixed overlay badges. The pinned header hosting this row
    // declares a text-scale-aware extent so the row has room to grow into.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        spacing: 8,
        children: [
          _FilterChip(
            label: context.l10n.inboxFilterAll,
            selected: !unreadOnly,
            onTap: () => onUnreadOnlyChanged(false),
          ),
          _FilterChip(
            label: context.l10n.inboxFilterUnread,
            selected: unreadOnly,
            onTap: () => onUnreadOnlyChanged(true),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // onPressed stays non-null on the selected chip so it keeps the enabled
    // visual style; the parent ignores redundant selections.
    return Semantics(
      selected: selected,
      child: DivineButton(
        label: label,
        type: selected
            ? DivineButtonType.secondary
            : DivineButtonType.ghostSecondary,
        size: DivineButtonSize.tiny,
        onPressed: onTap,
      ),
    );
  }
}
