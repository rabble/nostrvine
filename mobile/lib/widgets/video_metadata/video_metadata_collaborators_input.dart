// ABOUTME: Input widget for adding/managing video collaborators
// ABOUTME: Shows collaborator chips with remove buttons, max 5 limit,
// ABOUTME: and opens UserPickerSheet for adding via mutual-follow search

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_help_button.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_help_sheet.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_user_chip.dart';

/// Input widget for adding and managing collaborators on a video.
///
/// Displays collaborator chips (avatar + name + remove) and an
/// "Add collaborator" button. Limited to [VideoEditorNotifier.maxCollaborators].
class VideoMetadataCollaboratorsInput extends ConsumerWidget {
  /// Creates a video metadata collaborators input widget.
  const VideoMetadataCollaboratorsInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collaborators = ref.watch(
      videoEditorProvider.select((s) => s.collaboratorPubkeys),
    );

    final canAddCollaborators =
        collaborators.length < VideoEditorNotifier.maxCollaborators;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Add collaborator',
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
                        // TODO(l10n): Replace with context.l10n
                        //   when localization is added.
                        'Collaborators',
                        style: VineTheme.labelSmallFont(
                          color: VineTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      VideoMetadataHelpButton(
                        // TODO(l10n): Replace with context.l10n
                        //   when localization is added.
                        onTap: () => _showHelpDialog(context),
                        tooltip: 'How collaborators work',
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${collaborators.length}/'
                          '${VideoEditorNotifier.maxCollaborators} Collaborators',
                          style: VineTheme.titleFont(
                            fontSize: 16,
                            color: VineTheme.onSurface,
                            letterSpacing: 0.15,
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
                            'assets/icon/caret_right.svg',
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

        if (collaborators.isNotEmpty)
          Padding(
            padding: const .fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: collaborators
                  .map(
                    (pubkey) => VideoMetadataUserChip.fromPubkey(
                      pubkey: pubkey,
                      // TODO(l10n): Replace with context.l10n
                      //   when localization is added.
                      removeLabel: 'Remove collaborator',
                      onRemove: () => ref
                          .read(videoEditorProvider.notifier)
                          .removeCollaborator(pubkey),
                    ),
                  )
                  .toList(),
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
      body: const VideoMetadataHelpSheet(
        // TODO(l10n): Replace with context.l10n when localization is added.
        title: 'Collaborators',
        message:
            'Collaborators are tagged as co-creators on this post. '
            'You can only add people you mutually follow, and they appear '
            'in the post metadata when published.',
        assetPath: 'assets/stickers/stars.png',
      ),
    );
  }

  Future<void> _addCollaborator(BuildContext context, WidgetRef ref) async {
    // Get current collaborators to exclude from picker
    final currentCollaborators = ref
        .read(videoEditorProvider)
        .collaboratorPubkeys
        .toSet();

    final profile = await showUserPickerSheet(
      context,
      filterMode: UserPickerFilterMode.mutualFollowsOnly,
      // TODO(l10n): Replace with context.l10n when localization is added.
      title: 'Add collaborator',
      searchText: 'Mutual followers',
      excludePubkeys: currentCollaborators,
    );

    if (profile == null || !context.mounted) return;

    // Verify mutual follow
    final followRepo = ref.read(followRepositoryProvider);
    if (followRepo == null) return;
    final isMutual = await followRepo.isMutualFollow(profile.pubkey);

    if (!isMutual) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          content: DivineSnackbarContainer(
            // TODO(l10n): Replace with context.l10n when localization is added.
            label:
                'You need to mutually follow '
                '${profile.bestDisplayName} to add '
                'them as a collaborator.',
          ),
        ),
      );
      return;
    }

    ref.read(videoEditorProvider.notifier).addCollaborator(profile.pubkey);
  }
}
