// ABOUTME: Report content bottom sheet for Apple-compliant content reporting.
// ABOUTME: Replaces the legacy AlertDialog with a VineBottomSheet-based flow.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/content_filter_reason_localizations.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows a [VineBottomSheet] for reporting content or a user.
///
/// Usage:
/// ```dart
/// await ReportContentDialog.show(context, video: video);
/// await ReportContentDialog.showForMessage(
///   context,
///   messageId: message.id,
///   senderPubkey: message.senderPubkey,
/// );
/// await ReportContentDialog.showForUser(
///   context,
///   userPubkey: pubkey,
/// );
/// ```
class ReportContentDialog extends ConsumerStatefulWidget {
  ReportContentDialog({
    super.key,
    this.video,
    this.eventId,
    this.authorPubkey,
    this.userPubkey,
    this.moderationKindLabel = 'Content Report',
    this.moderationEventLabel = 'Event',
    this.isFromShareMenu = false,
    this.draggableController,
  }) {
    final hasVideo = video != null;
    final hasContent = eventId != null && authorPubkey != null;
    final hasUser = userPubkey != null;
    if (!hasVideo && !hasContent && !hasUser) {
      throw ArgumentError(
        'Provide a video, both eventId and authorPubkey, or a userPubkey.',
      );
    }
  }

  /// The video being reported. When non-null, [eventId] / [authorPubkey]
  /// fall back to `video.id` / `video.pubkey`.
  final VideoEvent? video;

  /// Event id of the content being reported. Required when [video] is null
  /// and this is not a user-targeted report.
  final String? eventId;

  /// Author pubkey of the content being reported. Required when [video]
  /// is null and this is not a user-targeted report.
  final String? authorPubkey;

  /// Pubkey of the user being reported.
  ///
  /// When non-null, the report targets the user (no specific event) and
  /// the dialog routes through [ContentReportingService.reportUser]
  /// instead of [ContentReportingService.reportContent].
  final String? userPubkey;

  /// Header used in the moderation DM (e.g. "Content Report", "DM
  /// Message Report"). Internal-only — not user-visible.
  final String moderationKindLabel;

  /// Label preceding the event id in the moderation DM body (e.g.
  /// "Event", "Message ID"). Internal-only — not user-visible.
  final String moderationEventLabel;

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

  /// Shows the bottom sheet for reporting a DM message. Uses the same UX
  /// as the video flow; differs only in the moderation-DM body labels.
  static Future<void> showForMessage(
    BuildContext context, {
    required String messageId,
    required String senderPubkey,
  }) {
    final controller = DraggableScrollableController();
    return context
        .showVideoPausingVineBottomSheet<void>(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          draggableController: controller,
          body: ReportContentDialog(
            eventId: messageId,
            authorPubkey: senderPubkey,
            moderationKindLabel: 'DM Message Report',
            moderationEventLabel: 'Message ID',
            draggableController: controller,
          ),
        )
        .whenComplete(controller.dispose);
  }

  /// Shows the bottom sheet for reporting a user account (e.g. for
  /// harassment, impersonation, or underage account claims).
  ///
  /// Routes submission through [ContentReportingService.reportUser], which
  /// emits a NIP-56 report with the synthetic `user_<pubkey>` event id.
  static Future<void> showForUser(
    BuildContext context, {
    required String userPubkey,
  }) {
    final controller = DraggableScrollableController();
    return context
        .showVideoPausingVineBottomSheet<void>(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          draggableController: controller,
          body: ReportContentDialog(
            userPubkey: userPubkey,
            moderationKindLabel: 'User Report',
            moderationEventLabel: 'User Pubkey',
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

  bool get _isUserReport => widget.userPubkey != null;

  String get _eventId {
    final userPubkey = widget.userPubkey;
    if (userPubkey != null) return 'user_$userPubkey';
    return widget.eventId ?? widget.video!.id;
  }

  String get _authorPubkey =>
      widget.userPubkey ?? widget.authorPubkey ?? widget.video!.pubkey;

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
          Text(l10n.reportWhyReporting, style: VineTheme.titleMediumFont()),
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
                title: l10n.reportReasonTitle(reason),
                subtitle: l10n.reportReasonSubtitle(reason),
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

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isSubmitting = true);
    final selectedReasonTitle = context.l10n.reportReasonTitle(
      _selectedReason!,
    );

    try {
      final reportService = await ref.read(
        contentReportingServiceProvider.future,
      );
      final details = _detailsController.text.trim().isEmpty
          ? selectedReasonTitle
          : _detailsController.text.trim();
      final result = _isUserReport
          ? await reportService.reportUser(
              userPubkey: widget.userPubkey!,
              reason: _selectedReason!,
              details: details,
            )
          : await reportService.reportContent(
              eventId: _eventId,
              authorPubkey: _authorPubkey,
              reason: _selectedReason!,
              details: details,
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
                eventId: _eventId,
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
      ..writeln(widget.moderationKindLabel)
      ..writeln('Reason: ${context.l10n.reportReasonTitle(reason)}')
      ..writeln('${widget.moderationEventLabel}: $eventId');
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
          Text(l10n.reportReceivedThankYou, style: VineTheme.bodyLargeFont()),
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
                    style: VineTheme.bodyMediumFont(color: VineTheme.vineGreen),
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
                    Text(title, style: VineTheme.bodyLargeFont()),
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
/// Used by `share_video_menu.dart`. [ReportContentDialog] (both video and
/// DM-message variants) uses the in-sheet [_ReportConfirmationView] instead.
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
