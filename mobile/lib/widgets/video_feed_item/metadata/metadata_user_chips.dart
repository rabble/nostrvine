// ABOUTME: User chip sections for the metadata expanded sheet.
// ABOUTME: Creator, Collaborators, Inspired By, and Reposted By sections
// ABOUTME: using tappable chips that navigate to user profiles.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_reposters_provider.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_section.dart';

/// Creator section showing the video author as a tappable chip.
class MetadataCreatorSection extends StatelessWidget {
  const MetadataCreatorSection({required this.pubkey, super.key});

  final String pubkey;

  @override
  Widget build(BuildContext context) {
    return MetadataSection(
      label: 'Creator',
      child: Wrap(
        children: [
          _TappableUserChip(pubkey: pubkey),
        ],
      ),
    );
  }
}

/// Collaborators section showing tappable user chips in a wrapping layout.
///
/// Returns [SizedBox.shrink] when the video has no collaborators.
class MetadataCollaboratorsSection extends StatelessWidget {
  const MetadataCollaboratorsSection({
    required this.collaboratorPubkeys,
    super.key,
  });

  final List<String> collaboratorPubkeys;

  @override
  Widget build(BuildContext context) {
    if (collaboratorPubkeys.isEmpty) return const SizedBox.shrink();

    return MetadataSection(
      label: 'Collaborators',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final pubkey in collaboratorPubkeys)
            _TappableUserChip(pubkey: pubkey),
        ],
      ),
    );
  }
}

/// Inspired-by section showing the inspiring creator as a tappable chip.
///
/// Returns [SizedBox.shrink] when the video has no inspired-by attribution.
class MetadataInspiredBySection extends StatelessWidget {
  const MetadataInspiredBySection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    if (!video.hasInspiredBy) return const SizedBox.shrink();

    final pubkey = _resolveCreatorPubkey();
    if (pubkey == null || pubkey.isEmpty) return const SizedBox.shrink();

    return MetadataSection(
      label: 'Inspired by',
      child: Wrap(
        children: [
          _TappableUserChip(pubkey: pubkey),
        ],
      ),
    );
  }

  String? _resolveCreatorPubkey() {
    if (video.inspiredByVideo != null) {
      return video.inspiredByVideo!.creatorPubkey;
    }
    if (video.inspiredByNpub != null) {
      try {
        return NostrKeyUtils.decode(video.inspiredByNpub!);
      } catch (e) {
        Log.warning(
          'Failed to decode inspiredByNpub ${video.inspiredByNpub}: $e',
          name: 'MetadataInspiredBySection',
          category: LogCategory.ui,
        );
        return null;
      }
    }
    return null;
  }
}

/// Reposted-by section showing reposter user chips.
///
/// Fetches reposter pubkeys from the relay via [videoRepostersProvider] and
/// merges with any pre-populated [VideoEvent.reposterPubkeys] from feed
/// consolidation. Returns [SizedBox.shrink] when no reposters are found.
class MetadataRepostedBySection extends ConsumerWidget {
  const MetadataRepostedBySection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repostersAsync = ref.watch(videoRepostersProvider(video.id));

    return repostersAsync.when(
      data: (relayPubkeys) {
        final allPubkeys = {
          ...?video.reposterPubkeys,
          ...relayPubkeys,
        }.toList();
        return _buildSection(allPubkeys);
      },
      loading: () => _buildSection(video.reposterPubkeys ?? []),
      error: (_, _) => _buildSection(video.reposterPubkeys ?? []),
    );
  }

  Widget _buildSection(List<String> pubkeys) {
    if (pubkeys.isEmpty) return const SizedBox.shrink();

    return MetadataSection(
      label: 'Reposted by',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final pubkey in pubkeys) _TappableUserChip(pubkey: pubkey),
        ],
      ),
    );
  }
}

/// A chip showing a user's avatar and name that navigates to their profile.
///
/// Reuses the same visual style as [VideoMetadataUserChip] but without the
/// remove button, and adds tap-to-navigate behavior.
class _TappableUserChip extends ConsumerWidget {
  const _TappableUserChip({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fetchUserProfileProvider(pubkey));
    final name =
        profileAsync.value?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(pubkey);

    return GestureDetector(
      onTap: () => _navigateToProfile(context),
      child: Semantics(
        identifier: 'metadata_user_chip',
        button: true,
        label: '$name. Tap to view profile.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: VineTheme.surfaceContainer,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              UserAvatar(
                imageUrl: profileAsync.value?.picture,
                name: name,
                size: 24,
              ),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.titleSmallFont(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    final npub = normalizeToNpub(pubkey);
    if (npub == null) return;

    // Dismiss the sheet first, then navigate from the root navigator context.
    // GoRouter extensions can throw when called from inside a modal bottom
    // sheet (the router is not in the modal's widget tree).
    final hostContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    Future<void>.delayed(Duration.zero).then((_) {
      if (!hostContext.mounted) return;
      hostContext.push(OtherProfileScreen.pathForNpub(npub));
    });
  }
}
