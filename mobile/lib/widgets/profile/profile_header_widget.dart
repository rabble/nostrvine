// ABOUTME: Profile header widget showing avatar, stats, name, and bio
// ABOUTME: Reusable between own profile and others' profile screens

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
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
    final profilePictureUrl = profile?.picture ?? avatarUrlHint;
    final displayName = profile?.bestDisplayName ?? displayNameHint;
    final hasCustomName =
        profile?.name?.isNotEmpty == true ||
        profile?.displayName?.isNotEmpty == true ||
        displayNameHint?.isNotEmpty == true;
    final nip05 = profile?.displayNip05;
    final about = profile?.about;
    final authService = ref.watch(authServiceProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // Setup profile banner for new users with default names
          // (only on own profile)
          if (isOwnProfile && !hasCustomName && onSetupProfile != null)
            _SetupProfileBanner(onSetup: onSetupProfile!),

          // Secure account banner for anonymous users (only on own profile)
          // Only shown when headless auth feature is enabled
          if (isOwnProfile && authService.isAnonymous)
            _IdentityNotRecoverableBanner(),

          // Profile picture and stats row
          Row(
            children: [
              // Profile picture
              UserAvatar(imageUrl: profilePictureUrl, name: null, size: 88),

              const SizedBox(width: 20),

              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ProfileStatColumn(
                      count: videoCount,
                      label: 'Videos',
                      isLoading: false,
                      onTap: null, // Videos aren't tappable
                    ),
                    ProfileFollowersStat(
                      pubkey: userIdHex,
                      displayName: displayName,
                    ),
                    ProfileFollowingStat(
                      pubkey: userIdHex,
                      displayName: displayName,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Name and bio
          _ProfileNameAndBio(
            profile: profile,
            userIdHex: userIdHex,
            nip05: nip05,
            about: about,
            displayNameHint: displayNameHint,
          ),
        ],
      ),
    );
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
          Icon(Icons.person_add, color: VineTheme.whiteText, size: 24),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [VineTheme.vineGreen, Color(0xFF2D8B6F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: VineTheme.whiteText, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Secure Your Account', style: VineTheme.titleSmallFont()),
                const SizedBox(height: 4),
                Text(
                  'Add email & password to recover your account on any device',
                  style: VineTheme.bodySmallFont(
                    color: VineTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
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
          ),
        ],
      ),
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
    this.displayNameHint,
  });

  final UserProfile? profile;
  final String userIdHex;
  final String? nip05;
  final String? about;
  final String? displayNameHint;

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
          _UniqueIdentifier(userIdHex: userIdHex, nip05: nip05),
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
class _UniqueIdentifier extends StatelessWidget {
  const _UniqueIdentifier({required this.userIdHex, required this.nip05});

  final String userIdHex;
  final String? nip05;

  @override
  Widget build(BuildContext context) {
    final displayText = (nip05 != null && nip05!.isNotEmpty)
        ? nip05!
        : NostrKeyUtils.encodePubKey(userIdHex);
    final npub = NostrKeyUtils.encodePubKey(userIdHex);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            displayText,
            style: VineTheme.bodyMediumFont(color: VineTheme.vineGreen),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: () => ClipboardUtils.copy(
              context,
              npub,
              message: 'Unique ID copied to clipboard',
            ),
            child: SvgPicture.asset(
              'assets/icon/copy.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                VineTheme.vineGreen,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// About/bio text display.
class _AboutText extends StatelessWidget {
  const _AboutText({required this.about});

  final String about;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      about,
      style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
    );
  }
}
