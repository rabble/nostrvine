// ABOUTME: Overlapping circular avatar stack for grouped notifications.
// ABOUTME: Shows 1-3 actor avatars with optional overflow count indicator.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';

/// Renders 1-3 overlapping circular avatars for grouped notifications.
///
/// When [overflowCount] is greater than zero, a "+N" circle is appended
/// after the last avatar.
class NotificationAvatarStack extends StatelessWidget {
  /// Creates an avatar stack from a list of actors.
  const NotificationAvatarStack({
    required this.actors,
    this.overflowCount,
    super.key,
  });

  /// The actors whose avatars to display (max 3 are shown).
  final List<ActorInfo> actors;

  /// Number of additional actors beyond those displayed.
  final int? overflowCount;

  /// Diameter of each avatar circle.
  static const double _avatarSize = 36;

  /// How much each successive avatar overlaps the previous one.
  static const double _overlap = 12;

  @override
  Widget build(BuildContext context) {
    final displayActors = actors.take(3).toList();
    final showOverflow = (overflowCount ?? 0) > 0;
    final itemCount = displayActors.length + (showOverflow ? 1 : 0);
    final totalWidth = _avatarSize + (_avatarSize - _overlap) * (itemCount - 1);

    return SizedBox(
      width: totalWidth,
      height: _avatarSize,
      child: Stack(
        children: [
          for (var i = 0; i < displayActors.length; i++)
            Positioned(
              left: (_avatarSize - _overlap) * i,
              child: _Avatar(actor: displayActors[i]),
            ),
          if (showOverflow)
            Positioned(
              left: (_avatarSize - _overlap) * displayActors.length,
              child: _OverflowCircle(count: overflowCount!),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.actor});

  final ActorInfo actor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: NotificationAvatarStack._avatarSize,
      height: NotificationAvatarStack._avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(width: 2),
      ),
      child: ClipOval(
        child: actor.pictureUrl != null
            ? CachedNetworkImage(
                imageUrl: actor.pictureUrl!,
                width: NotificationAvatarStack._avatarSize,
                height: NotificationAvatarStack._avatarSize,
                fit: BoxFit.cover,
                placeholder: (context, url) => const _DefaultAvatar(),
                errorWidget: (context, url, error) => const _DefaultAvatar(),
              )
            : const _DefaultAvatar(),
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: NotificationAvatarStack._avatarSize,
      height: NotificationAvatarStack._avatarSize,
      color: VineTheme.surfaceContainer,
      child: const Icon(
        Icons.person,
        color: VineTheme.lightText,
        size: 20,
      ),
    );
  }
}

class _OverflowCircle extends StatelessWidget {
  const _OverflowCircle({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: NotificationAvatarStack._avatarSize,
      height: NotificationAvatarStack._avatarSize,
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        shape: BoxShape.circle,
        border: Border.all(width: 2),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: VineTheme.labelSmallFont(color: VineTheme.secondaryText),
        ),
      ),
    );
  }
}
