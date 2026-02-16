// ABOUTME: Input widget for adding/managing video collaborators
// ABOUTME: Shows collaborator chips with remove buttons, max 5 limit,
// ABOUTME: and opens UserPickerSheet for adding via mutual-follow search

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';

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
    final remainingSlots =
        VideoEditorNotifier.maxCollaborators - collaborators.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            children: [
              Text(
                // TODO(l10n): Replace with context.l10n
                //   when localization is added.
                'Collaborators',
                style: VineTheme.bodyFont(
                  color: VineTheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(width: 8),
              _HelpButton(
                // TODO(l10n): Replace with context.l10n
                //   when localization is added.
                onTap: () => _showHelpDialog(context),
                tooltip: 'How collaborators work',
              ),
            ],
          ),
          Text(
            // TODO(l10n): Replace with context.l10n
            //   when localization is added.
            'Tag up to ${VideoEditorNotifier.maxCollaborators} mutual '
            'follows as co-creators.',
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
          ),

          if (collaborators.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x6E032017),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: VineTheme.outlineVariant),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: collaborators
                    .map((pubkey) => _CollaboratorChip(pubkey: pubkey))
                    .toList(),
              ),
            ),

          if (collaborators.length < VideoEditorNotifier.maxCollaborators)
            _AddCollaboratorButton(
              onPressed: () => _addCollaborator(context, ref),
              remainingSlots: remainingSlots,
            ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: VineTheme.cardBackground,
          title: Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Collaborators',
            style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
          ),
          content: Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Collaborators are tagged as co-creators on this post. '
            'You can only add people you mutually follow, and they appear in '
            'the post metadata when published.',
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                // TODO(l10n): Replace with context.l10n when localization is added.
                'Got it',
                style: VineTheme.bodyFont(color: VineTheme.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addCollaborator(BuildContext context, WidgetRef ref) async {
    final profile = await showUserPickerSheet(
      context,
      filterMode: UserPickerFilterMode.mutualFollowsOnly,
      // TODO(l10n): Replace with context.l10n
      //   when localization is added.
      title: 'Add collaborator',
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
          // TODO(l10n): Replace with context.l10n
          //   when localization is added.
          content: Text(
            'You need to mutually follow '
            '${profile.bestDisplayName} to add '
            'them as a collaborator.',
          ),
          backgroundColor: VineTheme.cardBackground,
        ),
      );
      return;
    }

    ref.read(videoEditorProvider.notifier).addCollaborator(profile.pubkey);
  }
}

/// Chip showing a collaborator's avatar, name, and remove button.
class _CollaboratorChip extends ConsumerWidget {
  const _CollaboratorChip({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fetchUserProfileProvider(pubkey));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0B2A20),
        border: Border.all(color: VineTheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
            imageUrl: profileAsync.value?.picture,
            name: profileAsync.value?.bestDisplayName,
            size: 24,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              profileAsync.value?.bestDisplayName ??
                  '${pubkey.substring(0, 8)}...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.bodyFont(
                color: VineTheme.whiteText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.38,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            // TODO(l10n): Replace with context.l10n
            //   when localization is added.
            label: 'Remove collaborator',
            button: true,
            child: GestureDetector(
              onTap: () => ref
                  .read(videoEditorProvider.notifier)
                  .removeCollaborator(pubkey),
              child: SizedBox(
                width: 16,
                height: 16,
                child: SvgPicture.asset(
                  'assets/icon/close.svg',
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF818F8B),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Button to add a new collaborator.
class _AddCollaboratorButton extends StatelessWidget {
  const _AddCollaboratorButton({
    required this.onPressed,
    required this.remainingSlots,
  });

  final VoidCallback onPressed;
  final int remainingSlots;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0x8C032017),
          border: Border.all(color: VineTheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: const Color(0xFF0E2B21),
              ),
              child: const Icon(Icons.add, color: VineTheme.primary, size: 15),
            ),
            const SizedBox(width: 8),
            Text(
              // TODO(l10n): Replace with context.l10n
              //   when localization is added.
              'Add collaborator (${remainingSlots} left)',
              style: VineTheme.bodyFont(
                color: VineTheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              // TODO(l10n): Replace with context.l10n
              //   when localization is added.
              'Mutuals only',
              style: VineTheme.bodyFont(
                color: VineTheme.onSurfaceMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.onTap, required this.tooltip});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0x8C032017),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: VineTheme.outlineVariant),
          ),
          child: Center(
            child: Text(
              '?',
              style: VineTheme.bodyFont(
                color: VineTheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
