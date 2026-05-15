// ABOUTME: Bottom bar for the full-screen video metadata edit flow.
// ABOUTME: Handles update (re-publish with createdAt+1) and delete flows.

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart' hide AspectRatio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/video_metadata_update_service.dart';
import 'package:openvine/utils/delete_failure_localization.dart';
import 'package:unified_logger/unified_logger.dart';

/// Bottom action bar for the video metadata edit screen.
///
/// Shows a "Delete" button (secondary) and an "Update" button (primary)
/// side by side, matching the capture bottom bar layout.
class VideoMetadataEditBottomBar extends ConsumerStatefulWidget {
  const VideoMetadataEditBottomBar({
    required this.video,
    required this.initialCollaboratorPubkeys,
    this.pendingThumbnailPath,
    super.key,
  });

  final VideoEvent video;
  final Set<String> initialCollaboratorPubkeys;
  final String? pendingThumbnailPath;

  @override
  ConsumerState<VideoMetadataEditBottomBar> createState() =>
      _VideoMetadataEditBottomBarState();
}

class _VideoMetadataEditBottomBarState
    extends ConsumerState<VideoMetadataEditBottomBar> {
  bool _isUpdating = false;
  bool _isDeleting = false;

  bool get _isBusy => _isUpdating || _isDeleting;

  Future<void> _updateVideo() async {
    if (_isBusy) return;
    setState(() => _isUpdating = true);

    try {
      final editorState = ref.read(videoEditorProvider);
      final service = ref.read(videoMetadataUpdateServiceProvider);
      final result = await service.updateVideo(
        originalVideo: widget.video,
        editorState: editorState,
        newThumbnailFile: widget.pendingThumbnailPath != null
            ? File(widget.pendingThumbnailPath!)
            : null,
        initialCollaboratorPubkeys: widget.initialCollaboratorPubkeys,
      );

      if (result is VideoUpdateSuccess) {
        if (widget.pendingThumbnailPath != null) {
          File(widget.pendingThumbnailPath!).delete().ignore();
        }
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          final snackBar = DivineSnackbarContainer.snackBar(
            result.inviteFailureCount == 0
                ? context.l10n.shareMenuVideoUpdated
                : context.l10n.shareMenuVideoUpdatedWithInviteFailures(
                    result.inviteFailureCount,
                  ),
            error: result.inviteFailureCount > 0,
          );
          context.pop();
          messenger.showSnackBar(snackBar);
        }
      } else if (result is VideoUpdateFailure) {
        throw result.error;
      }
    } catch (e) {
      Log.error(
        'Failed to update video: $e',
        name: 'VideoMetadataEditBottomBar',
        category: LogCategory.ui,
      );

      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.shareMenuFailedToUpdateVideo('$e'),
            error: true,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    if (_isBusy) return;
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: DivineStickerName.alert,
      title: context.l10n.shareMenuDeleteVideoQuestion,
      subtitle: context.l10n.shareMenuDeleteRelayWarning,
      primaryButtonText: context.l10n.shareMenuDelete,
      primaryButtonType: DivineButtonType.error,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      secondaryButtonText: context.l10n.shareMenuCancel,
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (confirmed == true) {
      await _deleteVideo();
    }
  }

  Future<void> _deleteVideo() async {
    if (_isBusy) return;
    setState(() => _isDeleting = true);

    try {
      final deletionService = await ref.read(
        contentDeletionServiceProvider.future,
      );

      final result = await deletionService.quickDelete(
        video: widget.video,
        reason: DeleteReason.personalChoice,
      );

      if (result.success) {
        final videoEventService = ref.read(videoEventServiceProvider);
        videoEventService.removeVideoCompletely(widget.video.id);

        Log.info(
          'Video deleted successfully: ${widget.video.id}',
          name: 'VideoMetadataEditBottomBar',
          category: LogCategory.ui,
        );

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          final snackBar = DivineSnackbarContainer.snackBar(
            context.l10n.shareMenuVideoDeletionRequested,
          );
          context.pop();
          messenger.showSnackBar(snackBar);
        }
      } else {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(
              localizedDeleteFailureMessage(context, result),
              error: true,
            ),
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to delete video: $e',
        name: 'VideoMetadataEditBottomBar',
        category: LogCategory.ui,
      );

      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.shareMenuDeleteFailedGeneric,
            error: true,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.15);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 10,
          children: [
            Expanded(
              child: _DeleteButton(
                onTap: _confirmDelete,
                isBusy: _isBusy,
                isDeleting: _isDeleting,
              ),
            ),
            Expanded(
              child: _UpdateButton(
                onTap: _updateVideo,
                isBusy: _isBusy,
                isUpdating: _isUpdating,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined button to delete the video.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.onTap,
    required this.isBusy,
    required this.isDeleting,
  });

  final VoidCallback onTap;
  final bool isBusy;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'delete_button',
      child: DivineButton(
        onPressed: isBusy ? null : onTap,
        type: .error,
        label: context.l10n.shareMenuDeleteVideo,
        isLoading: isDeleting,
      ),
    );
  }
}

/// Filled button to publish the updated video metadata.
class _UpdateButton extends StatelessWidget {
  const _UpdateButton({
    required this.onTap,
    required this.isBusy,
    required this.isUpdating,
  });

  final VoidCallback onTap;
  final bool isBusy;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'update_button',
      child: DivineButton(
        onPressed: isBusy ? null : onTap,
        expanded: true,
        label: context.l10n.shareMenuUpdate,
        isLoading: isUpdating,
      ),
    );
  }
}
