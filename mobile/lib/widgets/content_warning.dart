// ABOUTME: Content warning overlay widget for potentially sensitive content
// ABOUTME: Provides user control over viewing filtered content with clear warnings

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/content_moderation_service.dart';

/// Content warning overlay for filtered content
class ContentWarning extends StatefulWidget {
  const ContentWarning({
    required this.child,
    required this.moderationResult,
    super.key,
    this.onReport,
    this.onBlock,
    this.showControls = true,
  });
  final Widget child;
  final ModerationResult moderationResult;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final bool showControls;

  @override
  State<ContentWarning> createState() => _ContentWarningState();
}

class _ContentWarningState extends State<ContentWarning>
    with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If content is clean or user has revealed it, show normally
    if (!widget.moderationResult.shouldFilter || _isRevealed) {
      return widget.child;
    }

    // For blocked content, show permanent warning
    if (widget.moderationResult.severity == ContentSeverity.block) {
      return _buildBlockedContent(context);
    }

    // For hidden content, show warning overlay
    return _buildWarningOverlay(context);
  }

  Widget _buildWarningOverlay(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _getWarningColor(
        widget.moderationResult.severity,
      ).withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _getWarningColor(widget.moderationResult.severity),
        width: 2,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Warning icon and title
        Row(
          children: [
            Icon(
              _getWarningIcon(widget.moderationResult.severity),
              color: VineTheme.whiteText,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getWarningTitle(context, widget.moderationResult.severity),
                    style: const TextStyle(
                      color: VineTheme.whiteText,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.moderationResult.warningMessage != null)
                    Text(
                      widget.moderationResult.warningMessage!,
                      style: const TextStyle(
                        color: VineTheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Filter reason chips
        if (widget.moderationResult.reasons.isNotEmpty)
          Wrap(
            spacing: 8,
            children: widget.moderationResult.reasons
                .map(
                  (reason) => Chip(
                    label: Text(
                      reason.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: VineTheme.whiteText.withValues(alpha: 0.2),
                    labelStyle: const TextStyle(color: VineTheme.whiteText),
                  ),
                )
                .toList(),
          ),

        const SizedBox(height: 16),

        // Action buttons
        Row(
          children: [
            // Show content button
            Expanded(
              child: OutlinedButton(
                onPressed: _revealContent,
                style: OutlinedButton.styleFrom(
                  foregroundColor: VineTheme.whiteText,
                  side: const BorderSide(color: VineTheme.whiteText),
                ),
                child: Text(context.l10n.contentWarningViewAnyway),
              ),
            ),

            if (widget.showControls) ...[
              const SizedBox(width: 12),

              // Report button
              if (widget.onReport != null)
                IconButton(
                  onPressed: widget.onReport,
                  icon: const Icon(Icons.flag_outlined),
                  color: VineTheme.whiteText,
                  tooltip: context.l10n.contentWarningReportContentTooltip,
                ),

              // Block button
              if (widget.onBlock != null)
                IconButton(
                  onPressed: widget.onBlock,
                  icon: const Icon(Icons.block_outlined),
                  color: VineTheme.whiteText,
                  tooltip: context.l10n.contentWarningBlockUserTooltip,
                ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _buildBlockedContent(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: VineTheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: VineTheme.error, width: 2),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.block, color: VineTheme.whiteText, size: 48),
        const SizedBox(height: 16),
        Text(
          context.l10n.contentWarningBlockedTitle,
          style: const TextStyle(
            color: VineTheme.whiteText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.moderationResult.warningMessage != null)
          Text(
            widget.moderationResult.warningMessage!,
            style: const TextStyle(
              color: VineTheme.onSurfaceVariant,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 16),
        Text(
          context.l10n.contentWarningBlockedPolicy,
          style: TextStyle(
            color: VineTheme.whiteText.withValues(alpha: 0.8),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  void _revealContent() {
    setState(() {
      _isRevealed = true;
    });
    _animationController.forward();
  }

  Color _getWarningColor(ContentSeverity severity) {
    switch (severity) {
      case ContentSeverity.info:
        return VineTheme.info;
      case ContentSeverity.warning:
        return VineTheme.warning;
      case ContentSeverity.hide:
        return VineTheme.error;
      case ContentSeverity.block:
        return VineTheme.errorContainer;
    }
  }

  IconData _getWarningIcon(ContentSeverity severity) {
    switch (severity) {
      case ContentSeverity.info:
        return Icons.info_outline;
      case ContentSeverity.warning:
        return Icons.warning_amber_outlined;
      case ContentSeverity.hide:
        return Icons.visibility_off_outlined;
      case ContentSeverity.block:
        return Icons.block;
    }
  }

  String _getWarningTitle(BuildContext context, ContentSeverity severity) {
    switch (severity) {
      case ContentSeverity.info:
        return context.l10n.contentWarningNoticeTitle;
      case ContentSeverity.warning:
        return context.l10n.contentWarningSensitiveContent;
      case ContentSeverity.hide:
        return context.l10n.contentWarningPotentiallyHarmfulTitle;
      case ContentSeverity.block:
        return context.l10n.contentWarningBlockedTitle;
    }
  }
}

/// Quick content warning for less severe content
class QuickContentWarning extends StatelessWidget {
  const QuickContentWarning({
    required this.child,
    required this.warningText,
    super.key,
    this.icon = Icons.warning_amber_outlined,
    this.color = VineTheme.warning,
    this.onTap,
  });
  final Widget child;
  final String warningText;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      PositionedDirectional(
        top: 8,
        end: 8,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: VineTheme.whiteText, size: 16),
                const SizedBox(width: 4),
                Text(
                  warningText,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

/// Content warning for video thumbnails
class VideoContentWarning extends StatefulWidget {
  const VideoContentWarning({
    required this.thumbnail,
    required this.moderationResult,
    super.key,
    this.onPlay,
    this.onReport,
  });
  final Widget thumbnail;
  final ModerationResult moderationResult;
  final VoidCallback? onPlay;
  final VoidCallback? onReport;

  @override
  State<VideoContentWarning> createState() => _VideoContentWarningState();
}

class _VideoContentWarningState extends State<VideoContentWarning> {
  bool _showWarning = true;

  @override
  void initState() {
    super.initState();
    _showWarning = widget.moderationResult.shouldFilter;
  }

  @override
  Widget build(BuildContext context) {
    if (!_showWarning) {
      return widget.thumbnail;
    }

    return Stack(
      children: [
        // Blurred background
        ImageFiltered(
          imageFilter: widget.moderationResult.severity == ContentSeverity.block
              ? ColorFilter.mode(
                  VineTheme.backgroundColor.withValues(alpha: 0.8),
                  BlendMode.srcOver,
                )
              : const ColorFilter.mode(
                  VineTheme.transparent,
                  BlendMode.multiply,
                ),
          child: widget.thumbnail,
        ),

        // Warning overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.backgroundColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber,
                  color: VineTheme.whiteText,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.contentWarningSensitiveContent,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (widget.moderationResult.severity !=
                        ContentSeverity.block)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showWarning = false;
                          });
                          widget.onPlay?.call();
                        },
                        child: Text(
                          context.l10n.contentWarningView,
                          style: const TextStyle(color: VineTheme.whiteText),
                        ),
                      ),
                    if (widget.onReport != null)
                      TextButton(
                        onPressed: widget.onReport,
                        child: Text(
                          context.l10n.contentWarningReportAction,
                          style: const TextStyle(color: VineTheme.error),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
