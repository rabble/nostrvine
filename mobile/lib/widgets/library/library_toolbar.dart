// ABOUTME: Toolbar for the library screen with navigation and clip actions
// ABOUTME: Keeps library header actions separate from LibraryScreen wiring

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

class LibraryToolbar extends StatelessWidget {
  const LibraryToolbar({
    required this.isLibrarySelectionMode,
    required this.canExitSelectionMode,
    required this.isClipsTabActive,
    required this.onLeadingPressed,
    required this.onOpenSortMenu,
    required this.onEnterSelectionMode,
    required this.onOpenTrash,
    this.onDeleteSelectedClips,
    super.key,
  });

  final bool isLibrarySelectionMode;
  final bool canExitSelectionMode;
  final bool isClipsTabActive;
  final VoidCallback onLeadingPressed;
  final VoidCallback onOpenSortMenu;
  final VoidCallback onEnterSelectionMode;
  final VoidCallback onOpenTrash;
  final VoidCallback? onDeleteSelectedClips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        spacing: 8,
        children: [
          DivineIconButton(
            size: .small,
            type: .secondary,
            icon: isLibrarySelectionMode ? .x : .caretLeft,
            semanticLabel: isLibrarySelectionMode && canExitSelectionMode
                ? context.l10n.commonCancel
                : null,
            onPressed: onLeadingPressed,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                context.l10n.profileMyLibraryLabel,
                style: VineTheme.titleMediumFont(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (isClipsTabActive) ...[
            if (!isLibrarySelectionMode)
              DivineIconButton(
                size: .small,
                type: .secondary,
                icon: .trash,
                semanticLabel: context.l10n.libraryTrashEntryLabel,
                onPressed: onOpenTrash,
              ),
            DivineIconButton(
              size: .small,
              type: .secondary,
              icon: .funnelSimple,
              onPressed: onOpenSortMenu,
            ),
            if (!isLibrarySelectionMode)
              DivineButton(
                size: .small,
                type: .secondary,
                label: context.l10n.librarySelect,
                onPressed: onEnterSelectionMode,
              ),
            if (isLibrarySelectionMode)
              DivineIconButton(
                size: .small,
                type: .error,
                icon: .trash,
                semanticLabel: context.l10n.commonDelete,
                onPressed: onDeleteSelectedClips,
              ),
          ],
        ],
      ),
    );
  }
}
