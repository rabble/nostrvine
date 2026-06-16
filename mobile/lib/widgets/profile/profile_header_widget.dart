// ABOUTME: Profile header widget showing avatar, stats, name, and bio
// ABOUTME: Reusable between own profile and others' profile screens

import 'dart:async';
import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/other_profile/other_profile_bloc.dart';
import 'package:openvine/features/people_lists/view/people_list_membership_indicator.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/widgets/followers_screen_router.dart';
import 'package:openvine/router/widgets/following_screen_router.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/badges/badge_repository.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/deferred_login_options_navigator.dart';
import 'package:openvine/utils/divine_login_banner_dismissal.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/profile/profile_action_buttons_widget.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_actions_sheet.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';
import 'package:openvine/widgets/profile/profile_website_row.dart';
import 'package:openvine/widgets/profile/verified_accounts_row.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:skeletonizer/skeletonizer.dart';

part 'profile_header_identity.dart';
part 'profile_header_media.dart';

/// Profile header widget displaying avatar, stats, name, and bio.
class ProfileHeaderWidget extends ConsumerStatefulWidget {
  const ProfileHeaderWidget({
    required this.userIdHex,
    required this.isOwnProfile,
    required this.videoCount,
    this.profile,
    this.profileStats,
    this.onEditProfile,
    this.onBack,
    this.onMore,
    this.displayNameHint,
    this.avatarUrlHint,
    this.displayName,
    this.onOpenClips,
    this.onMessageUser,
    this.onShareProfile,
    this.onBlockedTap,
    super.key,
  });

  /// The hex public key of the profile being displayed.
  final String userIdHex;

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  /// The number of videos loaded in the profile grid.
  final int videoCount;

  /// Optional profile owned by the parent widget.
  /// When provided, avoids a second profile fetch path.
  final UserProfile? profile;

  /// Optional cached stats owned by the parent widget.
  final ProfileStats? profileStats;

  /// Callback when edit profile is tapped (own profile only).
  final VoidCallback? onEditProfile;

  /// Callback for back navigation (other profiles only).
  final VoidCallback? onBack;

  /// Callback for more options menu (other profiles only).
  final VoidCallback? onMore;

  /// Optional display name hint for users without Kind 0 profiles (e.g., classic Viners).
  final String? displayNameHint;

  /// Optional avatar URL hint for users without Kind 0 profiles.
  final String? avatarUrlHint;

  /// Display name for unfollow confirmation (only used for other profiles).
  final String? displayName;

  /// Callback when "Clips" button is tapped (own profile only).
  final VoidCallback? onOpenClips;

  /// Callback when "Message" button is tapped (other profiles only).
  final VoidCallback? onMessageUser;

  /// Callback when share button is tapped.
  final void Function(BuildContext context)? onShareProfile;

  /// Callback when the Blocked button is tapped (other profiles only).
  final VoidCallback? onBlockedTap;

  @override
  ConsumerState<ProfileHeaderWidget> createState() =>
      _ProfileHeaderWidgetState();
}

class _ProfileHeaderWidgetState extends ConsumerState<ProfileHeaderWidget> {
  /// Maximum window during which the username/avatar render as a skeleton.
  /// After this elapses, the existing generated-name / identicon fallback
  /// kicks in even if the parent says the profile is still loading. This
  /// keeps users who genuinely have no Kind 0 from seeing an infinite
  /// shimmer (#4163).
  static const _identitySkeletonTimeout = Duration(seconds: 7);

  Timer? _identitySkeletonTimer;
  bool _identityTimeoutExpired = false;
  bool? _wasLoadingIdentity;
  final _deferredLoginOptionsNavigator = DeferredLoginOptionsNavigator();

  @override
  void dispose() {
    _identitySkeletonTimer?.cancel();
    _deferredLoginOptionsNavigator.dispose();
    super.dispose();
  }

  void _syncIdentitySkeletonTimer({required bool isLoading}) {
    if (_wasLoadingIdentity == isLoading) return;
    _wasLoadingIdentity = isLoading;
    _identitySkeletonTimer?.cancel();
    _identitySkeletonTimer = null;
    _identityTimeoutExpired = false;
    if (!isLoading) return;
    _identitySkeletonTimer = Timer(_identitySkeletonTimeout, () {
      if (mounted) setState(() => _identityTimeoutExpired = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final UserProfile? effectiveProfile;
    final bool isLoadingIdentity;
    if (widget.isOwnProfile) {
      // Project to (profile, isInitialOrLoading) so this widget rebuilds only
      // when the displayed profile or the genuine "still loading" signal
      // changes. Watching the whole state would also rebuild on isFresh /
      // extractedUsername / verifiedClaims transitions and on the
      // MyProfileError variant, none of which the header reads here.
      final selection = context
          .select<
            MyProfileBloc,
            ({UserProfile? profile, bool isInitialOrLoading})
          >((bloc) {
            final state = bloc.state;
            return (
              profile: switch (state) {
                MyProfileUpdated(:final profile) => profile,
                MyProfileLoaded(:final profile) => profile,
                MyProfileLoading(:final profile) => profile,
                _ => null,
              },
              isInitialOrLoading:
                  state is MyProfileInitial || state is MyProfileLoading,
            );
          });
      effectiveProfile = selection.profile ?? widget.profile;
      // Skeleton on the user's own profile is appropriate only while we
      // genuinely have nothing to show. As soon as a cached profile is
      // available, fall through to render the real identity. After
      // MyProfileError(notFound) the generated fallback is the truthful
      // steady state — don't skeleton it.
      isLoadingIdentity =
          effectiveProfile == null && selection.isInitialOrLoading;
    } else if (widget.profile != null) {
      effectiveProfile = widget.profile;
      isLoadingIdentity = false;
    } else {
      final asyncProfile = ref.watch(
        fetchUserProfileProvider(widget.userIdHex),
      );
      effectiveProfile = asyncProfile.value;
      isLoadingIdentity = asyncProfile.isLoading && asyncProfile.value == null;
    }

    final showIdentitySkeleton = isLoadingIdentity && !_identityTimeoutExpired;
    // Drive the skeleton timeout timer from a post-frame callback rather
    // than mutating timer state during build. The `_wasLoadingIdentity`
    // guard inside `_syncIdentitySkeletonTimer` keeps this idempotent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncIdentitySkeletonTimer(isLoading: isLoadingIdentity);
    });

    // Use hints as fallbacks for users without Kind 0 profiles (e.g., classic Viners)
    // Check for both null AND empty string - some profiles have empty picture field
    final profilePictureUrl = (effectiveProfile?.picture?.isNotEmpty == true)
        ? effectiveProfile!.picture
        : widget.avatarUrlHint;
    final hasCustomName =
        effectiveProfile?.name?.isNotEmpty == true ||
        effectiveProfile?.displayName?.isNotEmpty == true ||
        widget.displayNameHint?.isNotEmpty == true;
    final hasAnyProfileInfo =
        hasCustomName ||
        effectiveProfile?.picture?.isNotEmpty == true ||
        effectiveProfile?.about?.isNotEmpty == true ||
        effectiveProfile?.nip05?.isNotEmpty == true;
    final nip05 = effectiveProfile?.shortDisplayNip05;
    final about = effectiveProfile?.about;
    final profileColor = effectiveProfile?.profileBackgroundColor;
    final authService = ref.watch(authServiceProvider);

    // Watch auth state to rebuild when auth state changes
    // (e.g., after email verification completes, or after background RPC
    // upgrade resolves — the auth stream emits a nudge in both cases)
    ref.watch(currentAuthStateProvider);
    final isAnonymous = authService.isAnonymous;
    final hasExpiredSession = authService.hasExpiredOAuthSession;
    final isRpcUpgradeInProgress = authService.isRpcUpgradeInProgress;
    final prefs = ref.watch(sharedPreferencesProvider);
    final isDivineLoginBannerHidden = isDivineLoginBannerDismissed(
      prefs,
      widget.userIdHex,
    );

    // Show session expired bottom sheet for non-anonymous users, but only
    // after the background RPC upgrade has definitively resolved. Showing the
    // sheet while the silent refresh is still in flight would send the user
    // to the login screen even when the refresh ultimately succeeds.
    if (widget.isOwnProfile &&
        !isAnonymous &&
        hasExpiredSession &&
        !isRpcUpgradeInProgress &&
        !isDivineLoginBannerHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _showSessionExpiredSheet(context, ref, widget.userIdHex);
        }
      });
    }

    // Compute pending profile actions for the avatar badge
    final pendingActions = ProfileActionType.pending(
      isOwnProfile: widget.isOwnProfile,
      isAnonymous: isAnonymous,
      hasExpiredSession: hasExpiredSession,
      hasAnyProfileInfo: hasAnyProfileInfo,
    );

    // Banner is rendered separately by ProfileBannerLayer in profile_grid.dart
    // so it can be placed behind the safe area. This widget only renders the
    // foreground content (nav buttons, avatar, name, bio, stats) on a
    // transparent background — the banner shows through underneath.
    //
    // The NestedScrollView extends edge-to-edge (no SafeArea wrapper), so we
    // add safeAreaTop as top padding here to push nav buttons below the
    // status bar at rest.
    final safeAreaTop = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.only(top: safeAreaTop),
      child: Column(
        mainAxisSize: .min,
        children: [
          // Navigation buttons — always visible immediately.
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.isOwnProfile)
                  DivineIconButton(
                    icon: DivineIconName.gear,
                    type: DivineIconButtonType.ghostSecondary,
                    size: DivineIconButtonSize.small,
                    onPressed: () => context.push(SettingsScreen.path),
                  )
                else if (widget.onBack != null)
                  DivineIconButton(
                    icon: DivineIconName.caretLeft,
                    type: DivineIconButtonType.ghostSecondary,
                    size: DivineIconButtonSize.small,
                    onPressed: widget.onBack,
                  ),
                if (widget.onMore != null)
                  DivineIconButton(
                    icon: DivineIconName.dotsThree,
                    type: DivineIconButtonType.ghostSecondary,
                    size: DivineIconButtonSize.small,
                    onPressed: widget.onMore,
                  ),
              ],
            ),
          ),

          // Identity content. A single Skeletonizer wraps just the avatar
          // and the name/NIP-05/bio block so its shimmer + pointer
          // absorption stays scoped to the widgets actually loading. The
          // people-list pill, stats row, and action buttons sit as
          // siblings outside the skeleton so they remain tappable
          // during the loading window (#4183 review).
          Skeletonizer(
            enabled: showIdentitySkeleton,
            effect: vineSkeletonEffect,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centered avatar with action label pill
                Center(
                  child: _ProfileAvatarWithColor(
                    imageUrl: profilePictureUrl,
                    userIdHex: widget.userIdHex,
                    profileColor: profileColor,
                    pendingActions: pendingActions,
                    onActionTap: pendingActions.isNotEmpty
                        ? () => _showActionsSheet(context, pendingActions)
                        : null,
                  ),
                ),

                // Name, NIP-05, and bio
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                  child: _ProfileNameAndBio(
                    profile: effectiveProfile,
                    userIdHex: widget.userIdHex,
                    nip05: nip05,
                    about: about,
                    displayNameHint: widget.displayNameHint,
                    accentColor: profileColor,
                    isOwnProfile: widget.isOwnProfile,
                  ),
                ),
              ],
            ),
          ),
          if (!widget.isOwnProfile) ...[
            PeopleListMembershipIndicator(pubkey: widget.userIdHex),
            const SizedBox(height: 16),
          ],

          // Stats row owns its own loading skeleton (driven by
          // profileStats == null) and lives outside the identity
          // skeletonizer so it remains interactive.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ProfileStatsRow(
              userIdHex: widget.userIdHex,
              profileStats: widget.profileStats,
            ),
          ),

          ProfileActionButtons(
            userIdHex: widget.userIdHex,
            isOwnProfile: widget.isOwnProfile,
            displayName: widget.displayName,
            onEditProfile: widget.onEditProfile,
            onOpenClips: widget.onOpenClips,
            onMessageUser: widget.onMessageUser,
            onShareProfile: widget.onShareProfile,
            onBlockedTap: widget.onBlockedTap,
          ),
        ],
      ),
    );
  }

  void _showSessionExpiredSheet(
    BuildContext context,
    WidgetRef ref,
    String userIdHex,
  ) {
    final l10n = context.l10n;
    VineBottomSheetPrompt.show(
      context: context,
      sticker: DivineStickerName.skeletonKey,
      title: l10n.profileSessionExpired,
      subtitle: l10n.profileSignInToRestore,
      primaryButtonText: l10n.profileSignInButton,
      onPrimaryPressed: () async {
        Navigator.of(context).pop();
        final authService = ref.read(authServiceProvider);
        final refreshed = await authService.tryRefreshExpiredSession();
        if (!context.mounted) return;
        if (refreshed) return;

        _deferredLoginOptionsNavigator.goAfterUploadsComplete(
          context: context,
          publishBloc: context.read(),
        );
      },
      secondaryButtonText: l10n.profileMaybeLaterLabel,
      onSecondaryPressed: () async {
        final prefs = ref.read(sharedPreferencesProvider);
        await dismissDivineLoginBanner(prefs, userIdHex);
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  void _showActionsSheet(
    BuildContext context,
    List<ProfileActionType> actions,
  ) {
    VineBottomSheet.show<void>(
      context: context,
      scrollable: false,
      showHeaderDivider: false,
      body: ProfileActionsSheetContent(actions: actions),
    );
  }
}

/// Profile name, NIP-05, bio, and public key display.
///
/// The username shimmers when an enclosing [Skeletonizer] is enabled;
/// the NIP-05 / npub identifier and the bio body are wrapped in
/// [Skeleton.keep] so they stay interactive and unshimmered (#4163).
