// ABOUTME: Input widget for adding/managing video collaborators
// ABOUTME: Shows collaborator chips with remove buttons, max 5 limit,
// ABOUTME: and opens UserPickerSheet for inviting via mutual-follow search

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_help_button.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_help_sheet.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_user_chip.dart';

/// Input widget for adding and managing collaborators on a video.
///
/// Displays collaborator chips (avatar + name + remove) and an
/// invite button. Limited to [VideoEditorNotifier.maxCollaborators].
class VideoMetadataCollaboratorsInput extends ConsumerWidget {
  /// Creates a video metadata collaborators input widget.
  const VideoMetadataCollaboratorsInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:collaborators, :pendingCollaborators) = ref.watch(
      videoEditorProvider.select(
        (s) => (
          collaborators: s.collaboratorPubkeys,
          pendingCollaborators: s.pendingCollaboratorPubkeys,
        ),
      ),
    );

    final totalCount = collaborators.length + pendingCollaborators.length;
    final canAddCollaborators =
        totalCount < VideoEditorNotifier.maxCollaborators;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: context.l10n.videoMetadataAddCollaboratorSemanticLabel,
          child: InkWell(
            onTap: canAddCollaborators
                ? () => _addCollaborator(context, ref)
                : null,
            child: Padding(
              padding: const .all(16),
              child: Column(
                spacing: 8,
                children: [
                  Row(
                    children: [
                      Text(
                        context.l10n.videoMetadataCollaboratorsLabel,
                        style: VineTheme.labelSmallFont(
                          color: VineTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      VideoMetadataHelpButton(
                        onTap: () => _showHelpDialog(context),
                        tooltip:
                            context.l10n.videoMetadataCollaboratorsHelpTooltip,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          context.l10n.videoMetadataCollaboratorsCount(
                            totalCount,
                            VideoEditorNotifier.maxCollaborators,
                          ),

                          style: VineTheme.titleMediumFont(
                            color: VineTheme.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: SvgPicture.asset(
                            DivineIconName.caretRight.assetPath,
                            colorFilter: ColorFilter.mode(
                              canAddCollaborators
                                  ? VineTheme.tabIndicatorGreen
                                  : VineTheme.outlineMuted,
                              .srcIn,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        if (collaborators.isNotEmpty || pendingCollaborators.isNotEmpty)
          Padding(
            padding: const .fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...collaborators.map(
                  (pubkey) => VideoMetadataUserChip.fromPubkey(
                    pubkey: pubkey,

                    removeLabel: context
                        .l10n
                        .videoMetadataRemoveCollaboratorSemanticLabel,
                    onRemove: () => ref
                        .read(videoEditorProvider.notifier)
                        .removeCollaborator(pubkey),
                  ),
                ),
                ...pendingCollaborators.map(
                  (pubkey) => VideoMetadataUserChip.fromPubkey(
                    pubkey: pubkey,
                    isLoading: true,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    VineBottomSheet.show(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: VideoMetadataHelpSheet(
        title: context.l10n.metadataCollaboratorsLabel,
        message: context.l10n.videoMetadataCollaboratorsHelpMessage,
        assetPath: 'assets/stickers/sparkle.svg',
      ),
    );
  }

  Future<void> _addCollaborator(BuildContext context, WidgetRef ref) async {
    // Get current and pending collaborators to exclude from picker
    final editorState = ref.read(videoEditorProvider);
    final excludePubkeys = {
      ...editorState.collaboratorPubkeys,
      ...editorState.pendingCollaboratorPubkeys,
    };

    final profile = await showUserPickerSheet(
      context,
      filterMode: UserPickerFilterMode.mutualFollowsOnly,
      title: context.l10n.videoMetadataAddCollaboratorSemanticLabel,
      searchText: context.l10n.videoMetadataMutualFollowersSearchText,
      excludePubkeys: excludePubkeys,
    );

    if (profile == null || !context.mounted) return;

    // Add to pending immediately for instant UI feedback
    final notifier = ref.read(videoEditorProvider.notifier);
    notifier.addPendingCollaborator(profile.pubkey);

    // Verify mutual follow in the background
    final followRepo = ref.read(followRepositoryProvider);
    final isMutual = await followRepo.isMutualFollow(profile.pubkey);

    if (!isMutual) {
      notifier.removePendingCollaborator(profile.pubkey);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            content: DivineSnackbarContainer(
              label: context.l10n.videoMetadataMustMutuallyFollowSnackbar(
                profile.bestDisplayName,
              ),
            ),
          ),
        );
      }
      return;
    }

    notifier.confirmCollaborator(profile.pubkey);
  }
}
