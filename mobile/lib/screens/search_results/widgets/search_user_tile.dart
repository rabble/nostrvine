import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Reusable tile widget for displaying a user profile in search results.
///
/// Uses [ConsumerWidget] (Riverpod) because [nip05VerificationProvider] is a
/// legacy Riverpod provider that has not yet been migrated to BLoC.
class SearchUserTile extends ConsumerWidget {
  const SearchUserTile({required this.profile, this.onTap, super.key});

  final UserProfile profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followerCount = profile.followerCount;
    final videoCount = profile.videoCount;
    final claimedNip05 = profile.displayNip05;
    final verificationStatus = claimedNip05 != null && claimedNip05.isNotEmpty
        ? ref
              .watch(nip05VerificationProvider(profile.pubkey))
              .whenOrNull(data: (status) => status)
        : null;
    final showVerifiedNip05 =
        verificationStatus == Nip05VerificationStatus.verified;

    return Semantics(
      identifier: 'search_user_tile_${profile.pubkey}',
      label: profile.bestDisplayName,
      container: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            spacing: 12,
            children: [
              UserAvatar(imageUrl: profile.picture, size: 48),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      profile.bestDisplayName,
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (showVerifiedNip05 && claimedNip05 != null)
                      Text(
                        claimedNip05,
                        style: const TextStyle(
                          color: VineTheme.vineGreen,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (followerCount != null || videoCount != null)
                      _ProfileStats(
                        followerCount: followerCount,
                        videoCount: videoCount,
                      ),
                    if (profile.about != null && profile.about!.isNotEmpty)
                      Text(
                        profile.about!,
                        style: const TextStyle(
                          color: VineTheme.secondaryText,
                          fontSize: 14,
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

class _ProfileStats extends StatelessWidget {
  const _ProfileStats({this.followerCount, this.videoCount});

  final int? followerCount;
  final int? videoCount;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (followerCount != null) {
      parts.add('${StringUtils.formatCompactNumber(followerCount!)} followers');
    }
    if (videoCount != null) {
      parts.add('${StringUtils.formatCompactNumber(videoCount!)} videos');
    }
    return Text(
      parts.join(' \u00B7 '),
      style: const TextStyle(color: VineTheme.lightText, fontSize: 13),
    );
  }
}
