// ABOUTME: Modal dialog explaining video badge origins (Vine archive vs Proofmode verification)
// ABOUTME: Shows ProofMode verification details and HiveAI detection results

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal dialog explaining the origin and authenticity of video content
class BadgeExplanationModal extends StatelessWidget {
  const BadgeExplanationModal({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final isVineArchive = video.isOriginalVine;

    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: _BadgeModalTitle(isVineArchive: isVineArchive),
      content: SingleChildScrollView(
        child: isVineArchive
            ? _VineArchiveExplanation(video: video)
            : _ProofModeExplanation(video: video),
      ),
      actions: [
        TextButton(
          onPressed: context.pop,
          child: const Text('Close', style: TextStyle(color: VineTheme.info)),
        ),
      ],
    );
  }
}

/// Title row for the badge explanation modal
class _BadgeModalTitle extends StatelessWidget {
  const _BadgeModalTitle({required this.isVineArchive});

  final bool isVineArchive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isVineArchive ? Icons.archive : Icons.verified_user,
          color: isVineArchive ? VineTheme.vineGreen : VineTheme.info,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isVineArchive ? 'Original Vine Archive' : 'Video Verification',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: VineTheme.whiteText,
            ),
          ),
        ),
      ],
    );
  }
}

/// Explanation content for archived Vine videos
class _VineArchiveExplanation extends StatelessWidget {
  const _VineArchiveExplanation({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This video is an original Vine recovered from the Internet '
          'Archive.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: VineTheme.whiteText,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Before Vine shut down in 2017, ArchiveTeam and the Internet '
          'Archive worked to preserve millions of Vines for posterity. '
          'This content is part of that historic preservation effort.',
          style: TextStyle(fontSize: 13, color: VineTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (video.originalLoops != null && video.originalLoops! > 0) ...[
          Text(
            'Original stats: ${video.originalLoops} loops',
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: VineTheme.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 8),
        ],
        const _ExternalLink(
          url: 'https://divine.video/dmca',
          label: 'Learn more about the Vine archive preservation',
        ),
      ],
    );
  }
}

/// Explanation content for ProofMode verified videos
class _ProofModeExplanation extends ConsumerWidget {
  const _ProofModeExplanation({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelService = ref.read(moderationLabelServiceProvider);
    final aiResult = _lookupAIDetection(labelService);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "This video's authenticity is verified using Proofmode "
          'technology.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: VineTheme.whiteText,
          ),
        ),
        const SizedBox(height: 16),
        _ProofModeDetailsSection(video: video, aiResult: aiResult),
        const SizedBox(height: 16),
        _AIDetectionSection(aiResult: aiResult),
        const SizedBox(height: 12),
        const _ExternalLink(
          url: 'https://divine.video/proofmode',
          label: 'Learn more about Proofmode verification',
        ),
        if (video.videoUrl != null && video.videoUrl!.isNotEmpty)
          _ExternalLink(
            url: 'https://check.proofmode.org/#${video.videoUrl}',
            label: 'Inspect with ProofCheck Tool',
          ),
      ],
    );
  }

  AIDetectionResult? _lookupAIDetection(
    ModerationLabelService labelService,
  ) {
    // Try lookup by event ID first
    final byEventId = labelService.getAIDetectionResult(video.id);
    if (byEventId != null) return byEventId;

    // Fallback: lookup by content hash
    final hash = video.sha256 ?? video.vineId;
    if (hash != null) {
      return labelService.getAIDetectionByHash(hash);
    }
    return null;
  }
}

/// Section showing ProofMode verification details
class _ProofModeDetailsSection extends StatelessWidget {
  const _ProofModeDetailsSection({
    required this.video,
    this.aiResult,
  });

  final VideoEvent video;
  final AIDetectionResult? aiResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.verified_user,
          title: 'ProofMode Verification',
        ),
        const SizedBox(height: 8),
        _VerificationLevelCard(video: video, aiResult: aiResult),
        const SizedBox(height: 8),
        _ProofCheckList(video: video),
      ],
    );
  }
}

/// Checklist of which proof elements are present
class _ProofCheckList extends StatelessWidget {
  const _ProofCheckList({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProofCheckItem(
          label: 'Device attestation',
          passed: video.proofModeDeviceAttestation != null,
        ),
        _ProofCheckItem(
          label: 'PGP signature',
          passed: video.proofModePgpFingerprint != null,
        ),
        _ProofCheckItem(
          label: 'C2PA Content Credentials',
          passed: video.proofModeC2paManifestId != null,
        ),
        _ProofCheckItem(
          label: 'Proof manifest',
          passed: video.proofModeManifest != null,
        ),
      ],
    );
  }
}

/// Single check item showing pass/fail status
class _ProofCheckItem extends StatelessWidget {
  const _ProofCheckItem({required this.label, required this.passed});

  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: passed ? VineTheme.success : VineTheme.onSurfaceMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: passed
                    ? VineTheme.onSurfaceVariant
                    : VineTheme.onSurfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section showing AI detection results from HiveAI
class _AIDetectionSection extends StatelessWidget {
  const _AIDetectionSection({required this.aiResult});

  final AIDetectionResult? aiResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.psychology, title: 'AI Detection'),
        const SizedBox(height: 8),
        if (aiResult != null)
          _AIDetectionResultCard(result: aiResult!)
        else
          const Text(
            'Not yet scanned',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: VineTheme.onSurfaceMuted,
            ),
          ),
      ],
    );
  }
}

/// Card showing AI detection score with progress bar
class _AIDetectionResultCard extends StatelessWidget {
  const _AIDetectionResultCard({required this.result});

  final AIDetectionResult result;

  @override
  Widget build(BuildContext context) {
    final percentage = (result.score * 100).round();
    final isLikelyAI = result.score > 0.5;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLikelyAI ? Icons.warning_amber : Icons.check_circle,
                size: 16,
                color: isLikelyAI ? VineTheme.warning : VineTheme.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$percentage% likelihood of being AI-generated',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isLikelyAI ? VineTheme.warning : VineTheme.whiteText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: result.score,
              backgroundColor: VineTheme.cardBackground,
              valueColor: AlwaysStoppedAnimation<Color>(
                isLikelyAI ? VineTheme.warning : VineTheme.success,
              ),
              minHeight: 6,
            ),
          ),
          if (result.source != null) ...[
            const SizedBox(height: 6),
            Text(
              'Scanned by: ${result.source}',
              style: const TextStyle(
                fontSize: 11,
                color: VineTheme.onSurfaceMuted,
              ),
            ),
          ],
          if (result.isVerified) ...[
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.verified, size: 12, color: VineTheme.info),
                SizedBox(width: 4),
                Text(
                  'Verified by human moderator',
                  style: TextStyle(fontSize: 11, color: VineTheme.info),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable section header with icon and title
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: VineTheme.info),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: VineTheme.whiteText,
          ),
        ),
      ],
    );
  }
}

/// Card showing verification level details with icon and description
class _VerificationLevelCard extends StatelessWidget {
  const _VerificationLevelCard({
    required this.video,
    this.aiResult,
  });

  final VideoEvent video;
  final AIDetectionResult? aiResult;

  @override
  Widget build(BuildContext context) {
    final config = _getVerificationConfig(video, aiResult);

    return Row(
      children: [
        Icon(config.icon, size: 18, color: config.color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            config.description,
            style: const TextStyle(
              fontSize: 12,
              color: VineTheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  _VerificationConfig _getVerificationConfig(
    VideoEvent video,
    AIDetectionResult? aiResult,
  ) {
    final hasHumanAIScan = aiResult != null && aiResult.score < 0.5;

    if (video.isVerifiedMobile && hasHumanAIScan) {
      return const _VerificationConfig(
        icon: Icons.verified,
        color: Color(0xFFE5E4E2), // Platinum
        description:
            'Platinum: Device hardware attestation, cryptographic '
            'signatures, Content Credentials (C2PA), and AI scan '
            'confirms human origin.',
      );
    } else if (video.isVerifiedMobile) {
      return const _VerificationConfig(
        icon: Icons.verified,
        color: Color(0xFFFFD700), // Gold
        description:
            'Gold: Captured on a real device with hardware attestation, '
            'cryptographic signatures, and Content Credentials (C2PA).',
      );
    } else if (video.isVerifiedWeb) {
      return const _VerificationConfig(
        icon: Icons.verified_outlined,
        color: Color(0xFFC0C0C0), // Silver
        description:
            "Silver: Cryptographic signatures prove this video hasn't "
            'been altered since recording.',
      );
    } else if (video.hasBasicProof) {
      return const _VerificationConfig(
        icon: Icons.verified_outlined,
        color: Color(0xFFCD7F32), // Bronze
        description: 'Bronze: Basic metadata signatures are present.',
      );
    } else if (hasHumanAIScan) {
      return const _VerificationConfig(
        icon: Icons.verified_outlined,
        color: Color(0xFFC0C0C0), // Silver
        description:
            'Silver: AI scan confirms this video is likely '
            'human-created.',
      );
    } else {
      return const _VerificationConfig(
        icon: Icons.shield_outlined,
        color: VineTheme.lightText,
        description: 'No verification data available for this video.',
      );
    }
  }
}

/// Reusable external link row
class _ExternalLink extends StatelessWidget {
  const _ExternalLink({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.open_in_new, size: 16, color: VineTheme.info),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: VineTheme.info,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Configuration data for verification levels
class _VerificationConfig {
  const _VerificationConfig({
    required this.icon,
    required this.color,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String description;
}
