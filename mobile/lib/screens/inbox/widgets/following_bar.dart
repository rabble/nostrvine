// ABOUTME: Horizontal scrollable bar of following users for the inbox screen.
// ABOUTME: Shows avatars with display names of users the current user follows.
// ABOUTME: Tapping an avatar navigates to start a conversation with that user.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Horizontal scrollable bar showing following users.
///
/// Displays a row of avatars with display names from [MyFollowingBloc].
/// Tapping a user triggers [onUserTapped] with their pubkey.
class FollowingBar extends StatelessWidget {
  const FollowingBar({required this.onUserTapped, super.key});

  final ValueChanged<String> onUserTapped;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<MyFollowingBloc, MyFollowingState, List<String>>(
      selector: (state) => state.followingPubkeys,
      builder: (context, followingPubkeys) {
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
      },
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
      data: (profile) =>
          profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey),
      orElse: () => UserProfile.defaultDisplayNameFor(pubkey),
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
          spacing: 8,
          children: [
            UserAvatar(
              imageUrl: imageUrl,
              name: displayName,
              placeholderSeed: pubkey,
              size: 48,
            ),
            Text(
              displayName,
              textScaler: TextScaler.noScaling,
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant)
                  .copyWith(
                    fontSize: MediaQuery.textScalerOf(
                      context,
                    ).scale(VineTheme.bodySmallFont().fontSize!).clamp(0, 18),
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
