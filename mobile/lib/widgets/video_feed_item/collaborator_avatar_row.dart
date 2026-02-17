// ABOUTME: Collaborator avatar row for video feed overlay
// ABOUTME: Shows small overlapping avatars of collaborators
// ABOUTME: with tap navigation to their profiles

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Displays collaborator avatars on a video feed item.
///
/// Shows small overlapping avatar circles for each
/// collaborator. Tapping opens the first collaborator's
/// profile.
///
/// Returns [SizedBox.shrink] if the video has no
/// collaborators.
class CollaboratorAvatarRow extends ConsumerWidget {
  /// Creates a CollaboratorAvatarRow.
  const CollaboratorAvatarRow({required this.video, super.key});

  /// The video event to display collaborators for.
  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!video.hasCollaborators) {
      return const SizedBox.shrink();
    }

    final pubkeys = video.collaboratorPubkeys;

    return GestureDetector(
      onTap: () => _navigateToCollaborator(context, pubkeys.first),
      child: Semantics(
        identifier: 'collaborator_avatar_row',
        button: true,
        label:
            '${pubkeys.length} collaborator'
            '${pubkeys.length > 1 ? 's' : ''}. '
            'Tap to view profile.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people, size: 14, color: VineTheme.vineGreen),
              const SizedBox(width: 4),
              // Show up to 3 overlapping avatars
              _CollaboratorAvatarStack(pubkeys: pubkeys.take(3).toList()),
              const SizedBox(width: 4),
              Flexible(child: _CollaboratorLabel(pubkeys: pubkeys)),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCollaborator(BuildContext context, String pubkey) {
    Log.info(
      'Navigating to collaborator profile: $pubkey',
      name: 'CollaboratorAvatarRow',
      category: LogCategory.ui,
    );

    final npub = normalizeToNpub(pubkey);
    if (npub != null) {
      context.push(OtherProfileScreen.pathForNpub(npub));
    }
  }
}

/// Small overlapping avatar circles.
class _CollaboratorAvatarStack extends ConsumerWidget {
  const _CollaboratorAvatarStack({required this.pubkeys});

  final List<String> pubkeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 20.0 + (pubkeys.length - 1) * 12.0,
      height: 20,
      child: Stack(
        children: [
          for (var i = 0; i < pubkeys.length; i++)
            Positioned(
              left: i * 12.0,
              child: _SmallAvatar(pubkey: pubkeys[i]),
            ),
        ],
      ),
    );
  }
}

/// A small 20px avatar with white border.
class _SmallAvatar extends ConsumerWidget {
  const _SmallAvatar({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fetchUserProfileProvider(pubkey));

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: VineTheme.whiteText, width: 1.5),
      ),
      child: ClipOval(
        child: UserAvatar(
          imageUrl: profileAsync.value?.picture,
          name: profileAsync.value?.bestDisplayName,
          size: 17,
        ),
      ),
    );
  }
}

/// Text label showing collaborator name(s).
class _CollaboratorLabel extends ConsumerWidget {
  const _CollaboratorLabel({required this.pubkeys});

  final List<String> pubkeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstProfile = ref.watch(fetchUserProfileProvider(pubkeys.first));

    final firstName =
        firstProfile.value?.bestDisplayName ??
        NostrKeyUtils.truncateNpub(pubkeys.first);

    final label = pubkeys.length == 1
        ? 'with @$firstName'
        : 'with @$firstName +${pubkeys.length - 1}';

    return Text(
      label,
      style: const TextStyle(
        color: VineTheme.whiteText,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        shadows: [Shadow(blurRadius: 4, color: VineTheme.backgroundColor)],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
