// ABOUTME: Profile header widget showing avatar, stats, name, and bio
// ABOUTME: Reusable between own profile and others' profile screens

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/profile/profile_followers_stat.dart';
import 'package:openvine/widgets/profile/profile_following_stat.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

/// Profile header widget displaying avatar, stats, name, and bio.
class ProfileHeaderWidget extends ConsumerWidget {
  const ProfileHeaderWidget({
    required this.userIdHex,
    required this.isOwnProfile,
    required this.videoCount,
    required this.profileStatsAsync,
    this.onSetupProfile,
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

  /// Async value containing profile stats (video count, etc.).
  final AsyncValue<ProfileStats> profileStatsAsync;

  /// Callback when "Set Up" button is tapped on the setup banner.
  /// Only shown for own profile with default name.
  final VoidCallback? onSetupProfile;

  /// Optional display name hint for users without Kind 0 profiles (e.g., classic Viners).
  final String? displayNameHint;

  /// Optional avatar URL hint for users without Kind 0 profiles.
  final String? avatarUrlHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch profile from relay (reactive)
    final profileAsync = ref.watch(fetchUserProfileProvider(userIdHex));
    final profile = profileAsync.value;

    // Use hints as fallbacks for users without Kind 0 profiles (e.g., classic Viners)
    // Check for both null AND empty string - some profiles have empty picture field
    final profilePictureUrl = (profile?.picture?.isNotEmpty == true)
        ? profile!.picture
        : avatarUrlHint;
    final displayName = profile?.bestDisplayName ?? displayNameHint;
    final hasCustomName =
        profile?.name?.isNotEmpty == true ||
        profile?.displayName?.isNotEmpty == true ||
        displayNameHint?.isNotEmpty == true;
    final nip05 = profile?.displayNip05;
    final about = profile?.about;
    final profileColor = profile?.profileBackgroundColor;
    final authService = ref.watch(authServiceProvider);

    // Watch auth state to rebuild when auth state changes
    // (e.g., after email verification completes)
    ref.watch(currentAuthStateProvider);
    final isAnonymous = authService.isAnonymous;

    // Use profile color as header background (like original Vine)
    // Color covers avatar/stats, then fades to dark for name/bio readability
    final hasProfileColor = profileColor != null;

    return Column(
      children: [
        // Colored section: avatar + stats with gradient fade at bottom
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            // Gradient from profile color to dark at the bottom
            gradient: hasProfileColor
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      profileColor,
                      profileColor,
                      VineTheme.backgroundColor,
                    ],
                    stops: const [0.0, 0.8, 1.0],
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 0, 16),
            child: Column(
              children: [
                // Setup profile banner for new users with default names
                // (only on own profile)
                if (isOwnProfile && !hasCustomName && onSetupProfile != null)
                  _SetupProfileBanner(onSetup: onSetupProfile!),

                // Secure account banner for anonymous users (only on own profile)
                // Only shown when headless auth feature is enabled
                if (isOwnProfile && isAnonymous)
                  const _IdentityNotRecoverableBanner(),

                // Profile picture and stats row
                Row(
                  children: [
                    // Profile picture
                    _ProfileAvatarWithColor(
                      imageUrl: profilePictureUrl,
                      profileColor: profileColor,
                    ),

                    const SizedBox(width: 20),

                    // Stats
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Flexible(
                            child: ProfileStatColumn(
                              count: videoCount,
                              label: 'Videos',
                              isLoading: false,
                            ),
                          ),
                          Flexible(
                            child: ProfileFollowersStat(
                              pubkey: userIdHex,
                              displayName: displayName,
                            ),
                          ),
                          Flexible(
                            child: ProfileFollowingStat(
                              pubkey: userIdHex,
                              displayName: displayName,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Dark section: name, link, and bio (always readable)
        Container(
          width: double.infinity,
          color: VineTheme.backgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: _ProfileNameAndBio(
              profile: profile,
              userIdHex: userIdHex,
              nip05: nip05,
              about: about,
              displayNameHint: displayNameHint,
              accentColor: profileColor,
              isOwnProfile: isOwnProfile,
            ),
          ),
        ),
      ],
    );
  }

  /// Get the profile color for this user (can be used by parent widgets for app bar)
  static Color? getProfileColor(UserProfile? profile) {
    return profile?.profileBackgroundColor;
  }
}

/// Setup profile banner shown for own profile with default name.
class _SetupProfileBanner extends StatelessWidget {
  const _SetupProfileBanner({required this.onSetup});

  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.purple, Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_add, color: VineTheme.whiteText, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete Your Profile',
                  style: VineTheme.titleSmallFont(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add your name, bio, and picture to get started',
                  style: VineTheme.bodySmallFont(
                    color: VineTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onSetup,
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.whiteText,
              foregroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Set Up',
              style: VineTheme.labelMediumFont(color: Colors.purple),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityNotRecoverableBanner extends StatelessWidget {
  const _IdentityNotRecoverableBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmailVerificationCubit, EmailVerificationState>(
      builder: (context, state) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: state.status == EmailVerificationStatus.failure
                  ? const [Color(0xFFD32F2F), Color(0xFFB71C1C)]
                  : const [VineTheme.vineGreen, Color(0xFF2D8B6F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildIcon(state),
              const SizedBox(width: 12),
              Expanded(child: _buildContent(state)),
              _buildAction(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIcon(EmailVerificationState state) {
    switch (state.status) {
      case EmailVerificationStatus.polling:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: VineTheme.whiteText,
          ),
        );
      case EmailVerificationStatus.failure:
        return const Icon(
          Icons.error_outline,
          color: VineTheme.whiteText,
          size: 24,
        );
      case EmailVerificationStatus.initial:
      case EmailVerificationStatus.success:
        return const Icon(Icons.security, color: VineTheme.whiteText, size: 24);
    }
  }

  Widget _buildContent(EmailVerificationState state) {
    switch (state.status) {
      case EmailVerificationStatus.polling:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verifying Email...', style: VineTheme.titleSmallFont()),
            const SizedBox(height: 4),
            Text(
              state.pendingEmail?.isNotEmpty == true
                  ? 'Check ${state.pendingEmail} for verification link'
                  : 'Waiting for email verification',
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
            ),
          ],
        );
      case EmailVerificationStatus.failure:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verification Failed', style: VineTheme.titleSmallFont()),
            const SizedBox(height: 4),
            Text(
              state.error ?? 'Please try again',
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      case EmailVerificationStatus.initial:
      case EmailVerificationStatus.success:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Secure Your Account', style: VineTheme.titleSmallFont()),
            const SizedBox(height: 4),
            Text(
              'Add email & password to recover your account on any device',
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
            ),
          ],
        );
    }
  }

  Widget _buildAction(BuildContext context, EmailVerificationState state) {
    switch (state.status) {
      case EmailVerificationStatus.polling:
        // No action needed — polling auto-expires after 15 minutes
        // (matching the server's token lifetime), then transitions to
        // failure state with a Retry button.
        return const SizedBox.shrink();
      case EmailVerificationStatus.failure:
        return ElevatedButton(
          onPressed: () => context.push(SecureAccountScreen.path),
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.whiteText,
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Retry',
            style: VineTheme.labelMediumFont(color: Colors.red),
          ),
        );
      case EmailVerificationStatus.initial:
      case EmailVerificationStatus.success:
        return ElevatedButton(
          onPressed: () => context.push(SecureAccountScreen.path),
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.whiteText,
            foregroundColor: VineTheme.vineGreen,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Register',
            style: VineTheme.labelMediumFont(color: VineTheme.vineGreen),
          ),
        );
    }
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 24),
            _AboutText(about: about!),
          ],
        ],
      ),
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
    final linkColor = accentColor ?? VineTheme.vineGreen;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                displayText,
                style: VineTheme.bodyMediumFont(color: linkColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () {
                  final profileUrl = buildProfileUrl(nip05, npub);
                  ClipboardUtils.copy(
                    context,
                    profileUrl,
                    message: 'Profile link copied',
                  );
                },
                child: SvgPicture.asset(
                  'assets/icon/copy.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(linkColor, BlendMode.srcIn),
                ),
              ),
            ),
          ],
        ),
        // NIP-05 verification failure is silently ignored for now.
        // TODO(#1658): surface NIP-05 verification errors once backend is fixed.
      ],
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
    final textStyle = VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted);

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

/// Profile avatar with optional light ring (when profile color is set).
///
/// Profile avatar widget for the header.
class _ProfileAvatarWithColor extends StatelessWidget {
  const _ProfileAvatarWithColor({required this.imageUrl, this.profileColor});

  final String? imageUrl;
  final Color? profileColor;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 88.0;
    return UserAvatar(imageUrl: imageUrl, size: avatarSize);
  }
}
