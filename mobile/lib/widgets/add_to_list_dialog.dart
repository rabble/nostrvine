// ABOUTME: Dialogs for adding videos to curated lists
// ABOUTME: Extracted from share_video_menu.dart - SelectListDialog and CreateListDialog

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:unified_logger/unified_logger.dart';

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: VineTheme.secondaryText,
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
            backgroundColor: VineTheme.cardBackground,
            title: Text(
              l10n.listAddToList,
              style: const TextStyle(color: VineTheme.whiteText),
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
                    leading: Icon(
                      isInList ? Icons.check_circle : Icons.playlist_play,
                      color: isInList
                          ? VineTheme.vineGreen
                          : VineTheme.whiteText,
                    ),
                    title: Text(
                      list.name,
                      style: const TextStyle(color: VineTheme.whiteText),
                    ),
                    subtitle: Text(
                      l10n.listVideoCount(list.videoEventIds.length),
                      style: const TextStyle(color: VineTheme.secondaryText),
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
              TextButton(
                onPressed: context.pop,
                child: Text(l10n.listDone),
              ),
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

/// Dialog for creating a new curated list and adding a video to it.
class CreateListDialog extends ConsumerStatefulWidget {
  const CreateListDialog({required this.video, super.key});
  final VideoEvent video;

  @override
  ConsumerState<CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends ConsumerState<CreateListDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isPublic = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: Text(
        l10n.listCreateNewList,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: InputDecoration(
              labelText: l10n.listNameLabel,
              labelStyle: const TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: InputDecoration(
              labelText: l10n.listDescriptionLabel,
              labelStyle: const TextStyle(color: VineTheme.secondaryText),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(
              l10n.listPublicList,
              style: const TextStyle(color: VineTheme.whiteText),
            ),
            subtitle: Text(
              l10n.listPublicListSubtitle,
              style: const TextStyle(color: VineTheme.secondaryText),
            ),
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: context.pop, child: Text(l10n.listCancel)),
        TextButton(onPressed: _createList, child: Text(l10n.listCreate)),
      ],
    );
  }

  Future<void> _createList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final listService = ref.read(curatedListsStateProvider.notifier).service;
      final newList = await listService?.createList(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isPublic: _isPublic,
      );

      if (newList != null && mounted) {
        // Add the video to the new list
        await listService?.addVideoToList(newList.id, widget.video.id);

        if (mounted) {
          // Close dialog and return the list name
          context.pop();
        }
      }
    } catch (e) {
      Log.error(
        'Failed to create list: $e',
        name: 'CreateListDialog',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.listCreateFailed),
            duration: const Duration(seconds: 2),
          ),
        );
        // Return null to indicate failure
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
