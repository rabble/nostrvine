// ABOUTME: Reusable row of ProofMode and Vine badges for consistent display across video UI
// ABOUTME: Automatically shows appropriate badges based on VideoEvent metadata

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/proofmode_badge.dart';
import 'package:openvine/utils/proofmode_helpers.dart';
import 'package:openvine/widgets/user_name.dart';

/// Reusable badge row for displaying ProofMode verification and Vine badges
class ProofModeBadgeRow extends StatelessWidget {
  const ProofModeBadgeRow({
    super.key,
    required this.video,
    this.size = BadgeSize.small,
    this.spacing = 8.0,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  final VideoEvent video;
  final BadgeSize size;
  final double spacing;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    // Don't render anything if no badges to show
    if (!video.shouldShowProofModeBadge &&
        !video.shouldShowNotDivineBadge &&
        !video.shouldShowVineBadge) {
      return const SizedBox.shrink();
    }

    final badges = <Widget>[];

    // Add ProofMode badge if applicable
    if (video.shouldShowProofModeBadge) {
      badges.add(
        ProofModeBadge(level: video.getVerificationLevel(), size: size),
      );
    }

    // Add "Not Divine" badge for external content (tappable with info popup)
    if (video.shouldShowNotDivineBadge) {
      badges.add(
        GestureDetector(
          onTap: () => _showNotDivineExplanation(context),
          child: NotDivineBadge(size: size),
        ),
      );
    }

    // Add Original Vine badge for vintage recovered vines
    if (video.shouldShowVineBadge) {
      badges.add(OriginalVineBadge(size: size));
    }

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.start,
      children: badges,
    );
  }

  /// Extract host domain from video URL
  String _getHostDomain() {
    final url = video.videoUrl;
    if (url == null || url.isEmpty) return 'unknown server';
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return 'unknown server';
    }
  }

  /// Show explanation popup for "Not Divine" badge
  void _showNotDivineExplanation(BuildContext context) {
    final hostDomain = _getHostDomain();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.public_off, color: Colors.grey.shade400, size: 24),
            const SizedBox(width: 8),
            const Text(
              'External Content',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This video is hosted on:',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              hostDomain,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Published by:',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 4),
            UserName.fromPubKey(
              video.pubkey,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'This content is not hosted, verified, or moderated by Divine. '
                'We cannot guarantee its authenticity or safety.',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: context.pop,
            child: const Text(
              'Got it',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
  }
}
