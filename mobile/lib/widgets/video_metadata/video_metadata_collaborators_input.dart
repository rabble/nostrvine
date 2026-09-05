// ABOUTME: Input widget for adding/managing video collaborators
// ABOUTME: Shows collaborator chips with remove buttons, max 5 limit,
// ABOUTME: and opens UserPickerSheet for inviting via mutual-follow search

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';

/// Preserves confirmed collaborators whose profiles were unavailable when the
/// picker opened, so they are not silently dropped on Done.
@visibleForTesting
Set<String> computeEffectiveCollaboratorResultPubkeys({
  required Set<String> confirmedPubkeys,
  required Set<String> preselectedPubkeys,
  required Set<String> pickerResultPubkeys,
  required String? viewerPubkey,
}) {
  final unresolvedConfirmedPubkeys = confirmedPubkeys.difference(
    preselectedPubkeys,
  );
  final effectivePubkeys = {
    ...pickerResultPubkeys,
    ...unresolvedConfirmedPubkeys,
  };
  if (viewerPubkey == null) return effectivePubkeys;
  return effectivePubkeys
      .where((pubkey) => !pubkeysEqual(pubkey, viewerPubkey))
      .toSet();
}

/// Input widget for adding and managing collaborators on a video.
///
/// Displays collaborator chips (avatar + name + remove) and an
/// invite button. Limited to [VideoEditorNotifier.maxCollaborators].
class VideoMetadataCollaboratorsInput extends ConsumerWidget {
  /// Creates a video metadata collaborators input widget.
  const VideoMetadataCollaboratorsInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collaborators = ref.watch(
      videoEditorProvider.select((s) => s.collaboratorPubkeys),
    );

    final collaboratorNames = collaborators
        .map((pubkey) {
          final name = ref
              .watch(userProfileReactiveProvider(pubkey))
              .value
              ?.bestDisplayName;
          return name ?? '';
        })
        .where((name) => name.isNotEmpty)
        .join(', ');

    return VideoMetadataSelectionTile(
      onTap: () => _addCollaborator(context, ref),
      semanticsLabel: context.l10n.videoMetadataAddCollaboratorSemanticLabel,
      labelText: context.l10n.videoMetadataCollaboratorsLabel,
      value: collaboratorNames,
    );
  }

  Future<void> _addCollaborator(BuildContext context, WidgetRef ref) async {
    final editorState = ref.read(videoEditorProvider);
    final viewerPubkey = ref.read(authServiceProvider).currentPublicKeyHex;

    // Confirmed collaborators shown as pre-selected chips in the picker.
    final confirmedProfiles = editorState.collaboratorPubkeys
        .map((k) => ref.read(userProfileReactiveProvider(k)).value)
        .nonNulls
        .toList();

    final result = await showUserPickerSheet(
      context,
      filterMode: UserPickerFilterMode.mutualFollowsOnly,
      title: context.l10n.videoMetadataCollaboratorsLabel,
      searchText: context.l10n.videoMetadataMutualFollowersSearchText,
      maxCount: VideoEditorConstants.maxCollaborators,
      initialSelectedProfiles: confirmedProfiles,
      excludeViewerPubkey: viewerPubkey,
    );

    if (result == null || !context.mounted) return;

    final notifier = ref.read(videoEditorProvider.notifier);
    final confirmedPubkeys = editorState.collaboratorPubkeys;
    final preselectedPubkeys = {for (final p in confirmedProfiles) p.pubkey};
    final resultPubkeys = {for (final p in result) p.pubkey};
    final effectiveResultPubkeys = computeEffectiveCollaboratorResultPubkeys(
      confirmedPubkeys: confirmedPubkeys,
      preselectedPubkeys: preselectedPubkeys,
      pickerResultPubkeys: resultPubkeys,
      viewerPubkey: viewerPubkey,
    );

    // Remove confirmed collaborators that were deselected in the picker.
    for (final pubkey in confirmedPubkeys) {
      if (!effectiveResultPubkeys.contains(pubkey)) {
        notifier.removeCollaborator(pubkey);
      }
    }

    // Confirm newly selected pubkeys. Mutual-follow is already guaranteed
    // by the picker's mutualFollowsOnly filter (verified at sheet open time).
    for (final pubkey in effectiveResultPubkeys) {
      if (confirmedPubkeys.contains(pubkey)) continue;
      notifier.addCollaborator(pubkey);
    }
  }
}
