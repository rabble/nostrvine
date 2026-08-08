// ABOUTME: Dialogs for adding videos to curated lists
// ABOUTME: SelectListDialog and CreateListDialog for curated video lists

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:unified_logger/unified_logger.dart';

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.vineColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

/// Dialog for selecting an existing list to add a video to.
class SelectListDialog extends StatelessWidget {
  const SelectListDialog({required this.video, super.key});
  final VideoEvent video;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, child) {
      final listServiceAsync = ref.watch(curatedListsStateProvider);

      return listServiceAsync.when(
        data: (lists) {
          final availableLists = lists.toList();

          final l10n = context.l10n;
          return AlertDialog(
            backgroundColor: context.vineColors.card,
            title: Text(
              l10n.listAddToList,
              style: TextStyle(color: context.vineColors.primaryText),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: availableLists.length,
                itemBuilder: (context, index) {
                  final list = availableLists[index];
                  final isInList = list.videoEventIds.contains(video.id);

                  return ListTile(
                    leading: DivineIcon(
                      icon: isInList
                          ? DivineIconName.checkCircle
                          : DivineIconName.playlist,
                      color: isInList
                          ? VineTheme.vineGreen
                          : context.vineColors.primaryText,
                    ),
                    title: Text(
                      list.name,
                      style: TextStyle(color: context.vineColors.primaryText),
                    ),
                    subtitle: Text(
                      '${l10n.listVideoCount(list.videoEventIds.length)} • '
                      '${list.isPublic ? l10n.listVisibilityPublic : l10n.listVisibilityPrivateDevice}',
                      style: TextStyle(color: context.vineColors.secondaryText),
                    ),
                    onTap: () => _toggleVideoInList(
                      context,
                      ref.read(curatedListsStateProvider.notifier).service!,
                      list,
                      isInList,
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => CreateListDialog(video: video),
                  );
                },
                child: Text(l10n.listNewList),
              ),
              TextButton(onPressed: context.pop, child: Text(l10n.listDone)),
            ],
          );
        },
        loading: () => const _LoadingIndicator(),
        error: (_, _) => Center(child: Text(context.l10n.listErrorLoading)),
      );
    },
  );

  Future<void> _toggleVideoInList(
    BuildContext context,
    CuratedListService listService,
    CuratedList list,
    bool isCurrentlyInList,
  ) async {
    try {
      bool success;
      if (isCurrentlyInList) {
        success = await listService.removeVideoFromList(list.id, video.id);
      } else {
        success = await listService.addVideoToList(list.id, video.id);
      }

      if (success && context.mounted) {
        final message = isCurrentlyInList
            ? context.l10n.listRemovedFrom(list.name)
            : context.l10n.listAddedTo(list.name);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to toggle video in list: $e',
        name: 'SelectListDialog',
        category: LogCategory.ui,
      );
    }
  }
}

/// Dialog for creating a new curated list, optionally adding [video] to it.
class CreateListDialog extends ConsumerStatefulWidget {
  const CreateListDialog({this.video, this.existingList, super.key});
  final VideoEvent? video;
  final CuratedList? existingList;

  @override
  ConsumerState<CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends ConsumerState<CreateListDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isPublic = true;

  bool get _isEditing => widget.existingList != null;

  @override
  void initState() {
    super.initState();
    final list = widget.existingList;
    if (list == null) return;
    _nameController.text = list.name;
    _descriptionController.text = list.description ?? '';
    _isPublic = list.isPublic;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: context.vineColors.card,
      title: Text(
        _isEditing ? l10n.listEditTitle : l10n.listCreateNewList,
        style: TextStyle(color: context.vineColors.primaryText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            enableInteractiveSelection: true,
            style: TextStyle(color: context.vineColors.primaryText),
            decoration: InputDecoration(
              labelText: l10n.listNameLabel,
              labelStyle: TextStyle(color: context.vineColors.secondaryText),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            enableInteractiveSelection: true,
            style: TextStyle(color: context.vineColors.primaryText),
            decoration: InputDecoration(
              labelText: l10n.listDescriptionLabel,
              labelStyle: TextStyle(color: context.vineColors.secondaryText),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(
              l10n.listPublicList,
              style: TextStyle(color: context.vineColors.primaryText),
            ),
            subtitle: Text(
              _isPublic
                  ? l10n.listPublicListSubtitle
                  : l10n.listPrivateListSubtitle,
              style: TextStyle(color: context.vineColors.secondaryText),
            ),
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: context.pop, child: Text(l10n.listCancel)),
        TextButton(
          onPressed: _saveList,
          child: Text(_isEditing ? l10n.listSave : l10n.listCreate),
        ),
      ],
    );
  }

  Future<void> _saveList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final listService = ref.read(curatedListsStateProvider.notifier).service;
      final existingList = widget.existingList;
      if (existingList != null) {
        if (existingList.isPublic != _isPublic &&
            !await _confirmVisibilityChange(existingList.isPublic)) {
          return;
        }
        if (!mounted) return;
        if (listService == null) {
          _showSaveFailed();
          return;
        }

        final messenger = ScaffoldMessenger.of(context);
        final failureMessage = context.l10n.listUpdateFailed;
        final updateFuture = listService.updateList(
          listId: existingList.id,
          name: name,
          description: _descriptionController.text.trim(),
          isPublic: _isPublic,
        );

        // updateList applies local fields before waiting for the relay, and a
        // visibility change can wait through the relay deadline. Close the
        // editor now so a slow relay does not make the save look unresponsive.
        Navigator.of(context).pop();

        if (!await updateFuture && messenger.mounted) {
          _showSaveFailed(
            messenger: messenger,
            failureMessage: failureMessage,
          );
        }
        return;
      }

      final newList = await listService?.createList(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isPublic: _isPublic,
      );

      if (!mounted) return;

      // createList catches its own exceptions and returns null — without
      // feedback here the dialog used to sit open doing nothing.
      if (newList == null) {
        _showSaveFailed();
        return;
      }

      final video = widget.video;
      if (video != null) {
        await listService?.addVideoToList(newList.id, video.id);
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      Log.error(
        'Failed to create list: $e',
        name: 'CreateListDialog',
        category: LogCategory.ui,
      );

      if (mounted) {
        _showSaveFailed();
      }
    }
  }

  Future<bool> _confirmVisibilityChange(bool wasPublic) async {
    final confirmed = await context.showVideoPausingDialog<bool>(
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.vineColors.card,
        title: Text(
          wasPublic
              ? context.l10n.listMakePrivateTitle
              : context.l10n.listMakePublicTitle,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        content: Text(
          wasPublic
              ? context.l10n.listMakePrivateWarning
              : context.l10n.listMakePublicWarning,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        actions: [
          DivineButton(
            label: context.l10n.commonCancel,
            type: DivineButtonType.link,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          DivineButton(
            label: context.l10n.listContinue,
            type: DivineButtonType.link,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  // A retained messenger lets an edit report relay failure after dismissing.
  void _showSaveFailed({
    ScaffoldMessengerState? messenger,
    String? failureMessage,
  }) {
    (messenger ?? ScaffoldMessenger.of(context)).showSnackBar(
      SnackBar(
        content: Text(
          failureMessage ??
              (_isEditing
                  ? context.l10n.listUpdateFailed
                  : context.l10n.listCreateFailed),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
