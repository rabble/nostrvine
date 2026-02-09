// ABOUTME: Input widget for setting "Inspired By" attribution on videos
// ABOUTME: Supports two modes: reference a specific video (a-tag) or
// ABOUTME: reference a creator (NIP-27 npub in content)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';

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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          // Section label
          Text(
            // TODO(l10n): Replace with context.l10n
            //   when localization is added.
            'Inspired by',
            style: VineTheme.bodyFont(
              color: VineTheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.45,
              letterSpacing: 0.5,
            ),
          ),

          // Show current attribution or add button
          if (hasInspiredBy)
            _InspiredByDisplay(
              inspiredByNpub: inspiredByNpub,
              inspiredByVideo: inspiredByVideo,
            )
          else
            _AddInspiredByButton(
              onPressed: () => _selectInspiredByPerson(context, ref),
            ),
        ],
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
      // TODO(l10n): Replace with context.l10n
      //   when localization is added.
      title: 'Inspired by',
    );

    if (profile == null || !context.mounted) return;

    // Check if the user has muted us
    final blocklistService = ref.read(contentBlocklistServiceProvider);
    if (blocklistService.hasMutedUs(profile.pubkey)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // TODO(l10n): Replace with context.l10n
          //   when localization is added.
          content: Text('This creator cannot be referenced.'),
          backgroundColor: VineTheme.cardBackground,
        ),
      );
      return;
    }

    // Convert hex pubkey to npub for NIP-27 content reference
    final npub = NostrKeyUtils.encodePubKey(profile.pubkey);
    ref.read(videoEditorProvider.notifier).setInspiredByPerson(npub);
  }
}

/// Displays the current "Inspired By" attribution with a remove
/// button.
class _InspiredByDisplay extends ConsumerWidget {
  const _InspiredByDisplay({this.inspiredByNpub, this.inspiredByVideo});

  final String? inspiredByNpub;
  final InspiredByInfo? inspiredByVideo;

  /// Extracts the pubkey for fetching the profile.
  String? get _pubkey {
    if (inspiredByVideo != null) {
      return inspiredByVideo!.creatorPubkey;
    }
    // inspiredByNpub is an npub - we need to look it up
    // For display purposes we use it directly
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If we have a pubkey from the video reference, fetch profile
    final pubkey = _pubkey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: VineTheme.cardBackground,
      ),
      child: Row(
        children: [
          // Avatar and name
          if (pubkey != null)
            _InspiredByProfileInfo(pubkey: pubkey)
          else if (inspiredByNpub != null)
            _InspiredByNpubInfo(npub: inspiredByNpub!),

          const Spacer(),

          // Remove button
          Semantics(
            // TODO(l10n): Replace with context.l10n
            //   when localization is added.
            label: 'Remove inspired by',
            button: true,
            child: GestureDetector(
              onTap: () =>
                  ref.read(videoEditorProvider.notifier).clearInspiredBy(),
              child: SizedBox(
                width: 20,
                height: 20,
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

/// Shows profile info when we have a hex pubkey (from video ref).
class _InspiredByProfileInfo extends ConsumerWidget {
  const _InspiredByProfileInfo({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fetchUserProfileProvider(pubkey));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(
          imageUrl: profileAsync.value?.picture,
          name: profileAsync.value?.bestDisplayName,
          size: 32,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // TODO(l10n): Replace with context.l10n
              //   when localization is added.
              'Inspired by',
              style: VineTheme.bodyFont(
                color: VineTheme.onSurfaceMuted,
                fontSize: 11,
                height: 1.27,
              ),
            ),
            Text(
              profileAsync.value?.bestDisplayName ??
                  '${pubkey.substring(0, 12)}...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.bodyFont(
                color: VineTheme.whiteText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.43,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shows npub info when we only have an npub (person reference).
class _InspiredByNpubInfo extends StatelessWidget {
  const _InspiredByNpubInfo({required this.npub});

  final String npub;

  @override
  Widget build(BuildContext context) {
    // Display truncated npub with ellipsis
    final display = npub.length > 20
        ? '${npub.substring(0, 10)}...${npub.substring(npub.length - 8)}'
        : npub;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const UserAvatar(size: 32),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // TODO(l10n): Replace with context.l10n
              //   when localization is added.
              'Inspired by',
              style: VineTheme.bodyFont(
                color: VineTheme.onSurfaceMuted,
                fontSize: 11,
                height: 1.27,
              ),
            ),
            Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.bodyFont(
                color: VineTheme.whiteText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.43,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Button to add an "Inspired By" reference.
class _AddInspiredByButton extends StatelessWidget {
  const _AddInspiredByButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: VineTheme.onSurfaceMuted,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: const Icon(
              Icons.add,
              color: VineTheme.onSurfaceMuted,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            // TODO(l10n): Replace with context.l10n
            //   when localization is added.
            'Add inspiration credit',
            style: VineTheme.bodyFont(
              color: VineTheme.onSurfaceMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
