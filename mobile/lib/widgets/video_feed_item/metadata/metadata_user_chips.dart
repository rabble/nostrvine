// ABOUTME: User chip sections for the metadata expanded sheet.
// ABOUTME: Creator, Collaborators, Inspired By, and Reposted By sections
// ABOUTME: using tappable chips that navigate to user profiles.

import 'dart:async';

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_collaborator_status/video_collaborator_status_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/video_reposters_cubit.dart';

/// Whether every chip in [pubkeys] already knows the name it will render.
///
/// [_TappableUserChip] falls back to a generated name while its profile
/// loads, so a row shown before the profiles settle swaps every label — and
/// reflows itself around the new widths — a moment later. Sections that can
/// afford to arrive late hold their reveal until this is true.
///
/// Every provider is watched unconditionally so the rebuild arrives for
/// whichever profile resolves last.
bool _namesSettled(WidgetRef ref, List<String> pubkeys) {
  final profiles = [
    for (final pubkey in pubkeys) ref.watch(fetchUserProfileProvider(pubkey)),
  ];
  return profiles.every((profile) => profile.hasValue || profile.hasError);
}

const _nameRevealGrace = Duration(seconds: 1);

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
/// Renders nothing while the resulting list is empty.
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
/// can exercise every render branch without standing up a `BlocProvider` or
/// a mock repository. A `ProviderScope` is still required: the chip names
/// come from [fetchUserProfileProvider].
@visibleForTesting
class MetadataCollaboratorsSectionBody extends ConsumerStatefulWidget {
  const MetadataCollaboratorsSectionBody({required this.visibility, super.key});

  final CollaboratorVisibility visibility;

  @override
  ConsumerState<MetadataCollaboratorsSectionBody> createState() =>
      _MetadataCollaboratorsSectionBodyState();
}

class _MetadataCollaboratorsSectionBodyState
    extends ConsumerState<MetadataCollaboratorsSectionBody> {
  List<String> _waitingFor = const [];
  bool _graceElapsed = false;
  Timer? _graceTimer;

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.visibility.visiblePubkeys;
    final namesSettled = _namesSettled(ref, visible);
    final canReveal = visible.isNotEmpty && (namesSettled || _graceElapsed);

    _syncGraceTimer(visible, namesSettled);

    // A tagged collaborator stays hidden until their confirmation status
    // resolves, so this section arrives late on videos that have one. Profile
    // names get a short grace window to avoid common label reflows without
    // hiding the whole section behind network tails.
    return AnimatedReveal(
      child: canReveal
          ? MetadataSection(
              label: context.l10n.metadataCollaboratorsLabel,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final pubkey in visible)
                    _TappableUserChip(
                      pubkey: pubkey,
                      isPending: widget.visibility.isPendingForInviter(pubkey),
                    ),
                ],
              ),
            )
          : null,
    );
  }

  void _syncGraceTimer(List<String> visible, bool namesSettled) {
    if (visible.isEmpty || namesSettled) {
      _cancelGraceTimer();
      _waitingFor = visible;
      _graceElapsed = false;
      return;
    }

    if (_samePubkeys(_waitingFor, visible) &&
        (_graceTimer != null || _graceElapsed)) {
      return;
    }

    _graceTimer?.cancel();
    _waitingFor = List.unmodifiable(visible);
    _graceElapsed = false;
    _graceTimer = Timer(_nameRevealGrace, () {
      if (!mounted || !_samePubkeys(_waitingFor, visible)) return;
      setState(() {
        _graceElapsed = true;
        _graceTimer = null;
      });
    });
  }

  void _cancelGraceTimer() {
    _graceTimer?.cancel();
    _graceTimer = null;
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
/// Renders nothing while no reposters are found.
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
          return _RepostedByContent(
            pubkeys: video.reposterPubkeys ?? [],
            video: video,
          );
        }

        return _RepostedByContent(pubkeys: allPubkeys, video: video);
      },
    );
  }
}

/// Content widget for the Reposted-by section.
///
/// Shows at most [_maxVisibleReposters] chips and hands the rest to the
/// reposters list screen. A popular video can be reposted thousands of
/// times, and every chip resolves its own profile — rendering the full set
/// would fire a profile fetch per reposter and lay them all out at once.
///
/// Renders nothing until the first capped set of chip names has resolved,
/// and while [pubkeys] is empty. The reposters resolve from a relay
/// round-trip, so the section is revealed through an [AnimatedReveal] rather
/// than snapping the sections below it down on arrival.
class _RepostedByContent extends ConsumerStatefulWidget {
  const _RepostedByContent({required this.pubkeys, required this.video});

  /// Roughly three rows of chips on a phone — nine came out at five.
  ///
  /// Not an exact row count: chip width follows the display name, and those
  /// resolve per chip after this has already been laid out.
  static const _maxVisibleReposters = 5;

  final List<String> pubkeys;
  final VideoEvent video;

  @override
  ConsumerState<_RepostedByContent> createState() => _RepostedByContentState();
}

class _RepostedByContentState extends ConsumerState<_RepostedByContent> {
  /// The last capped set whose chip names had all resolved.
  ///
  /// Feed consolidation can pre-populate fewer reposters than the cap, so a
  /// relay answer widens a row that is already on screen. Re-gating the whole
  /// section on the widened set would pull it back down to nothing while the
  /// new profiles load — a bigger jump than the one the gate exists to
  /// prevent. The row keeps rendering what it already revealed until the
  /// wider set has settled too.
  List<String> _revealed = const [];
  List<String> _waitingFor = const [];
  bool _graceElapsed = false;
  Timer? _graceTimer;

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.pubkeys
        .take(_RepostedByContent._maxVisibleReposters)
        .toList();
    final namesSettled = _namesSettled(ref, candidate);
    // A derived cache, not a rebuild trigger — this build already carries the
    // resolved names, so there is nothing to schedule.
    if (namesSettled || (_revealed.isEmpty && _graceElapsed)) {
      _revealed = candidate;
    }
    _syncGraceTimer(candidate, namesSettled);
    final visible = _revealed;
    final hiddenCount = widget.pubkeys.length - candidate.length;

    return AnimatedReveal(
      child: visible.isEmpty
          ? null
          : MetadataSection(
              label: context.l10n.metadataRepostedByLabel,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final pubkey in visible)
                    _TappableUserChip(pubkey: pubkey),
                  if (hiddenCount > 0)
                    _MoreRepostersChip(count: hiddenCount, video: widget.video),
                ],
              ),
            ),
    );
  }

  void _syncGraceTimer(List<String> candidate, bool namesSettled) {
    if (candidate.isEmpty || namesSettled || _revealed.isNotEmpty) {
      _cancelGraceTimer();
      _waitingFor = candidate;
      _graceElapsed = false;
      return;
    }

    if (_samePubkeys(_waitingFor, candidate) &&
        (_graceTimer != null || _graceElapsed)) {
      return;
    }

    _graceTimer?.cancel();
    _waitingFor = List.unmodifiable(candidate);
    _graceElapsed = false;
    _graceTimer = Timer(_nameRevealGrace, () {
      if (!mounted || !_samePubkeys(_waitingFor, candidate)) return;
      setState(() {
        _graceElapsed = true;
        _graceTimer = null;
      });
    });
  }

  void _cancelGraceTimer() {
    _graceTimer?.cancel();
    _graceTimer = null;
  }
}

bool _samePubkeys(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Button that opens the full reposters list for [video].
///
/// [DivineButtonSize.small] paints a 40px pill with the same 16px radius and
/// 16/8 padding as [_TappableUserChip], so it sits on the chips' baseline
/// while its outlined variant reads as an action rather than a person. The
/// row centres its children because this carries a 4px tap-target halo the
/// chips do not.
class _MoreRepostersChip extends StatelessWidget {
  const _MoreRepostersChip({required this.count, required this.video});

  final int count;
  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: context.l10n.metadataMoreReposters(count),
      type: DivineButtonType.secondary,
      size: DivineButtonSize.small,
      onPressed: () => _openRepostersList(context),
    );
  }

  void _openRepostersList(BuildContext context) {
    final addressableId = video.addressableId;
    // Dismiss the sheet first, then navigate from the root navigator context
    // — the same handoff every other destination in this sheet uses. Both the
    // router lookup and the push run against the host context, which is
    // outside the modal's widget tree.
    final hostContext = Navigator.of(context, rootNavigator: true).context;
    final location = GoRouter.of(hostContext).namedLocation(
      VideoEngagementListScreen.repostersRouteName,
      pathParameters: {'eventId': video.id},
      queryParameters: addressableId == null ? const {} : {'a': addressableId},
    );
    Navigator.of(context).pop();
    // Defer to the next frame so the modal route's pop has settled in the
    // route stack before we push the destination route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hostContext.mounted) return;
      hostContext.pushWithVideoPause<void>(location);
    });
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
        color: context.vineColors.surfaceContainer,
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
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
          if (isPending)
            Text(
              context.l10n.videoCollaboratorPendingDecoration,
              style: VineTheme.labelSmallFont(
                color: context.vineColors.onSurfaceMuted,
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
