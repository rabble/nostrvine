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
    this.isTrashFilterActive = false,
    this.onEmptyTrash,
    this.onManageActiveCategory,
    this.onMoveSelectedClips,
    this.onDeleteSelectedClips,
    super.key,
  });

  final bool isLibrarySelectionMode;
  final bool canExitSelectionMode;
  final bool isClipsTabActive;
  final VoidCallback onLeadingPressed;
  final VoidCallback onOpenSortMenu;
  final VoidCallback onEnterSelectionMode;

  /// Whether the clip grid is currently showing the trash bin. Sorting and
  /// selecting do not apply there, so those actions step aside.
  final bool isTrashFilterActive;

  /// Empties the trash. Null when the bin is empty or not being shown.
  final VoidCallback? onEmptyTrash;

  /// Renames or deletes the category the grid is filtered to. Null unless a
  /// user category is the active filter.
  final VoidCallback? onManageActiveCategory;

  /// Files the selected clips into a category. Null when nothing is selected.
  final VoidCallback? onMoveSelectedClips;

  final VoidCallback? onDeleteSelectedClips;

  @override
  Widget build(BuildContext context) {
    final showsSelectionExit =
        isClipsTabActive && isLibrarySelectionMode && canExitSelectionMode;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        spacing: 8,
        children: [
          DivineIconButton(
            size: .small,
            type: .secondary,
            icon: showsSelectionExit ? .x : .caretLeft,
            semanticLabel: showsSelectionExit
                ? context.l10n.libraryStopSelectingClipsSemanticLabel
                : context.l10n.libraryCloseSemanticLabel,
            onPressed: onLeadingPressed,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                context.l10n.profileMyLibraryLabel,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.primaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (isClipsTabActive) ...[
            if (isTrashFilterActive) ...[
              if (onEmptyTrash != null)
                DivineButton(
                  size: .small,
                  type: .error,
                  label: context.l10n.libraryTrashEmptyAllLabel,
                  onPressed: onEmptyTrash,
                ),
            ] else ...[
              if (!isLibrarySelectionMode && onManageActiveCategory != null)
                DivineIconButton(
                  size: .small,
                  type: .secondary,
                  icon: .pencilSimple,
                  semanticLabel:
                      context.l10n.libraryCategoryManageSemanticLabel,
                  onPressed: onManageActiveCategory,
                ),
              DivineIconButton(
                size: .small,
                type: .secondary,
                icon: .funnelSimple,
                // #7129 put the grid-size control in this same menu, so the
                // label names both jobs.
                semanticLabel:
                    '${context.l10n.librarySortClipsSemanticLabel}. '
                    '${context.l10n.libraryGridSizeLabel}',
                onPressed: onOpenSortMenu,
              ),
              if (!isLibrarySelectionMode)
                DivineButton(
                  size: .small,
                  type: .secondary,
                  label: context.l10n.librarySelect,
                  semanticLabel: context.l10n.librarySelectClipsSemanticLabel,
                  onPressed: onEnterSelectionMode,
                ),
              if (isLibrarySelectionMode) ...[
                DivineIconButton(
                  size: .small,
                  type: .secondary,
                  icon: .folderOpen,
                  semanticLabel: context.l10n.libraryMoveSelectedClipsTooltip,
                  onPressed: onMoveSelectedClips,
                ),
                DivineIconButton(
                  size: .small,
                  type: .error,
                  icon: .trash,
                  semanticLabel: context.l10n.libraryDeleteSelectedClipsTooltip,
                  onPressed: onDeleteSelectedClips,
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
