// ABOUTME: Modal dialog explaining video badge origins (Vine archive vs Proofmode verification)
// ABOUTME: Shows ProofMode verification details and HiveAI detection results

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
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
class _ProofModeExplanation extends ConsumerStatefulWidget {
  const _ProofModeExplanation({required this.video});

  final VideoEvent video;

  @override
  ConsumerState<_ProofModeExplanation> createState() =>
      _ProofModeExplanationState();
}

class _ProofModeExplanationState extends ConsumerState<_ProofModeExplanation> {
  AIDetectionResult? _manualAiResult;

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final labelService = ref.read(moderationLabelServiceProvider);
    var aiResult = _manualAiResult ?? _lookupAIDetection(labelService);

    if (aiResult == null && video.isFromDivineServer) {
      final statusAsync = ref.watch(
        videoModerationStatusProvider(video.sha256),
      );
      aiResult = statusAsync.whenOrNull(
        data: (status) {
          if (status?.aiScore != null) {
            return AIDetectionResult(
              score: status!.aiScore!,
              source: 'moderation-service',
            );
          }
          return null;
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getIntroText(aiResult),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: VineTheme.whiteText,
          ),
        ),
        const SizedBox(height: 16),
        _ProofModeDetailsSection(video: video, aiResult: aiResult),
        const SizedBox(height: 16),
        _AIDetectionSection(
          video: video,
          initialResult: aiResult,
          onResult: (result) => setState(() => _manualAiResult = result),
        ),
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
    final video = widget.video;

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

  String _getIntroText(AIDetectionResult? aiResult) {
    final video = widget.video;

    if (video.hasProofMode) {
      return "This video's authenticity is verified using Proofmode "
          'technology.';
    }
    if (aiResult != null && aiResult.score < 0.5) {
      if (video.isFromDivineServer) {
        return 'This video is hosted on Divine and AI detection indicates it '
            'is likely human-made, even though no ProofMode verification data '
            'is attached.';
      }
      return 'AI detection indicates this video is likely human-made, though '
          'no ProofMode verification data is attached.';
    }
    if (video.isFromDivineServer) {
      return 'This video is hosted on Divine, but no ProofMode verification '
          'data is attached yet.';
    }
    return 'This video is hosted outside Divine and does not include '
        'ProofMode verification data.';
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
class _AIDetectionSection extends ConsumerStatefulWidget {
  const _AIDetectionSection({
    required this.video,
    required this.initialResult,
    this.onResult,
  });

  final VideoEvent video;
  final AIDetectionResult? initialResult;
  final ValueChanged<AIDetectionResult>? onResult;

  @override
  ConsumerState<_AIDetectionSection> createState() =>
      _AIDetectionSectionState();
}

class _AIDetectionSectionState extends ConsumerState<_AIDetectionSection> {
  AIDetectionResult? _result;
  bool _isLoading = false;
  bool _checkedAndEmpty = false;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
  }

  @override
  void didUpdateWidget(covariant _AIDetectionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_result == null && widget.initialResult != null) {
      _result = widget.initialResult;
    }
  }

  Future<void> _checkForResults() async {
    setState(() => _isLoading = true);

    try {
      final sha256 = VideoModerationStatusService.resolveSha256(
        explicitSha256: widget.video.sha256,
        videoUrl: widget.video.videoUrl,
      );

      if (sha256 == null) {
        setState(() {
          _isLoading = false;
          _checkedAndEmpty = true;
        });
        return;
      }

      final status = await ref
          .read(videoModerationStatusServiceProvider)
          .fetchStatus(sha256);

      if (!mounted) return;

      if (status?.aiScore != null) {
        final result = AIDetectionResult(
          score: status!.aiScore!,
          source: 'moderation-service',
        );
        setState(() {
          _result = result;
          _checkedAndEmpty = false;
          _isLoading = false;
        });
        widget.onResult?.call(result);
      } else {
        setState(() {
          _isLoading = false;
          _checkedAndEmpty = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _checkedAndEmpty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.psychology, title: 'AI Detection'),
        const SizedBox(height: 8),
        if (result != null)
          _AIDetectionResultCard(result: result)
        else
          _buildNotScannedCard(),
      ],
    );
  }

  Widget _buildNotScannedCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VineTheme.onSurfaceMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI scan: Not yet scanned',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: VineTheme.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.onSurfaceMuted,
                  ),
                ),
              ),
            )
          else if (_checkedAndEmpty)
            const Text(
              'No scan results available yet.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: VineTheme.onSurfaceMuted,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _checkForResults,
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Check if AI-generated'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VineTheme.onSurfaceVariant,
                  side: const BorderSide(color: VineTheme.onSurfaceMuted),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
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
            'Silver: AI scan confirms this video is likely human-created.',
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
