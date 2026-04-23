// ABOUTME: Input widget for setting "Inspired By" attribution on videos
// ABOUTME: Supports two modes: reference a specific video (a-tag) or
// ABOUTME: reference a creator (NIP-27 npub in content)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_help_button.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_help_sheet.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_user_chip.dart';

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

    final hasInspiredBy = inspiredByNpub != null || inspiredByVideo != null;

    return Semantics(
      button: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: context.l10n.videoMetadataSetInspiredBySemanticLabel,
      child: InkWell(
        onTap: hasInspiredBy
            ? null
            : () => _selectInspiredByPerson(context, ref),
        child: Padding(
          padding: const .all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: hasInspiredBy ? 16 : 8,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.videoMetadataInspiredByLabel,
                    style: VineTheme.labelSmallFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  VideoMetadataHelpButton(
                    onTap: () => _showHelpDialog(context),
                    tooltip: context.l10n.videoMetadataInspiredByHelpTooltip,
                  ),
                ],
              ),

              // Show current attribution or add button.
              if (hasInspiredBy)
                _InspiredByDisplay(
                  inspiredByNpub: inspiredByNpub,
                  inspiredByVideo: inspiredByVideo,
                )
              else
                Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        context.l10n.videoMetadataInspiredByNone,
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
                          colorFilter: const ColorFilter.mode(
                            VineTheme.tabIndicatorGreen,
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
    );
  }

  void _showHelpDialog(BuildContext context) {
    VineBottomSheet.show(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: VideoMetadataHelpSheet(
        title: context.l10n.videoMetadataInspiredByLabel,
        message: context.l10n.videoMetadataInspiredByHelpMessage,
        assetPath: 'assets/stickers/trail_sign.svg',
      ),
    );
  }

  Future<void> _selectInspiredByPerson(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final profile = await showUserPickerSheet(
      context,
      filterMode: UserPickerFilterMode.allUsers,
      autoFocus: true,
      title: context.l10n.videoMetadataInspiredByLabel,
    );

    if (profile == null || !context.mounted) return;

    // Check if the user has muted us
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);
    if (blocklistRepository.hasMutedUs(profile.pubkey)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: .floating,
          content: DivineSnackbarContainer(
            label: context.l10n.videoMetadataCreatorCannotBeReferencedSnackbar,
          ),
        ),
      );
      return;
    }

    // Convert hex pubkey to npub for NIP-27 content reference
    final npub = NostrKeyUtils.encodePubKey(profile.pubkey);
    ref.read(videoEditorProvider.notifier).setInspiredByPerson(npub);
  }
}

/// Displays the current "Inspired By" attribution with a remove button.
class _InspiredByDisplay extends ConsumerWidget {
  const _InspiredByDisplay({this.inspiredByNpub, this.inspiredByVideo});

  final String? inspiredByNpub;
  final InspiredByInfo? inspiredByVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine which chip variant to show
    if (inspiredByVideo != null) {
      return VideoMetadataUserChip.fromPubkey(
        pubkey: inspiredByVideo!.creatorPubkey,
        removeLabel: context.l10n.videoMetadataRemoveInspiredBySemanticLabel,
        onRemove: () =>
            ref.read(videoEditorProvider.notifier).clearInspiredBy(),
      );
    }

    if (inspiredByNpub != null) {
      return VideoMetadataUserChip.fromNpub(
        npub: inspiredByNpub!,
        removeLabel: context.l10n.videoMetadataRemoveInspiredBySemanticLabel,
        onRemove: () =>
            ref.read(videoEditorProvider.notifier).clearInspiredBy(),
      );
    }

    // Should not happen, but return empty container as fallback
    return const SizedBox.shrink();
  }
}
