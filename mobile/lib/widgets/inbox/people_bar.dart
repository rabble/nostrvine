// ABOUTME: Horizontal scrollable people bar showing recent conversation users
// ABOUTME: Displays user avatars with display names in a horizontally
// ABOUTME: scrollable container at the top of the messages tab

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/services/image_cache_manager.dart';

/// Data model for a user displayed in the [PeopleBar].
class PeopleBarUser {
  /// Creates a [PeopleBarUser] with the given display information.
  const PeopleBarUser({required this.displayName, this.avatarUrl, this.pubkey});

  /// The user's display name shown below their avatar.
  final String displayName;

  /// Optional URL for the user's avatar image.
  final String? avatarUrl;

  /// Optional Nostr public key for the user.
  final String? pubkey;
}

/// A horizontal scrollable bar showing recent conversation participants.
///
/// Displays user avatars with names in a horizontally scrollable row.
/// When [users] is empty, shows a centered empty state message.
class PeopleBar extends StatelessWidget {
  /// Creates a [PeopleBar] with the given list of [users].
  const PeopleBar({required this.users, this.onUserTap, super.key});

  /// The list of users to display in the bar.
  final List<PeopleBarUser> users;

  /// Optional callback when a user avatar is tapped.
  final ValueChanged<PeopleBarUser>? onUserTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VineTheme.outlineMuted)),
      ),
      child: users.isEmpty
          ? const _EmptyPeopleBar()
          : _PopulatedPeopleBar(users: users, onUserTap: onUserTap),
    );
  }
}

class _EmptyPeopleBar extends StatelessWidget {
  const _EmptyPeopleBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'No recent conversations',
          style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _PopulatedPeopleBar extends StatelessWidget {
  const _PopulatedPeopleBar({required this.users, this.onUserTap});

  final List<PeopleBarUser> users;
  final ValueChanged<PeopleBarUser>? onUserTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: 20,
        ),
        itemCount: users.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _PeopleBarItem(
            user: users[index],
            onTap: onUserTap != null ? () => onUserTap!(users[index]) : null,
          );
        },
      ),
    );
  }
}

class _PeopleBarItem extends StatelessWidget {
  const _PeopleBarItem({required this.user, this.onTap});

  final PeopleBarUser user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PeopleBarAvatar(avatarUrl: user.avatarUrl),
            const SizedBox(height: 8),
            Text(
              user.displayName,
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleBarAvatar extends StatelessWidget {
  const _PeopleBarAvatar({this.avatarUrl});

  final String? avatarUrl;

  static const double _size = 48;
  static const double _borderRadius = 20;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_borderRadius),
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    width: _size,
                    height: _size,
                    fit: BoxFit.cover,
                    cacheManager: openVineImageCache,
                    placeholder: (context, url) =>
                        const _PeopleBarAvatarFallback(),
                    errorWidget: (context, url, error) =>
                        const _PeopleBarAvatarFallback(),
                  )
                : const _PeopleBarAvatarFallback(),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_borderRadius),
                border: Border.all(color: VineTheme.onSurfaceDisabled),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleBarAvatarFallback extends StatelessWidget {
  const _PeopleBarAvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(
        Icons.person,
        color: VineTheme.onSurfaceVariant,
        size: 24,
      ),
    );
  }
}
