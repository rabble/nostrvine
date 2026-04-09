import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Reusable tile widget for displaying a user profile in search results.
///
/// Shows avatar, display name, and a secondary line with verified NIP-05 or
/// truncated npub. Uses [ConsumerWidget] (Riverpod) because
/// [nip05VerificationProvider] is a legacy Riverpod provider that has not yet
/// been migrated to BLoC.
class SearchUserTile extends ConsumerWidget {
  const SearchUserTile({required this.profile, this.onTap, super.key});

  final UserProfile profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimedNip05 = profile.displayNip05;
    final verificationStatus = claimedNip05 != null && claimedNip05.isNotEmpty
        ? ref
              .watch(nip05VerificationProvider(profile.pubkey))
              .whenOrNull(data: (status) => status)
        : null;
    final showVerifiedNip05 =
        verificationStatus == Nip05VerificationStatus.verified;

    final secondaryText = showVerifiedNip05 && claimedNip05 != null
        ? claimedNip05
        : profile.truncatedNpub;

    return Semantics(
      identifier: 'search_user_tile_${profile.pubkey}',
      label: profile.bestDisplayName,
      container: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            spacing: 16,
            children: [
              UserAvatar(imageUrl: profile.picture, size: 40),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      profile.bestDisplayName,
                      style: VineTheme.titleMediumFont(),
                    ),
                    Text(
                      secondaryText,
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
