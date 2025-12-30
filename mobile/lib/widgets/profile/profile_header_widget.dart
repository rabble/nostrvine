// ABOUTME: Profile header widget showing avatar, stats, name, bio, and npub
// ABOUTME: Reusable between own profile and others' profile screens

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/profile/profile_followers_stat.dart';
import 'package:openvine/widgets/profile/profile_following_stat.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

/// Profile header widget displaying avatar, stats, name, bio, and public key.
class ProfileHeaderWidget extends ConsumerWidget {
  const ProfileHeaderWidget({
    required this.userIdHex,
    required this.isOwnProfile,
    required this.profileStatsAsync,
    this.onSetupProfile,
    super.key,
  });

  /// The hex public key of the profile being displayed.
  final String userIdHex;

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  /// Async value containing profile stats (video count, etc.).
  final AsyncValue<ProfileStats> profileStatsAsync;

  /// Callback when "Set Up" button is tapped on the setup banner.
  /// Only shown for own profile with default name.
  final VoidCallback? onSetupProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch profile from relay (reactive)
    final profileAsync = ref.watch(fetchUserProfileProvider(userIdHex));
    final profile = profileAsync.value;

    if (!isOwnProfile && profile == null) {
      return const SizedBox.shrink();
    }

    final profilePictureUrl = profile?.picture;
    final displayName = profile?.bestDisplayName;
    final hasCustomName =
        profile?.name?.isNotEmpty == true ||
        profile?.displayName?.isNotEmpty == true;
    final nip05 = profile?.nip05;
    final about = profile?.about;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Setup profile banner for new users with default names
          // (only on own profile)
          if (isOwnProfile && !hasCustomName && onSetupProfile != null)
            _SetupProfileBanner(onSetup: onSetupProfile!),

          // Profile picture and stats row
          Row(
            children: [
              // Profile picture
              UserAvatar(imageUrl: profilePictureUrl, name: null, size: 86),

              const SizedBox(width: 20),

              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ProfileStatColumn(
                      count: profileStatsAsync.hasValue
                          ? profileStatsAsync.value!.videoCount
                          : null,
                      label: 'Videos',
                      isLoading: profileStatsAsync.isLoading,
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

          const SizedBox(height: 16),

          // Name and bio
          _ProfileNameAndBio(userIdHex: userIdHex, nip05: nip05, about: about),
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
          const Icon(Icons.person_add, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Add your name, bio, and picture to get started',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onSetup,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Set Up',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
    required this.userIdHex,
    required this.nip05,
    required this.about,
  });

  final String userIdHex;
  final String? nip05;
  final String? about;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserName.fromPubKey(
            userIdHex,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (nip05 != null && nip05!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _Nip05Identifier(nip05: nip05!),
          ],
          if (about != null && about!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _AboutText(about: about!),
          ],
          const SizedBox(height: 8),
          _PublicKeyDisplay(userIdHex: userIdHex),
        ],
      ),
    );
  }
}

/// NIP-05 identifier display.
class _Nip05Identifier extends StatelessWidget {
  const _Nip05Identifier({required this.nip05});

  final String nip05;

  @override
  Widget build(BuildContext context) {
    return Text(nip05, style: TextStyle(color: Colors.grey[400], fontSize: 13));
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
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
    );
  }
}

/// Public key (npub) display with copy functionality.
class _PublicKeyDisplay extends StatelessWidget {
  const _PublicKeyDisplay({required this.userIdHex});

  final String userIdHex;

  Future<void> _copyToClipboard(BuildContext context) async {
    try {
      final npub = NostrKeyUtils.encodePubKey(userIdHex);
      await Clipboard.setData(ClipboardData(text: npub));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(width: 8),
                Text('Public key copied to clipboard'),
              ],
            ),
            backgroundColor: VineTheme.vineGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _copyToClipboard(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[600]!, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SelectableText(
                NostrKeyUtils.encodePubKey(userIdHex),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }
}
