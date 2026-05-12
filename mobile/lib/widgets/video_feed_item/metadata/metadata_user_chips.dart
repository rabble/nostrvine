// ABOUTME: User chip sections for the metadata expanded sheet.
// ABOUTME: Creator, Collaborators, Inspired By, and Reposted By sections
// ABOUTME: using tappable chips that navigate to user profiles.

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_collaborator_status/video_collaborator_status_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/video_reposters_cubit.dart';

/// Creator section showing the video author as a tappable chip.
class MetadataCreatorSection extends StatelessWidget {
  const MetadataCreatorSection({required this.pubkey, super.key});

  final String pubkey;

  @override
  Widget build(BuildContext context) {
    return MetadataSection(
      label: context.l10n.metadataCreatorLabel,
      child: _TappableUserChip(pubkey: pubkey),
    );
  }
}

/// Collaborators section showing tappable user chips in a wrapping layout.
///
/// Hides the current user's chip when their local invite store says
/// `ignored` for this video. Pending collaborator chips are dimmed when
/// the current user is the video's creator.
///
/// Returns [SizedBox.shrink] when the resulting list is empty.
class MetadataCollaboratorsSection extends ConsumerWidget {
  const MetadataCollaboratorsSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!video.hasCollaborators) return const SizedBox.shrink();

    final pubkeys = video.collaboratorPubkeys;
    final repo = ref.watch(collaboratorConfirmationRepositoryProvider);
    final currentUserPubkey =
        ref.watch(authServiceProvider).currentPublicKeyHex ?? '';
    final videoAddress = video.addressableId;

    if (repo == null || videoAddress == null || currentUserPubkey.isEmpty) {
      return MetadataCollaboratorsSectionBody(
        visibility: CollaboratorVisibility.fallback(taggedPubkeys: pubkeys),
      );
    }

    return BlocProvider<VideoCollaboratorStatusCubit>(
      key: ValueKey((repo, videoAddress, Object.hashAll(pubkeys))),
      create: (_) => VideoCollaboratorStatusCubit(
        repository: repo,
        videoAddress: videoAddress,
        creatorPubkey: video.pubkey,
        taggedPubkeys: pubkeys,
      ),
      child: _CollaboratorsSectionStatusAware(
        video: video,
        pubkeys: pubkeys,
        currentUserPubkey: currentUserPubkey,
      ),
    );
  }
}

class _CollaboratorsSectionStatusAware extends StatelessWidget {
  const _CollaboratorsSectionStatusAware({
    required this.video,
    required this.pubkeys,
    required this.currentUserPubkey,
  });

  final VideoEvent video;
  final List<String> pubkeys;
  final String currentUserPubkey;

  @override
  Widget build(BuildContext context) {
    final statusByPubkey = context.select(
      (VideoCollaboratorStatusCubit c) => c.state.statusByPubkey,
    );
    return MetadataCollaboratorsSectionBody(
      visibility: CollaboratorVisibility(
        taggedPubkeys: pubkeys,
        statusByPubkey: statusByPubkey,
        currentUserPubkey: currentUserPubkey,
        creatorPubkey: video.pubkey,
      ),
    );
  }
}

/// Renders the collaborators section from a [CollaboratorVisibility].
///
/// Promoted to a top-level class with [visibleForTesting] so widget tests
/// can exercise every render branch without standing up a Riverpod
/// container, a `BlocProvider`, or a mock repository.
@visibleForTesting
class MetadataCollaboratorsSectionBody extends StatelessWidget {
  const MetadataCollaboratorsSectionBody({
    required this.visibility,
    super.key,
  });

  final CollaboratorVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final visible = visibility.visiblePubkeys;
    if (visible.isEmpty) return const SizedBox.shrink();

    return MetadataSection(
      label: context.l10n.metadataCollaboratorsLabel,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final pubkey in visible)
            _TappableUserChip(
              pubkey: pubkey,
              isPending: visibility.isPendingForInviter(pubkey),
            ),
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
    final pubkey = video.inspiredByCreatorPubkey;
    if (pubkey == null) return const SizedBox.shrink();

    return MetadataSection(
      label: context.l10n.metadataInspiredByLabel,
      child: _TappableUserChip(pubkey: pubkey),
    );
  }
}

/// Reposted-by section showing reposter user chips.
///
/// Reads reposter pubkeys from [VideoRepostersCubit] (provided by the
/// metadata sheet) and merges with any pre-populated
/// [VideoEvent.reposterPubkeys] from feed consolidation.
/// Returns [SizedBox.shrink] when no reposters are found.
class MetadataRepostedBySection extends StatelessWidget {
  const MetadataRepostedBySection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoRepostersCubit, VideoRepostersState>(
      builder: (context, state) {
        final allPubkeys = {
          ...?video.reposterPubkeys,
          ...state.pubkeys,
        }.toList();

        if (state.isLoading && allPubkeys.isEmpty) {
          return _RepostedByContent(pubkeys: video.reposterPubkeys ?? []);
        }

        return _RepostedByContent(pubkeys: allPubkeys);
      },
    );
  }
}

/// Content widget for the Reposted-by section.
///
/// Returns [SizedBox.shrink] when [pubkeys] is empty.
class _RepostedByContent extends StatelessWidget {
  const _RepostedByContent({required this.pubkeys});

  final List<String> pubkeys;

  @override
  Widget build(BuildContext context) {
    if (pubkeys.isEmpty) return const SizedBox.shrink();

    return MetadataSection(
      label: context.l10n.metadataRepostedByLabel,
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
  const _TappableUserChip({required this.pubkey, this.isPending = false});

  final String pubkey;
  final bool isPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fetchUserProfileProvider(pubkey));
    final name =
        profileAsync.value?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(pubkey);

    final chip = Container(
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
          if (isPending)
            Text(
              context.l10n.videoCollaboratorPendingDecoration,
              style: VineTheme.labelSmallFont(
                color: VineTheme.onSurfaceMuted,
              ),
            ),
        ],
      ),
    );

    final styled = isPending ? Opacity(opacity: 0.7, child: chip) : chip;

    return Semantics(
      button: true,
      label: context.l10n.profileChipTapHint(name),
      child: GestureDetector(
        onTap: () => _navigateToProfile(context),
        child: styled,
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
    // Defer to the next frame so the modal route's pop has settled in the
    // route stack before we push the destination route from the root
    // navigator's context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hostContext.mounted) return;
      hostContext.pushWithVideoPause(OtherProfileScreen.pathForNpub(npub));
    });
  }
}
