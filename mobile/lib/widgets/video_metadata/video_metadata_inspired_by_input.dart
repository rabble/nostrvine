// ABOUTME: Input widget for setting "Inspired By" attribution on videos
// ABOUTME: Supports two modes: reference a specific video (a-tag) or
// ABOUTME: reference a creator (NIP-27 npub in content)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';

/// Input widget for setting "Inspired By" attribution.
///
/// Two modes:
/// - **Inspired by a creator**: stores npub, appended to content
///   as NIP-27 on publish.
/// - **Inspired by a video**: stores [InspiredByInfo] with
///   addressable event ID. (Future: video picker after creator
///   selection.)
class VideoMetadataInspiredByInput extends ConsumerWidget {
  /// Creates a video metadata inspired-by input widget.
  const VideoMetadataInspiredByInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspiredByNpub = ref.watch(
      videoEditorProvider.select((s) => s.inspiredByNpub),
    );
    final inspiredByVideo = ref.watch(
      videoEditorProvider.select((s) => s.inspiredByVideo),
    );

    final resolvedPubkey =
        inspiredByVideo?.creatorPubkey ?? npubToHexOrNull(inspiredByNpub);
    final currentProfile = resolvedPubkey != null
        ? ref.watch(userProfileReactiveProvider(resolvedPubkey)).value
        : null;
    return VideoMetadataSelectionTile(
      onTap: () => _selectInspiredByPerson(context, ref, currentProfile),
      semanticsLabel: context.l10n.videoMetadataSetInspiredBySemanticLabel,
      labelText: context.l10n.videoMetadataInspiredByLabel,
      value: currentProfile?.bestDisplayName ?? '',
    );
  }

  Future<void> _selectInspiredByPerson(
    BuildContext context,
    WidgetRef ref,
    UserProfile? currentProfile,
  ) async {
    final result = await showUserPickerSheet(
      context,
      filterMode: UserPickerFilterMode.allUsers,
      autoFocus: true,
      title: context.l10n.videoMetadataInspiredByLabel,
      initialSelectedProfiles: [?currentProfile],
    );
    if (result == null || !context.mounted) return;

    if (result.isEmpty) {
      ref.read(videoEditorProvider.notifier).clearInspiredBy();
      return;
    }

    final profile = result.first;

    // Check if the user has muted us
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);
    if (blocklistRepository.hasMutedUs(profile.pubkey)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoMetadataCreatorCannotBeReferencedSnackbar,
        ),
      );
      return;
    }

    // Convert hex pubkey to npub for NIP-27 content reference
    final npub = NostrKeyUtils.encodePubKey(profile.pubkey);
    ref.read(videoEditorProvider.notifier).setInspiredByPerson(npub);
  }
}
