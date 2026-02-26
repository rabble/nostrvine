// ABOUTME: Dialogs for adding videos to curated lists
// ABOUTME: Extracted from share_video_menu.dart - SelectListDialog and CreateListDialog

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:divine_ui/divine_ui.dart';

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

          return AlertDialog(
            backgroundColor: VineTheme.cardBackground,
            title: const Text(
              'Add to List',
              style: TextStyle(color: VineTheme.whiteText),
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
                      '${list.videoEventIds.length} videos',
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
              TextButton(onPressed: context.pop, child: const Text('Done')),
            ],
          );
        },
        loading: () => const _LoadingIndicator(),
        error: (_, __) => const Center(child: Text('Error loading lists')),
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
            ? 'Removed from ${list.name}'
            : 'Added to ${list.name}';
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
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: const Text(
      'Create New List',
      style: TextStyle(color: VineTheme.whiteText),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          enableInteractiveSelection: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: const InputDecoration(
            labelText: 'List Name',
            labelStyle: TextStyle(color: VineTheme.secondaryText),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          enableInteractiveSelection: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            labelStyle: TextStyle(color: VineTheme.secondaryText),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text(
            'Public List',
            style: TextStyle(color: VineTheme.whiteText),
          ),
          subtitle: const Text(
            'Others can follow and see this list',
            style: TextStyle(color: VineTheme.secondaryText),
          ),
          value: _isPublic,
          onChanged: (value) => setState(() => _isPublic = value),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: context.pop, child: const Text('Cancel')),
      TextButton(onPressed: _createList, child: const Text('Create')),
    ],
  );

  Future<void> _createList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final listService = await ref
          .read(curatedListsStateProvider.notifier)
          .service;
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
          const SnackBar(
            content: Text('Failed to create list'),
            duration: Duration(seconds: 2),
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
