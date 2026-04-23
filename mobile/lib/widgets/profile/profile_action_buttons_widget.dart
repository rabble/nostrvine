// ABOUTME: Action buttons widget for profile page (library, share, follow)
// ABOUTME: Shows different buttons for own profile vs other user profiles

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/widgets/profile/follow_from_profile_button.dart';

/// Action buttons shown on profile page.
///
/// Different buttons shown for own profile vs other user profiles.
/// For other profiles, button order changes based on follow state:
/// - Not following: [Follow] [Message] [Share]
/// - Following:     [Message] [Following] [Share]
///
/// Creates [MyFollowingBloc] for other profiles so both the follow button
/// and the row ordering react to the same optimistic state change instantly.
class ProfileActionButtons extends ConsumerWidget {
  const ProfileActionButtons({
    required this.userIdHex,
    required this.isOwnProfile,
    this.displayName,
    this.onEditProfile,
    this.onOpenClips,
    this.onMessageUser,
    this.onShareProfile,
    this.onBlockedTap,
    super.key,
  });

  final String userIdHex;
  final bool isOwnProfile;

  /// Display name for unfollow confirmation (required when not own profile).
  final String? displayName;
  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenClips;
  final VoidCallback? onMessageUser;
  final VoidCallback? onShareProfile;

  /// Callback when the Blocked button is tapped.
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isOwnProfile) {
      return _ActionButtonsRow(children: _buildOwnProfileButtons(context));
    }

    final followRepository = ref.watch(followRepositoryProvider);
    final contentBlocklistRepository = ref.watch(
      contentBlocklistRepositoryProvider,
    );
    final nostrClient = ref.watch(nostrServiceProvider);

    // Watch blocklist version to trigger rebuilds when block/unblock occurs
    ref.watch(blocklistVersionProvider);

    final isBlocked = contentBlocklistRepository.isBlocked(userIdHex);
    final isBlockedByThem = contentBlocklistRepository.hasBlockedUs(userIdHex);

    // Create MyFollowingBloc at this level so both the follow button
    // and the row ordering share the same optimistic state.
    return BlocProvider(
      create: (_) => MyFollowingBloc(
        followRepository: followRepository,
        contentBlocklistRepository: contentBlocklistRepository,
      )..add(const MyFollowingListLoadRequested()),
      child: _OtherProfileButtons(
        userIdHex: userIdHex,
        displayName: displayName,
        currentUserPubkey: nostrClient.publicKey,
        isBlocked: isBlocked,
        isBlockedByThem: isBlockedByThem,
        onMessageUser: onMessageUser,
        onShareProfile: onShareProfile,
        onBlockedTap: onBlockedTap,
      ),
    );
  }

  List<Widget> _buildOwnProfileButtons(BuildContext context) {
    return [
      Expanded(
        child: DivineButton(
          key: const Key('library-button'),
          expanded: true,
          leadingIcon: .filmSlate,
          type: .secondary,
          size: .small,
          label: context.l10n.profileMyLibraryLabel,
          onPressed: onOpenClips,
        ),
      ),
      DivineIconButton(
        icon: .pencilSimpleLine,
        type: .secondary,
        size: .small,
        onPressed: onEditProfile,
      ),
      DivineIconButton(
        icon: .shareFat,
        type: .secondary,
        size: .small,
        onPressed: onShareProfile,
      ),
    ];
  }
}

class _ActionButtonsRow extends StatelessWidget {
  const _ActionButtonsRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      child: Row(spacing: 6, children: children),
    );
  }
}

/// Other-profile buttons that reorder based on [MyFollowingBloc] state.
///
/// Uses [BlocSelector] on the bloc provided by [ProfileActionButtons]
/// so the reorder happens in the same frame as the follow button's
/// visual state change.
class _OtherProfileButtons extends StatelessWidget {
  const _OtherProfileButtons({
    required this.userIdHex,
    required this.displayName,
    required this.currentUserPubkey,
    required this.isBlocked,
    required this.isBlockedByThem,
    required this.onMessageUser,
    required this.onShareProfile,
    required this.onBlockedTap,
  });

  final String userIdHex;
  final String? displayName;
  final String? currentUserPubkey;
  final bool isBlocked;
  final bool isBlockedByThem;
  final VoidCallback? onMessageUser;
  final VoidCallback? onShareProfile;
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocSelector<MyFollowingBloc, MyFollowingState, bool>(
      selector: (state) => state.isFollowing(userIdHex),
      builder: (context, isFollowing) {
        final followButton = FollowFromProfileButtonView(
          pubkey: userIdHex,
          displayName: displayName ?? l10n.profileUserFallback,
          currentUserPubkey: currentUserPubkey,
          isBlocked: isBlocked,
          isBlockedByThem: isBlockedByThem,
          onBlockedTap: onBlockedTap,
        );

        final shareButton = DivineIconButton(
          icon: .shareFat,
          type: .secondary,
          size: .small,
          onPressed: onShareProfile,
        );

        final List<Widget> children;

        if (isFollowing) {
          // Following: [Message (expanded)] [Following] [Share]
          children = [
            Expanded(
              child: DivineButton(
                expanded: true,
                leadingIcon: .envelopeSimple,
                type: .secondary,
                size: .small,
                label: l10n.profileMessageLabel,
                onPressed: onMessageUser,
              ),
            ),
            followButton,
            shareButton,
          ];
        } else {
          // Not following: [Follow (expanded)] [Message (icon)] [Share]
          children = [
            Expanded(child: followButton),
            DivineButton(
              leadingIcon: .envelopeSimple,
              type: .secondary,
              size: .small,
              label: '',
              onPressed: onMessageUser,
            ),
            shareButton,
          ];
        }

        return _ActionButtonsRow(children: children);
      },
    );
  }
}
