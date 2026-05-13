// ABOUTME: Bottom bar for the full-screen video metadata edit flow.
// ABOUTME: Handles update (re-publish with createdAt+1) and delete flows.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart' hide AspectRatio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory, NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/utils/collaborator_tags.dart';
import 'package:openvine/utils/delete_failure_localization.dart';
import 'package:openvine/widgets/share_video_menu.dart'
    show extractEngagementCountTags, sendPostPublishCollaboratorInvites;
import 'package:unified_logger/unified_logger.dart';

/// Bottom action bar for the video metadata edit screen.
///
/// Shows a "Delete" button (secondary) and an "Update" button (primary)
/// side by side, matching the capture bottom bar layout.
class VideoMetadataEditBottomBar extends ConsumerStatefulWidget {
  const VideoMetadataEditBottomBar({
    required this.video,
    required this.initialCollaboratorPubkeys,
    super.key,
  });

  final VideoEvent video;
  final Set<String> initialCollaboratorPubkeys;

  @override
  ConsumerState<VideoMetadataEditBottomBar> createState() =>
      _VideoMetadataEditBottomBarState();
}

class _VideoMetadataEditBottomBarState
    extends ConsumerState<VideoMetadataEditBottomBar> {
  bool _isUpdating = false;
  bool _isDeleting = false;

  Future<void> _updateVideo() async {
    setState(() => _isUpdating = true);

    // Capture l10n eagerly — awaiting the publish round-trip means the
    // widget may have unmounted by the time the invite service needs it.
    final inviteL10n = context.l10n;

    try {
      final editorState = ref.read(videoEditorProvider);

      final authService = ref.read(authServiceProvider);
      if (!authService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final tags = <List<String>>[];

      // Required 'd' tag — must use the same identifier to replace the event.
      tags.add(['d', widget.video.stableId]);

      // Extract ALL valid HTTP video URLs from the original imeta tag.
      // The original event may have multiple URL entries (streaming MP4,
      // HLS, R2 fallback, etc.) which must all be preserved.
      final videoUrls = <String>[];
      for (final tag in widget.video.nostrEventTags) {
        if (tag.isEmpty || tag[0] != 'imeta') continue;
        if (tag.length > 1 && tag[1].contains(' ')) {
          // Old imeta format: ['imeta', 'url https://...', 'm video/mp4', ...]
          for (var i = 1; i < tag.length; i++) {
            final spaceIdx = tag[i].indexOf(' ');
            if (spaceIdx > 0) {
              final key = tag[i].substring(0, spaceIdx);
              final value = tag[i].substring(spaceIdx + 1);
              if (key == 'url' &&
                  _isHttpUrl(value) &&
                  !videoUrls.contains(value)) {
                videoUrls.add(value);
              }
            }
          }
        } else {
          // New imeta format: ['imeta', 'url', 'https://...', 'm', 'video/mp4', ...]
          for (var i = 1; i < tag.length - 1; i += 2) {
            if (tag[i] == 'url' &&
                _isHttpUrl(tag[i + 1]) &&
                !videoUrls.contains(tag[i + 1])) {
              videoUrls.add(tag[i + 1]);
            }
          }
        }
      }

      // Fallback: nostrEventTags may be empty for events loaded from a JSON
      // cache that doesn't serialise raw tags — use the single videoUrl.
      if (videoUrls.isEmpty && _isHttpUrl(widget.video.videoUrl)) {
        videoUrls.add(widget.video.videoUrl!);
      }

      if (videoUrls.isEmpty) {
        throw Exception('Cannot update video: no valid HTTP video URLs found');
      }

      // Build imeta tag components (preserve all original media URLs).
      final imetaComponents = <String>[];
      for (final url in videoUrls) {
        imetaComponents.add('url $url');
      }
      imetaComponents.add('m video/mp4');

      if (widget.video.thumbnailUrl != null) {
        imetaComponents.add('image ${widget.video.thumbnailUrl!}');
      }
      if (widget.video.blurhash != null) {
        imetaComponents.add('blurhash ${widget.video.blurhash!}');
      }
      if (widget.video.dimensions != null) {
        imetaComponents.add('dim ${widget.video.dimensions!}');
      }
      if (widget.video.sha256 != null) {
        imetaComponents.add('x ${widget.video.sha256!}');
      }
      if (widget.video.fileSize != null) {
        imetaComponents.add('size ${widget.video.fileSize!}');
      }

      if (imetaComponents.isNotEmpty) {
        tags.add(['imeta', ...imetaComponents]);
      }

      // Updated metadata from the editor form.
      final title = editorState.title.trim();
      if (title.isNotEmpty) {
        tags.add(['title', title]);
      }

      for (final hashtag in editorState.tags) {
        tags.add(['t', hashtag]);
      }

      for (final label in editorState.contentWarnings) {
        tags.add(['l', label.value, 'content-warning']);
      }

      // Preserve engagement count tags so a metadata edit doesn't zero
      // originalLoops / originalLikes for Vine-imported videos.
      tags.addAll(extractEngagementCountTags(widget.video.nostrEventTags));

      if (widget.video.publishedAt != null) {
        tags.add(['published_at', widget.video.publishedAt!]);
      }
      if (widget.video.duration != null) {
        tags.add(['duration', widget.video.duration.toString()]);
      }
      if (widget.video.altText != null) {
        tags.add(['alt', widget.video.altText!]);
      }

      for (final pubkey in editorState.collaboratorPubkeys) {
        tags.add(buildCollaboratorPTag(pubkey));
      }

      if (editorState.inspiredByVideo != null) {
        tags.add([
          'a',
          editorState.inspiredByVideo!.addressableId,
          editorState.inspiredByVideo!.relayUrl ?? '',
          'inspired-by',
        ]);
      }

      tags.add(['client', 'diVine']);

      if (editorState.allowAudioReuse) {
        tags.add(['allow_audio_reuse', 'true']);
      }

      // Build content with optional NIP-27 inspired-by person reference.
      var content = editorState.description.trim();
      final inspiredByNpub = editorState.inspiredByNpub;
      if (inspiredByNpub != null && inspiredByNpub.isNotEmpty) {
        final ibText = '\n\nInspired by nostr:$inspiredByNpub';
        content = content.isEmpty ? ibText.trim() : '$content$ibText';
      }

      // Use original created_at + 1 so relays treat this as a replacement
      // while preserving the video's chronological position in feeds.
      final event = await authService.createAndSignEvent(
        kind: NIP71VideoKinds.addressableShortVideo,
        content: content,
        tags: tags,
        createdAt: widget.video.createdAt + 1,
      );

      if (event == null) {
        throw Exception('Failed to create updated event');
      }

      final nostrService = ref.read(nostrServiceProvider);
      final publishResult = await nostrService.publishEvent(event);
      if (publishResult is! PublishSuccess) {
        throw Exception('Failed to publish updated event');
      }
      final publishedEvent = publishResult.event;

      final personalEventCache = ref.read(personalEventCacheServiceProvider);
      personalEventCache.cacheUserEvent(publishedEvent);

      final videoEventService = ref.read(videoEventServiceProvider);
      final updatedVideoEvent = VideoEvent.fromNostrEvent(publishedEvent);
      videoEventService.updateVideoEvent(updatedVideoEvent);

      final inviteResults = await sendPostPublishCollaboratorInvites(
        inviteService: CollaboratorInviteService(
          dmRepository: ref.read(dmRepositoryProvider),
          l10n: inviteL10n,
        ),
        video: updatedVideoEvent,
        previousCollaboratorPubkeys: widget.initialCollaboratorPubkeys,
        updatedCollaboratorPubkeys: editorState.collaboratorPubkeys,
      );
      final inviteFailures = inviteResults.values
          .where((r) => !r.success)
          .length;

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              inviteFailures == 0
                  ? context.l10n.shareMenuVideoUpdated
                  : 'Video updated, but $inviteFailures collaborator '
                        'invite${inviteFailures == 1 ? '' : 's'} did not send.',
            ),
            backgroundColor: inviteFailures == 0
                ? VineTheme.vineGreen
                : VineTheme.warning,
          ),
        );
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
          SnackBar(
            content: Text(context.l10n.shareMenuFailedToUpdateVideo('$e')),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
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
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.shareMenuVideoDeletionRequested),
              backgroundColor: VineTheme.vineGreen,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizedDeleteFailureMessage(context, result)),
              backgroundColor: VineTheme.error,
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
          SnackBar(
            content: Text(context.l10n.shareMenuDeleteFailedGeneric),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }

  /// Returns true only for HTTP/HTTPS URLs (excludes local file paths).
  static bool _isHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
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
                isDeleting: _isDeleting,
              ),
            ),
            Expanded(
              child: _UpdateButton(
                onTap: _updateVideo,
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
  const _DeleteButton({required this.onTap, required this.isDeleting});

  final VoidCallback onTap;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'delete_button',
      label: context.l10n.shareMenuDeleteVideo,
      button: true,
      child: DivineButton(
        onPressed: isDeleting ? null : onTap,
        type: .error,
        label: context.l10n.shareMenuDeleteVideo,
        isLoading: isDeleting,
      ),
    );
  }
}

/// Filled button to publish the updated video metadata.
class _UpdateButton extends StatelessWidget {
  const _UpdateButton({required this.onTap, required this.isUpdating});

  final VoidCallback onTap;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'update_button',
      label: context.l10n.shareMenuUpdate,
      button: true,
      child: DivineButton(
        onPressed: isUpdating ? null : onTap,
        expanded: true,
        label: context.l10n.shareMenuUpdate,
        isLoading: isUpdating,
      ),
    );
  }
}
