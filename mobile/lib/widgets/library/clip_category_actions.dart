// ABOUTME: Bottom sheets for creating, renaming, and assigning clip categories.
// ABOUTME: Returns the user's choice; dispatching events is the caller's job.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_category.dart';

/// Where the user wants the selected clips filed.
sealed class ClipCategoryMoveChoice {
  const ClipCategoryMoveChoice();
}

/// File the clips under an existing category.
final class ClipCategoryMoveToExisting extends ClipCategoryMoveChoice {
  const ClipCategoryMoveToExisting(this.categoryId);

  /// The target category.
  final String categoryId;
}

/// Take the clips out of whatever category they are in.
final class ClipCategoryMoveToNone extends ClipCategoryMoveChoice {
  const ClipCategoryMoveToNone();
}

/// Create a category first, then file the clips into it.
final class ClipCategoryMoveToNew extends ClipCategoryMoveChoice {
  const ClipCategoryMoveToNew();
}

/// Archive the clips instead of filing them.
final class ClipCategoryMoveToArchive extends ClipCategoryMoveChoice {
  const ClipCategoryMoveToArchive();
}

/// What the user picked in the category management sheet.
enum ClipCategoryManageChoice { rename, delete }

/// Bottom sheets backing the library's category management.
///
/// The `run*` flows chain the sheets and dispatch the resulting events, so
/// the chip row's long-press and the toolbar's actions behave identically
/// without either owning a copy of the sequence.
abstract final class ClipCategoryActions {
  /// Asks for a name and creates a category, optionally filing [clipIds]
  /// into it right away.
  static Future<void> runCreateFlow({
    required BuildContext context,
    required ClipsLibraryBloc bloc,
    Set<String> clipIds = const {},
  }) async {
    final name = await showNamePrompt(
      context: context,
      title: context.l10n.libraryCategoryCreateTitle,
      confirmLabel: context.l10n.libraryCategoryCreateAction,
    );
    if (name == null) return;
    bloc.add(ClipsLibraryCategoryCreated(name, clipIds: clipIds));
  }

  /// Runs the rename/delete flow for [category].
  static Future<void> runManageFlow({
    required BuildContext context,
    required ClipsLibraryBloc bloc,
    required ClipCategory category,
  }) async {
    final choice = await showManageSheet(context: context, category: category);
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case ClipCategoryManageChoice.rename:
        final name = await showNamePrompt(
          context: context,
          title: context.l10n.libraryCategoryRenameTitle,
          confirmLabel: context.l10n.libraryCategoryRenameAction,
          initialName: category.name,
        );
        if (name == null) return;
        bloc.add(
          ClipsLibraryCategoryRenamed(categoryId: category.id, name: name),
        );
      case ClipCategoryManageChoice.delete:
        final confirmed = await confirmDelete(
          context: context,
          category: category,
        );
        if (!confirmed) return;
        bloc.add(ClipsLibraryCategoryDeleted(category.id));
    }
  }

  /// Asks where to file [clipIds] and dispatches the move.
  static Future<void> runMoveFlow({
    required BuildContext context,
    required ClipsLibraryBloc bloc,
    required Set<String> clipIds,
  }) async {
    if (clipIds.isEmpty) return;

    final state = bloc.state;
    // Offer the current category as preselected only when the whole
    // selection already shares one; a mixed selection has no current value.
    final currentCategoryIds = {
      for (final clip in state.clips)
        if (clipIds.contains(clip.id)) clip.categoryId,
    };
    final choice = await showMoveSheet(
      context: context,
      categories: state.categories,
      currentCategoryId: currentCategoryIds.length == 1
          ? currentCategoryIds.first
          : null,
      showArchiveOption: !state.isShowingTrash,
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case ClipCategoryMoveToNew():
        await runCreateFlow(context: context, bloc: bloc, clipIds: clipIds);
      case ClipCategoryMoveToArchive():
        bloc.add(
          ClipsLibraryClipsArchiveChanged(clipIds: clipIds, archived: true),
        );
      case ClipCategoryMoveToNone():
        bloc.add(
          ClipsLibraryClipsMovedToCategory(clipIds: clipIds, categoryId: null),
        );
      case ClipCategoryMoveToExisting(:final categoryId):
        bloc.add(
          ClipsLibraryClipsMovedToCategory(
            clipIds: clipIds,
            categoryId: categoryId,
          ),
        );
    }
  }

  /// Sentinel option values for the move sheet. Category ids are UUIDs, so
  /// these cannot collide with a real one.
  static const _noneValue = '__no_category__';
  static const _newValue = '__new_category__';
  static const _archiveValue = '__archive__';

  /// Asks where to file the selected clips.
  ///
  /// Returns null when the sheet is dismissed without a choice.
  static Future<ClipCategoryMoveChoice?> showMoveSheet({
    required BuildContext context,
    required List<ClipCategory> categories,
    String? currentCategoryId,
    bool showArchiveOption = true,
  }) async {
    final l10n = context.l10n;
    final selected = await VineBottomSheetSelectionMenu.show(
      context: context,
      title: Text(
        l10n.libraryCategoryMoveTitle,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      selectedValue: currentCategoryId ?? _noneValue,
      options: [
        VineBottomSheetSelectionOptionData(
          label: l10n.libraryCategoryMoveNone,
          value: _noneValue,
          leadingIcon: DivineIconName.prohibit,
        ),
        for (final category in categories)
          VineBottomSheetSelectionOptionData(
            label: category.name,
            value: category.id,
            leadingIcon: DivineIconName.folderOpen,
          ),
        VineBottomSheetSelectionOptionData(
          label: l10n.libraryCategoryMoveNewCategory,
          value: _newValue,
          leadingIcon: DivineIconName.plus,
        ),
        if (showArchiveOption)
          VineBottomSheetSelectionOptionData(
            label: l10n.libraryArchiveAction,
            value: _archiveValue,
            leadingIcon: DivineIconName.stackSimple,
          ),
      ],
    );

    return switch (selected) {
      null => null,
      _noneValue => const ClipCategoryMoveToNone(),
      _newValue => const ClipCategoryMoveToNew(),
      _archiveValue => const ClipCategoryMoveToArchive(),
      final String id => ClipCategoryMoveToExisting(id),
    };
  }

  /// Asks whether to rename or delete [category].
  ///
  /// Returns null when the sheet is dismissed without a choice.
  static Future<ClipCategoryManageChoice?> showManageSheet({
    required BuildContext context,
    required ClipCategory category,
  }) async {
    ClipCategoryManageChoice? choice;
    await VineBottomSheetActionMenu.show(
      context: context,
      title: Text(
        category.name,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      options: [
        VineBottomSheetActionData(
          iconPath: DivineIconName.pencilSimple.assetPath,
          label: context.l10n.libraryCategoryRenameAction,
          onTap: () => choice = ClipCategoryManageChoice.rename,
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.trash.assetPath,
          label: context.l10n.libraryCategoryDeleteAction,
          isDestructive: true,
          onTap: () => choice = ClipCategoryManageChoice.delete,
        ),
      ],
    );
    return choice;
  }

  /// Asks for a category name.
  ///
  /// Returns the entered text, or null when the sheet is dismissed. The
  /// caller still passes the text through [ClipCategory.sanitizeName] via the
  /// bloc, which rejects blank input.
  static Future<String?> showNamePrompt({
    required BuildContext context,
    required String title,
    required String confirmLabel,
    String? initialName,
  }) {
    return VineBottomSheet.show<String>(
      context: context,
      scrollable: false,
      expanded: false,
      isScrollControlled: true,
      title: Text(
        title,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      body: _CategoryNameForm(
        confirmLabel: confirmLabel,
        initialName: initialName,
      ),
    );
  }

  /// Confirms deleting [category], spelling out that its clips survive.
  static Future<bool> confirmDelete({
    required BuildContext context,
    required ClipCategory category,
  }) async {
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: context.l10n.libraryCategoryDeleteConfirmTitle(category.name),
      subtitle: context.l10n.libraryCategoryDeleteConfirmMessage,
      primaryButtonText: context.l10n.commonDelete,
      secondaryButtonText: context.l10n.commonCancel,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );
    return confirmed ?? false;
  }
}

class _CategoryNameForm extends StatefulWidget {
  const _CategoryNameForm({required this.confirmLabel, this.initialName});

  final String confirmLabel;
  final String? initialName;

  @override
  State<_CategoryNameForm> createState() => _CategoryNameFormState();
}

class _CategoryNameFormState extends State<_CategoryNameForm> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    if (ClipCategory.sanitizeName(value) == null) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return VineKeyboardAwareFooter(
      includeSafeArea: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            DivineTextField(
              key: const Key('clip_category_name_field'),
              controller: _controller,
              labelText: context.l10n.libraryCategoryNameLabel,
              // Sits directly on the sheet surface, so it needs its own fill
              // to have a visible edge at all.
              filled: true,
              primaryWhenFilled: true,
              autofocus: true,
              maxLength: ClipCategory.maxNameLength,
              textInputAction: TextInputAction.done,
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              onSubmitted: _submit,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final canSubmit = ClipCategory.sanitizeName(value.text) != null;
                return DivineButton(
                  expanded: true,
                  label: widget.confirmLabel,
                  onPressed: canSubmit ? () => _submit(value.text) : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
