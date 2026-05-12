// ABOUTME: Report content bottom sheet for Apple-compliant content reporting.
// ABOUTME: Replaces the legacy AlertDialog with a VineBottomSheet-based flow.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
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
    this.draggableController,
  });

  final VideoEvent video;
  final bool isFromShareMenu;

  /// Optional controller used to programmatically expand the bottom sheet
  /// to full height when the "Other" reason is selected (so the details
  /// field is reachable above the keyboard).
  final DraggableScrollableController? draggableController;

  static Future<void> show(
    BuildContext context, {
    required VideoEvent video,
    bool isFromShareMenu = false,
  }) {
    final controller = DraggableScrollableController();
    return context
        .showVideoPausingVineBottomSheet<void>(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          draggableController: controller,
          body: ReportContentDialog(
            video: video,
            isFromShareMenu: isFromShareMenu,
            draggableController: controller,
          ),
        )
        .whenComplete(controller.dispose);
  }

  @override
  ConsumerState<ReportContentDialog> createState() =>
      _ReportContentDialogState();
}

class _ReportContentDialogState extends ConsumerState<ReportContentDialog> {
  ContentFilterReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  final FocusNode _detailsFocusNode = FocusNode();
  final GlobalKey _detailsFieldKey = GlobalKey();
  final GlobalKey _otherCardKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  bool _isSubmitting = false;
  bool _submitted = false;
  bool _scrollWhenKeyboardOpens = false;
  double _previousViewInsetsBottom = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBottom = MediaQuery.viewInsetsOf(context).bottom;
    if (_scrollWhenKeyboardOpens &&
        currentBottom > _previousViewInsetsBottom &&
        currentBottom > 100) {
      _scrollWhenKeyboardOpens = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _otherCardKey.currentContext;
        if (ctx == null) return;
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
    _previousViewInsetsBottom = currentBottom;
  }

  void _onReasonSelected(ContentFilterReason reason) {
    final wasOther = _selectedReason == ContentFilterReason.other;
    setState(() => _selectedReason = reason);

    if (reason == ContentFilterReason.other && !wasOther) {
      final controller = widget.draggableController;
      if (controller != null && controller.isAttached) {
        controller.animateTo(
          0.95,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      _scrollWhenKeyboardOpens = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _detailsFocusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return _ReportConfirmationView(isFromShareMenu: widget.isFromShareMenu);
    }

    final l10n = context.l10n;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeAreaBottom = MediaQuery.viewPaddingOf(context).bottom;
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        8,
        16,
        24 + keyboardInset + safeAreaBottom,
      ),
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
              key: reason == ContentFilterReason.other ? _otherCardKey : null,
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReasonCard(
                title: _getReasonTitle(reason),
                subtitle: _getReasonSubtitle(reason),
                isSelected: _selectedReason == reason,
                onTap: () => _onReasonSelected(reason),
              ),
            ),
          ),
          if (_selectedReason == ContentFilterReason.other) ...[
            const SizedBox(height: 4),
            DecoratedBox(
              decoration: BoxDecoration(
                color: VineTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      l10n.reportDetailsRequired,
                      style: VineTheme.labelSmallFont(
                        color: VineTheme.vineGreen,
                      ),
                    ),
                    TextField(
                      key: _detailsFieldKey,
                      controller: _detailsController,
                      focusNode: _detailsFocusNode,
                      enableInteractiveSelection: true,
                      style: VineTheme.bodyLargeFont(),
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          DivineButton(
            label: l10n.reportSubmit,
            expanded: true,
            onPressed: _isSubmitting ? null : _handleSubmitReport,
            isLoading: _isSubmitting,
          ),
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
            setState(() => _submitted = true);
            final controller = widget.draggableController;
            if (controller != null && controller.isAttached) {
              controller.animateTo(
                0.65,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.reportFailed(result.error ?? '')),
              backgroundColor: VineTheme.error,
            ),
          );
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
    _detailsFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// =============================================================================
// Confirmation view (shown inside the sheet after successful submission)
// =============================================================================

class _ReportConfirmationView extends StatelessWidget {
  const _ReportConfirmationView({required this.isFromShareMenu});

  final bool isFromShareMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            spacing: 12,
            children: [
              const DivineIcon(
                icon: DivineIconName.checkCircle,
                color: VineTheme.vineGreen,
                size: 28,
              ),
              Expanded(
                child: Text(
                  l10n.reportReceivedTitle,
                  style: VineTheme.titleMediumFont(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.reportReceivedThankYou,
            style: VineTheme.bodyLargeFont(),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.reportReceivedReviewNotice,
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('https://divine.video/safety');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${l10n.reportLearnMoreAt} ',
                    style: VineTheme.bodyMediumFont(
                      color: VineTheme.onSurfaceMuted,
                    ),
                  ),
                  TextSpan(
                    text: l10n.reportSafetyUrl,
                    style: VineTheme.bodyMediumFont(
                      color: VineTheme.vineGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          DivineButton(
            label: l10n.reportClose,
            expanded: true,
            onPressed: () {
              Navigator.of(context).pop();
              if (isFromShareMenu) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
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
            borderRadius: BorderRadius.circular(24),
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
                child: DivineIcon(
                  icon: DivineIconName.check,
                  size: 14,
                  color: VineTheme.surfaceBackground,
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
/// Used by [share_video_menu.dart] and [report_message_dialog.dart].
/// [ReportContentDialog] uses [_ReportConfirmationView] (in-sheet) instead.
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
