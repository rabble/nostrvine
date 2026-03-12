// ABOUTME: Horizontal scrollable bar of following users for the inbox screen.
// ABOUTME: Shows avatars with display names of users the current user follows.
// ABOUTME: Tapping an avatar navigates to start a conversation with that user.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Horizontal scrollable bar showing following users.
///
/// Displays a row of avatars with display names from the cached following list.
/// Tapping a user triggers [onUserTapped] with their pubkey.
class FollowingBar extends ConsumerWidget {
  const FollowingBar({required this.onUserTapped, super.key});

  final ValueChanged<String> onUserTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingPubkeys = ref.watch(cachedFollowingListProvider);

    if (followingPubkeys.isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: VineTheme.outlineDisabled),
        ),
      ),
      child: SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: followingPubkeys.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => _FollowingUserButton(
            pubkey: followingPubkeys[index],
            onTap: () => onUserTapped(followingPubkeys[index]),
          ),
        ),
      ),
    );
  }
}

class _FollowingUserButton extends ConsumerWidget {
  const _FollowingUserButton({required this.pubkey, required this.onTap});

  final String pubkey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fetchUserProfileProvider(pubkey));

    final displayName = profileAsync.maybeWhen(
      data: (profile) => profile?.displayName?.isNotEmpty == true
          ? profile!.displayName!
          : profile?.name ?? _truncatePubkey(pubkey),
      orElse: () => _truncatePubkey(pubkey),
    );

    final imageUrl = profileAsync.maybeWhen(
      data: (profile) => profile?.picture,
      orElse: () => null,
    );

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(imageUrl: imageUrl, name: displayName, size: 48),
            const SizedBox(height: 8),
            Text(
              displayName,
              style: VineTheme.bodySmallFont(
                color: VineTheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static String _truncatePubkey(String pubkey) =>
      NostrKeyUtils.truncateNpub(pubkey);
}
