// ABOUTME: Report content bottom sheet for Apple-compliant content reporting.
// ABOUTME: Replaces the legacy AlertDialog with a VineBottomSheet-based flow.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows a [VineBottomSheet] for reporting a video.
///
/// Usage:
/// ```dart
/// await ReportContentDialog.show(context, video: video);
/// ```
class ReportContentDialog extends ConsumerStatefulWidget {
  const ReportContentDialog({
    required this.video,
    super.key,
    this.isFromShareMenu = false,
  });

  final VideoEvent video;
  final bool isFromShareMenu;

  static Future<void> show(
    BuildContext context, {
    required VideoEvent video,
    bool isFromShareMenu = false,
  }) {
    return VineBottomSheet.show<void>(
      context: context,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      title: Text(context.l10n.reportTitle),
      body: ReportContentDialog(video: video, isFromShareMenu: isFromShareMenu),
    );
  }

  @override
  ConsumerState<ReportContentDialog> createState() =>
      _ReportContentDialogState();
}

class _ReportContentDialogState extends ConsumerState<ReportContentDialog> {
  ContentFilterReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            l10n.reportWhyReporting,
            style: VineTheme.titleMediumFont(),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.reportPolicyNotice,
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
          ),
          const SizedBox(height: 16),
          ...ContentFilterReason.values.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReasonCard(
                title: _getReasonTitle(reason),
                subtitle: _getReasonSubtitle(reason),
                isSelected: _selectedReason == reason,
                onTap: () => setState(() => _selectedReason = reason),
              ),
            ),
          ),
          if (_selectedReason == ContentFilterReason.other) ...[
            const SizedBox(height: 4),
            TextField(
              controller: _detailsController,
              enableInteractiveSelection: true,
              style: VineTheme.bodyMediumFont(),
              decoration: InputDecoration(
                labelText: l10n.reportDetailsRequired,
                labelStyle: VineTheme.bodyMediumFont(
                  color: VineTheme.onSurfaceMuted,
                ),
              ),
              maxLines: 3,
            ),
          ],
          const SizedBox(height: 24),
          DivineButton(
            label: l10n.reportSubmit,
            expanded: true,
            onPressed: _isSubmitting ? null : _handleSubmitReport,
            isLoading: _isSubmitting,
          ),
          SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
        ],
      ),
    );
  }

  void _handleSubmitReport() {
    if (_isSubmitting) return;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.reportSelectReason),
          backgroundColor: VineTheme.error,
        ),
      );
      return;
    }
    if (_selectedReason == ContentFilterReason.other &&
        _detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.reportOtherRequiresDetails),
          backgroundColor: VineTheme.error,
        ),
      );
      return;
    }
    _submitReport();
  }

  String _getReasonTitle(ContentFilterReason reason) {
    final l10n = context.l10n;
    return switch (reason) {
      ContentFilterReason.spam => l10n.reportReasonSpam,
      ContentFilterReason.harassment => l10n.reportReasonHarassment,
      ContentFilterReason.violence => l10n.reportReasonViolence,
      ContentFilterReason.sexualContent => l10n.reportReasonSexualContent,
      ContentFilterReason.copyright => l10n.reportReasonCopyright,
      ContentFilterReason.falseInformation => l10n.reportReasonFalseInfo,
      ContentFilterReason.csam => l10n.reportReasonCsam,
      ContentFilterReason.aiGenerated => l10n.reportReasonAiGenerated,
      ContentFilterReason.other => l10n.reportReasonOther,
    };
  }

  String _getReasonSubtitle(ContentFilterReason reason) {
    final l10n = context.l10n;
    return switch (reason) {
      ContentFilterReason.spam => l10n.reportReasonSpamSubtitle,
      ContentFilterReason.harassment => l10n.reportReasonHarassmentSubtitle,
      ContentFilterReason.violence => l10n.reportReasonViolenceSubtitle,
      ContentFilterReason.sexualContent =>
        l10n.reportReasonSexualContentSubtitle,
      ContentFilterReason.copyright => l10n.reportReasonCopyrightSubtitle,
      ContentFilterReason.falseInformation =>
        l10n.reportReasonFalseInfoSubtitle,
      ContentFilterReason.csam => l10n.reportReasonCsamSubtitle,
      ContentFilterReason.aiGenerated => l10n.reportReasonAiGeneratedSubtitle,
      ContentFilterReason.other => l10n.reportReasonOtherSubtitle,
    };
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isSubmitting = true);

    try {
      final reportService = await ref.read(
        contentReportingServiceProvider.future,
      );
      final result = await reportService.reportContent(
        eventId: widget.video.id,
        authorPubkey: widget.video.pubkey,
        reason: _selectedReason!,
        details: _detailsController.text.trim().isEmpty
            ? _getReasonTitle(_selectedReason!)
            : _detailsController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close the bottom sheet
        if (widget.isFromShareMenu) {
          Navigator.of(context).pop(); // Also close share menu
        }

        if (result.success) {
          // Send DM to moderation team with report details (TC-025/026)
          final dmRepo = ref.read(dmRepositoryProvider);
          final labelService = ref.read(moderationLabelServiceProvider);
          try {
            await dmRepo.sendMessage(
              recipientPubkey: labelService.divineModerationPubkeyHex,
              content: _formatReportDm(
                reason: _selectedReason!,
                eventId: widget.video.id,
                details: _detailsController.text.trim(),
              ),
            );
          } catch (e) {
            Log.warning(
              'Failed to send moderation DM: $e',
              name: 'ReportContentDialog',
              category: LogCategory.system,
            );
          }

          if (mounted) {
            showDialog<void>(
              context: context,
              builder: (context) => const ReportConfirmationDialog(),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.reportFailed(result.error ?? '')),
                backgroundColor: VineTheme.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      Log.error(
        'Failed to submit report: $e',
        name: 'ReportContentDialog',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.reportFailed(e)),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatReportDm({
    required ContentFilterReason reason,
    required String eventId,
    required String details,
  }) {
    final buffer = StringBuffer()
      ..writeln('Content Report')
      ..writeln('Reason: ${_getReasonTitle(reason)}')
      ..writeln('Event: $eventId');
    if (details.isNotEmpty) {
      buffer.writeln('Details: $details');
    }
    return buffer.toString().trimRight();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }
}

// =============================================================================
// Reason card
// =============================================================================

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? VineTheme.vineGreen
                  : VineTheme.outlinedDisabled,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              _RadioIndicator(isSelected: isSelected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: VineTheme.bodyLargeFont(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: VineTheme.bodySmallFont(
                        color: VineTheme.onSurfaceMuted,
                      ),
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

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? VineTheme.vineGreen : VineTheme.transparent,
          border: Border.all(color: VineTheme.vineGreen, width: 2),
        ),
        child: isSelected
            ? const Center(
                child: SizedBox.square(
                  dimension: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: VineTheme.whiteText,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

// =============================================================================
// Confirmation dialog (shown after successful report submission)
// =============================================================================

/// Confirmation dialog shown after successfully reporting content.
///
/// Used by [ReportContentDialog], [share_video_menu.dart], and
/// [report_message_dialog.dart].
class ReportConfirmationDialog extends StatelessWidget {
  const ReportConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: Row(
        spacing: 12,
        children: [
          const Icon(Icons.check_circle, color: VineTheme.vineGreen, size: 28),
          Text(
            l10n.reportReceivedTitle,
            style: const TextStyle(color: VineTheme.whiteText),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reportReceivedThankYou,
            style: const TextStyle(color: VineTheme.whiteText, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.reportReceivedReviewNotice,
            style: const TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () async {
              final uri = Uri.parse('https://divine.video/safety');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VineTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: VineTheme.vineGreen),
              ),
              child: Row(
                spacing: 8,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: VineTheme.vineGreen,
                    size: 20,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.reportLearnMore,
                          style: const TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.reportSafetyUrl,
                          style: const TextStyle(
                            color: VineTheme.vineGreen,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new,
                    color: VineTheme.vineGreen,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: Text(
            l10n.reportClose,
            style: const TextStyle(color: VineTheme.vineGreen),
          ),
        ),
      ],
    );
  }
}
