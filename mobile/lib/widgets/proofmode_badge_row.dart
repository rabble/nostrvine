// ABOUTME: Reusable row of ProofMode and Vine badges for consistent display across video UI
// ABOUTME: Automatically shows appropriate badges based on VideoEvent metadata and AI scan results

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/utils/proofmode_helpers.dart';
import 'package:openvine/widgets/proofmode_badge.dart';
import 'package:openvine/widgets/user_name.dart';

/// Reusable badge row for displaying ProofMode verification and Vine badges
class ProofModeBadgeRow extends ConsumerWidget {
  const ProofModeBadgeRow({
    required this.video,
    super.key,
    this.size = BadgeSize.small,
    this.spacing = 8.0,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  final VideoEvent video;
  final BadgeSize size;
  final double spacing;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelService = ref.read(moderationLabelServiceProvider);
    final moderationStatusService = ref.read(
      videoModerationStatusServiceProvider,
    );
    final resolvedSha256 = VideoModerationStatusService.resolveSha256(
      explicitSha256: video.sha256,
      videoUrl: video.videoUrl,
    );
    AIDetectionResult? aiResult = _lookupAIDetection(
      labelService,
      resolvedSha256,
    );

    // For Divine-hosted videos without Kind 1985 AI labels,
    // fall back to the moderation status service (auto-scans all uploads).
    // Use select() to only rebuild when the AI score actually changes,
    // avoiding excessive rebuilds during scroll.
    if (aiResult == null && video.isFromDivineServer) {
      final aiScore = ref.watch(
        videoModerationStatusProvider(resolvedSha256).select(
          (asyncValue) =>
              asyncValue.whenOrNull(data: (status) => status?.aiScore),
        ),
      );
      if (aiScore != null) {
        aiResult = AIDetectionResult(
          score: aiScore,
          source: 'moderation-service',
        );
      }
    }

    // Determine effective verification level (with platinum upgrade)
    final effectiveLevel = _resolveLevel(aiResult);

    // A video with no proof tags can still earn a badge via AI scan.
    final hasAIScanBadge =
        !video.hasProofMode &&
        aiResult != null &&
        aiResult.score < 0.5 &&
        !video.isOriginalVine;

    // AI scan indicates possibly AI-generated (score >= 0.5)
    final isPossiblyAI =
        aiResult != null && aiResult.score >= 0.5 && !video.isOriginalVine;
    final isCheckingForAI =
        video.isFromDivineServer &&
        !video.shouldShowProofModeBadge &&
        !video.shouldShowVineBadge &&
        !hasAIScanBadge &&
        !isPossiblyAI &&
        aiResult == null;

    final badges = <Widget>[];

    // Add ProofMode badge for proof-backed content or a clean AI scan.
    if (video.shouldShowProofModeBadge || hasAIScanBadge) {
      badges.add(ProofModeBadge(level: effectiveLevel, size: size));
    }

    // Add "Possibly AI-Generated" badge for high AI scores
    if (isPossiblyAI && !video.shouldShowProofModeBadge) {
      badges.add(PossiblyAIBadge(size: size));
    }

    // Divine-hosted videos should surface pending AI status instead of
    // rendering blank while scan results are unavailable.
    if (isCheckingForAI) {
      badges.add(CheckingForAIBadge(size: size));
    }

    // Add "Not Divine Hosted" badge for external content (tappable)
    if (video.shouldShowNotDivineBadge && !hasAIScanBadge && !isPossiblyAI) {
      badges.add(
        GestureDetector(
          onTap: () => _showNotDivineExplanation(
            context,
            aiResult,
            moderationStatusService,
          ),
          child: NotDivineBadge(size: size),
        ),
      );
    }

    // Add Original Vine badge for vintage recovered vines
    if (video.shouldShowVineBadge) {
      badges.add(OriginalVineBadge(size: size));
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(spacing: spacing, runSpacing: spacing, children: badges);
  }

  /// Resolve the effective verification level, upgrading to platinum when
  /// device proof is combined with an AI scan confirming human origin.
  VerificationLevel _resolveLevel(AIDetectionResult? aiResult) {
    final baseLevel = video.getVerificationLevel();

    // No AI scan result — use base level
    if (aiResult == null) return baseLevel;

    final isLikelyHuman = aiResult.score < 0.5;

    // Platinum: device proof + AI scan confirms human
    if (baseLevel == VerificationLevel.verifiedMobile && isLikelyHuman) {
      return VerificationLevel.platinum;
    }

    // AI scan alone (no proof tags) earns silver for likely-human videos.
    if (baseLevel == VerificationLevel.unverified && isLikelyHuman) {
      return VerificationLevel.verifiedWeb;
    }

    return baseLevel;
  }

  /// Look up AI detection results from the moderation label service.
  AIDetectionResult? _lookupAIDetection(
    ModerationLabelService labelService,
    String? resolvedSha256,
  ) {
    final byEventId = labelService.getAIDetectionResult(video.id);
    if (byEventId != null) return byEventId;

    final hash = resolvedSha256 ?? video.vineId;
    if (hash != null) {
      return labelService.getAIDetectionByHash(hash);
    }
    return null;
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

  /// Show explanation popup for "Not Divine Hosted" badge
  void _showNotDivineExplanation(
    BuildContext context,
    AIDetectionResult? aiResult,
    VideoModerationStatusService moderationStatusService,
  ) {
    final hostDomain = _getHostDomain();
    final hasProof = video.hasProofMode;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.public_off, color: VineTheme.secondaryText, size: 24),
            SizedBox(width: 8),
            Text(
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
            const Text(
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
            const Text(
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

            // AI Detection assessment
            _AICheckSection(
              initialResult: aiResult,
              hasProof: hasProof,
              video: video,
              moderationStatusService: moderationStatusService,
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VineTheme.cardBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'This content is not hosted on Divine servers. '
                'We cannot fully guarantee its authenticity.',
                style: TextStyle(
                  color: VineTheme.secondaryText,
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

/// Stateful widget for AI assessment that supports on-demand scan checks.
class _AICheckSection extends StatefulWidget {
  const _AICheckSection({
    required this.initialResult,
    required this.hasProof,
    required this.video,
    required this.moderationStatusService,
  });

  final AIDetectionResult? initialResult;
  final bool hasProof;
  final VideoEvent video;
  final VideoModerationStatusService moderationStatusService;

  @override
  State<_AICheckSection> createState() => _AICheckSectionState();
}

class _AICheckSectionState extends State<_AICheckSection> {
  AIDetectionResult? _result;
  bool _isLoading = false;
  bool _checkedAndEmpty = false;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
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

      final status = await widget.moderationStatusService.fetchStatus(sha256);

      if (!mounted) return;

      if (status?.aiScore != null) {
        setState(() {
          _result = AIDetectionResult(
            score: status!.aiScore!,
            source: 'moderation-service',
          );
          _isLoading = false;
        });
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
    if (_result != null) {
      return _buildResultCard(_result!);
    }
    return _buildNotScannedCard();
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
          Row(
            children: [
              const Icon(
                Icons.pending_outlined,
                size: 20,
                color: VineTheme.onSurfaceMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
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
                    if (!widget.hasProof)
                      const Text(
                        'No ProofMode data attached',
                        style: TextStyle(
                          fontSize: 11,
                          color: VineTheme.onSurfaceMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
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

  Widget _buildResultCard(AIDetectionResult aiResult) {
    final percentage = (aiResult.score * 100).round();
    final isLikelyHuman = aiResult.score < 0.5;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLikelyHuman ? VineTheme.success : VineTheme.warning,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLikelyHuman ? Icons.check_circle : Icons.warning_amber,
                size: 20,
                color: isLikelyHuman ? VineTheme.success : VineTheme.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isLikelyHuman
                      ? 'Likely human-created'
                      : 'Possibly AI-generated',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isLikelyHuman
                        ? VineTheme.success
                        : VineTheme.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: aiResult.score,
              backgroundColor: VineTheme.cardBackground,
              valueColor: AlwaysStoppedAnimation<Color>(
                isLikelyHuman ? VineTheme.success : VineTheme.warning,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$percentage% likelihood of being AI-generated',
            style: const TextStyle(
              fontSize: 12,
              color: VineTheme.onSurfaceVariant,
            ),
          ),
          if (aiResult.source != null) ...[
            const SizedBox(height: 2),
            Text(
              'Scanned by: ${aiResult.source}',
              style: const TextStyle(
                fontSize: 11,
                color: VineTheme.onSurfaceMuted,
              ),
            ),
          ],
          if (aiResult.isVerified) ...[
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.verified, size: 12, color: VineTheme.info),
                SizedBox(width: 4),
                Text(
                  'Confirmed by human moderator',
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
