// ABOUTME: Profile header widget showing avatar, stats, name, and bio
// ABOUTME: Reusable between own profile and others' profile screens

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/widgets/followers_screen_router.dart';
import 'package:openvine/router/widgets/following_screen_router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/divine_login_banner_dismissal.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_actions_sheet.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

/// Profile header widget displaying avatar, stats, name, and bio.
class ProfileHeaderWidget extends ConsumerWidget {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserProfile? effectiveProfile;
    if (isOwnProfile) {
      final state = context.watch<MyProfileBloc>().state;
      effectiveProfile = switch (state) {
        MyProfileUpdated(:final profile) => profile,
        _ => null,
      };
    } else if (profile != null) {
      effectiveProfile = profile;
    } else {
      effectiveProfile = ref.watch(fetchUserProfileProvider(userIdHex)).value;
    }

    // Use hints as fallbacks for users without Kind 0 profiles (e.g., classic Viners)
    // Check for both null AND empty string - some profiles have empty picture field
    final profilePictureUrl = (effectiveProfile?.picture?.isNotEmpty == true)
        ? effectiveProfile!.picture
        : avatarUrlHint;
    final hasCustomName =
        effectiveProfile?.name?.isNotEmpty == true ||
        effectiveProfile?.displayName?.isNotEmpty == true ||
        displayNameHint?.isNotEmpty == true;
    final hasAnyProfileInfo =
        hasCustomName ||
        effectiveProfile?.picture?.isNotEmpty == true ||
        effectiveProfile?.about?.isNotEmpty == true ||
        effectiveProfile?.nip05?.isNotEmpty == true;
    final nip05 = effectiveProfile?.displayNip05;
    final about = effectiveProfile?.about;
    final profileColor = effectiveProfile?.profileBackgroundColor;
    final authService = ref.watch(authServiceProvider);

    // Watch auth state to rebuild when auth state changes
    // (e.g., after email verification completes)
    ref.watch(currentAuthStateProvider);
    final isAnonymous = authService.isAnonymous;
    final hasExpiredSession = authService.hasExpiredOAuthSession;
    final prefs = ref.watch(sharedPreferencesProvider);
    final isDivineLoginBannerHidden = isDivineLoginBannerDismissed(
      prefs,
      userIdHex,
    );

    // Show session expired bottom sheet for non-anonymous users
    if (isOwnProfile &&
        !isAnonymous &&
        hasExpiredSession &&
        !isDivineLoginBannerHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _showSessionExpiredSheet(context, ref, userIdHex);
        }
      });
    }

    // Compute pending profile actions for the avatar badge
    final pendingActions = ProfileActionType.pending(
      isOwnProfile: isOwnProfile,
      isAnonymous: isAnonymous,
      hasExpiredSession: hasExpiredSession,
      hasAnyProfileInfo: hasAnyProfileInfo,
    );

    final hasBannerImage = effectiveProfile?.hasBannerImage ?? false;
    final bannerUrl = hasBannerImage ? effectiveProfile!.banner : null;

    const bannerHeight = 334.0;

    final safeAreaTop = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: VineTheme.surfaceBackground,
      child: Stack(
        children: [
          // Background: banner image or color gradient (z-index 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ProfileBanner(
              bannerUrl: bannerUrl,
              profileColor: profileColor,
              height: bannerHeight,
            ),
          ),

          // Foreground: all profile content (z-index 1)
          Padding(
            padding: EdgeInsets.only(top: safeAreaTop),
            child: Column(
              children: [
                // Navigation buttons
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isOwnProfile)
                        DivineIconButton(
                          icon: DivineIconName.gear,
                          type: DivineIconButtonType.ghostSecondary,
                          size: DivineIconButtonSize.small,
                          onPressed: () => context.push(SettingsScreen.path),
                        )
                      else if (onBack != null)
                        DivineIconButton(
                          icon: DivineIconName.caretLeft,
                          type: DivineIconButtonType.ghostSecondary,
                          size: DivineIconButtonSize.small,
                          onPressed: onBack,
                        ),
                      if (isOwnProfile && onEditProfile != null)
                        DivineIconButton(
                          icon: DivineIconName.pencilSimpleLine,
                          type: DivineIconButtonType.ghostSecondary,
                          size: DivineIconButtonSize.small,
                          onPressed: onEditProfile,
                        )
                      else if (!isOwnProfile && onMore != null)
                        DivineIconButton(
                          icon: DivineIconName.dotsThree,
                          type: DivineIconButtonType.ghostSecondary,
                          size: DivineIconButtonSize.small,
                          onPressed: onMore,
                        ),
                    ],
                  ),
                ),

                // Centered avatar with action label pill
                Center(
                  child: _ProfileAvatarWithColor(
                    imageUrl: profilePictureUrl,
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
                    userIdHex: userIdHex,
                    nip05: nip05,
                    about: about,
                    displayNameHint: displayNameHint,
                    accentColor: profileColor,
                    isOwnProfile: isOwnProfile,
                  ),
                ),

                // Stats row: Followers | Following | Likes | Loops
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _ProfileStatsRow(
                    userIdHex: userIdHex,
                    profileStats: profileStats,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get the profile color for this user (can be used by parent widgets for app bar)
  static Color? getProfileColor(UserProfile? profile) {
    return profile?.profileBackgroundColor;
  }

  static void _showSessionExpiredSheet(
    BuildContext context,
    WidgetRef ref,
    String userIdHex,
  ) {
    VineBottomSheetPrompt.show(
      context: context,
      sticker: DivineStickerName.skeletonKey,
      title: 'Session Expired',
      subtitle: 'Sign in again to restore full access to your account.',
      primaryButtonText: 'Sign In',
      onPrimaryPressed: () async {
        Navigator.of(context).pop();
        final authService = ref.read(authServiceProvider);
        final refreshed = await authService.tryRefreshExpiredSession();
        if (context.mounted && !refreshed) {
          GoRouter.of(context).go(WelcomeScreen.loginOptionsPath);
        }
      },
      secondaryButtonText: 'Maybe Later',
      onSecondaryPressed: () async {
        final prefs = ref.read(sharedPreferencesProvider);
        await dismissDivineLoginBanner(prefs, userIdHex);
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  static void _showActionsSheet(
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
class _ProfileNameAndBio extends StatelessWidget {
  const _ProfileNameAndBio({
    required this.profile,
    required this.userIdHex,
    required this.nip05,
    required this.about,
    required this.isOwnProfile,
    this.displayNameHint,
    this.accentColor,
  });

  final UserProfile? profile;
  final String userIdHex;
  final String? nip05;
  final String? about;
  final bool isOwnProfile;
  final String? displayNameHint;

  /// Optional accent color (from profile color) for links/buttons.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (profile != null)
          UserName.fromUserProfile(
            profile!,
            style: VineTheme.titleLargeFont(),
          )
        else
          UserName.fromPubKey(
            userIdHex,
            style: VineTheme.titleLargeFont(),
            anonymousName: displayNameHint,
          ),
        _UniqueIdentifier(
          userIdHex: userIdHex,
          nip05: nip05,
          isOwnProfile: isOwnProfile,
          accentColor: accentColor,
        ),
        if (about != null && about!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AboutText(about: about!),
        ],
      ],
    );
  }
}

/// Unique identifier display (NIP-05 or full npub with ellipsis).
/// Uses profile accent color when available, falls back to vineGreen.
/// Shows warning for failed NIP-05 verification on own profile.
/// Hides unverified NIP-05s for other profiles (potential impersonation).
class _UniqueIdentifier extends ConsumerWidget {
  const _UniqueIdentifier({
    required this.userIdHex,
    required this.nip05,
    required this.isOwnProfile,
    this.accentColor,
  });

  final String userIdHex;
  final String? nip05;
  final bool isOwnProfile;

  /// Optional accent color (from profile color) for the link text and icon.
  final Color? accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNip05 = nip05 != null && nip05!.isNotEmpty;
    final npub = NostrKeyUtils.encodePubKey(userIdHex);
    const linkColor = VineTheme.vineGreen;

    // Watch NIP-05 verification status
    final verificationStatus = hasNip05
        ? ref
              .watch(nip05VerificationProvider(userIdHex))
              .whenOrNull(data: (status) => status)
        : null;

    final verificationFailed =
        verificationStatus == Nip05VerificationStatus.failed;

    // For other profiles: hide unverified NIP-05s (show npub instead)
    // For own profile: show with warning so user knows there's an issue
    final String displayText;
    if (hasNip05) {
      if (verificationFailed && !isOwnProfile) {
        // Don't show unverified NIP-05s for other users - potential impersonation
        displayText = npub;
      } else {
        displayText = nip05!;
      }
    } else {
      displayText = npub;
    }

    return GestureDetector(
      onTap: () {
        final verifiedNip05 = hasNip05 && !verificationFailed ? nip05 : null;
        final profileUrl = buildProfileUrl(verifiedNip05, npub);
        ClipboardUtils.copy(
          context,
          profileUrl,
          message: 'Profile link copied',
        );
      },
      child: Text(
        displayText,
        style: VineTheme.bodyMediumFont(color: linkColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Build a shareable profile URL.
///
/// If the user has a `.divine.video` NIP-05 subdomain (e.g. `_@thomas.divine.video`),
/// returns `https://thomas.divine.video`. Otherwise falls back to
/// `https://divine.video/profile/{npub}`.
@visibleForTesting
String buildProfileUrl(String? nip05, String npub) {
  if (nip05 != null && nip05.isNotEmpty) {
    // NIP-05 format: `_@username.divine.video` or `user@domain.com`
    final atIndex = nip05.indexOf('@');
    if (atIndex != -1) {
      final domain = nip05.substring(atIndex + 1);
      if (domain.endsWith('.divine.video')) {
        return 'https://$domain';
      }
    }
  }
  return 'https://divine.video/profile/$npub';
}

/// About/bio text display with expandable "Show more/less" functionality.
class _AboutText extends StatefulWidget {
  const _AboutText({required this.about});

  final String about;

  /// Maximum lines to show when collapsed.
  static const int _collapsedMaxLines = 3;

  @override
  State<_AboutText> createState() => _AboutTextState();
}

class _AboutTextState extends State<_AboutText> {
  bool _isExpanded = false;
  bool _needsExpansion = false;

  @override
  Widget build(BuildContext context) {
    final textStyle = VineTheme.bodyMediumFont(
      color: VineTheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure if text exceeds max lines
        final textSpan = TextSpan(text: widget.about, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: _AboutText._collapsedMaxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        _needsExpansion = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isExpanded)
              SelectableText(widget.about, style: textStyle)
            else
              Text(
                widget.about,
                style: textStyle,
                maxLines: _AboutText._collapsedMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            if (_needsExpansion)
              GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _isExpanded ? 'Show less' : 'Show more',
                    style: VineTheme.bodySmallFont(color: VineTheme.vineGreen),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The 334px background banner area. Shows a banner image, a color gradient,
/// or a plain dark background depending on what the profile provides.
class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({
    required this.height,
    this.bannerUrl,
    this.profileColor,
  });

  final double height;
  final String? bannerUrl;
  final Color? profileColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: background (image or color gradient)
          if (bannerUrl != null)
            Image.network(
              bannerUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: VineTheme.surfaceBackground),
            )
          else if (profileColor != null)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [profileColor!, profileColor!],
                ),
              ),
            )
          else
            const ColoredBox(color: VineTheme.surfaceBackground),

          // Layer 2: gradient scrim fading to bg/surface at the bottom
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  VineTheme.surfaceBackground.withValues(alpha: 0),
                  VineTheme.surfaceBackground,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stats row displaying Followers, Following, Likes, and Loops with dividers.
class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({
    required this.userIdHex,
    this.profileStats,
  });

  final String userIdHex;
  final ProfileStats? profileStats;

  @override
  Widget build(BuildContext context) {
    final hasFollowers = profileStats?.followers != null;
    final hasFollowing = profileStats?.following != null;
    final hasLikes = profileStats?.totalLikes != null;
    final hasLoops = profileStats?.totalViews != null;

    final columns = <Widget>[
      if (hasLoops)
        ProfileStatColumn(
          count: profileStats!.totalViews,
          label: 'Loops',
          isLoading: false,
        ),
      if (hasLikes)
        ProfileStatColumn(
          count: profileStats!.totalLikes,
          label: 'Likes',
          isLoading: false,
        ),
      if (hasFollowing)
        ProfileStatColumn(
          count: profileStats!.following,
          label: 'Following',
          isLoading: false,
          onTap: () => context.push(
            FollowingScreenRouter.pathForPubkey(userIdHex),
          ),
        ),
      if (hasFollowers)
        ProfileStatColumn(
          count: profileStats!.followers,
          label: 'Followers',
          isLoading: false,
          onTap: () => context.push(
            FollowersScreenRouter.pathForPubkey(userIdHex),
          ),
        ),
    ];

    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 0; i < columns.length; i++) ...[
            if (i > 0) const _StatDivider(),
            columns[i],
          ],
        ],
      ),
    );
  }
}

/// Vertical divider between stat columns.
class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 2,
      height: 44,
      child: ColoredBox(color: VineTheme.outlineMuted),
    );
  }
}

/// Profile avatar with optional action label overlapping the bottom edge.
///
/// When [pendingActions] is non-empty, a pill-shaped label (e.g. "Secure
/// your account") is centred below the avatar. A red count badge appears
/// on the label when more than one action is pending. Tapping either the
/// avatar or the label triggers [onActionTap].
class _ProfileAvatarWithColor extends StatelessWidget {
  const _ProfileAvatarWithColor({
    required this.imageUrl,
    this.profileColor,
    this.pendingActions = const [],
    this.onActionTap,
  });

  final String? imageUrl;
  final Color? profileColor;

  /// Ordered list of pending profile actions. The first action determines
  /// the label text and icon.
  final List<ProfileActionType> pendingActions;

  /// Called when the label or avatar is tapped.
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 144.0;
    final avatar = UserAvatar(imageUrl: imageUrl, size: avatarSize);

    if (pendingActions.isEmpty) return avatar;

    // The label overlaps the avatar bottom, so we need extra space below.
    return GestureDetector(
      onTap: onActionTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Reserve space for label overflow below the avatar.
          const SizedBox(width: avatarSize, height: avatarSize + 16),
          avatar,
          Positioned(
            bottom: 0,
            child: _ProfileActionLabel(
              action: pendingActions.first,
              badgeCount: pendingActions.length,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped label shown below the profile avatar for the highest-priority
/// pending action. Displays an icon and text matching the action type, with
/// an optional red badge when multiple actions are pending.
class _ProfileActionLabel extends StatelessWidget {
  const _ProfileActionLabel({
    required this.action,
    required this.badgeCount,
  });

  final ProfileActionType action;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (action) {
      ProfileActionType.secureAccount => (
        DivineIconName.lockSimple,
        'Secure your account',
      ),
      ProfileActionType.completeProfile => (
        DivineIconName.pencilSimple,
        'Complete your profile',
      ),
    };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          decoration: BoxDecoration(
            color: VineTheme.accentYellowBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0.4, 0.4),
                blurRadius: 0.6,
              ),
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              DivineIcon(
                icon: icon,
                size: 16,
                color: VineTheme.accentYellow,
              ),
              Text(
                label,
                style: VineTheme.titleSmallFont(
                  color: VineTheme.accentYellow,
                ),
              ),
            ],
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -4,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: VineTheme.error,
                borderRadius: BorderRadius.circular(1000),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount.toString(),
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 16 / 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
