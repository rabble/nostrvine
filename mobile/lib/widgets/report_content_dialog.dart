// ABOUTME: Report content bottom sheet for Apple-compliant content reporting.
// ABOUTME: Replaces the legacy AlertDialog with a VineBottomSheet-based flow.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/content_filter_reason_localizations.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/report_content_confirmation.dart';
import 'package:unified_logger/unified_logger.dart';

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
    this.scrollController,
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

  /// Scroll controller handed down by the enclosing [VineBottomSheet].
  ///
  /// The sheet's [DraggableScrollableSheet] only reacts to a downward drag
  /// when its own controller drives the scroll view inside it — with a
  /// foreign controller the drag is swallowed by the content and the sheet
  /// can no longer be pulled closed. Null when the dialog is shown outside a
  /// draggable sheet, where an internal controller stands in.
  final ScrollController? scrollController;

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
          buildScrollBody: (scrollController) => ReportContentDialog(
            video: video,
            isFromShareMenu: isFromShareMenu,
            draggableController: controller,
            scrollController: scrollController,
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
          buildScrollBody: (scrollController) => ReportContentDialog(
            eventId: messageId,
            authorPubkey: senderPubkey,
            moderationKindLabel: 'DM Message Report',
            moderationEventLabel: 'Message ID',
            draggableController: controller,
            scrollController: scrollController,
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
          buildScrollBody: (scrollController) => ReportContentDialog(
            userPubkey: userPubkey,
            moderationKindLabel: 'User Report',
            moderationEventLabel: 'User Pubkey',
            draggableController: controller,
            scrollController: scrollController,
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
  final ScrollController _fallbackScrollController = ScrollController();
  bool _isSubmitting = false;
  bool _submitted = false;
  bool _moderationDmFailed = false;
  String? _errorMessage;
  bool _scrollWhenKeyboardOpens = false;
  double _previousViewInsetsBottom = 0;

  bool get _isUserReport => widget.userPubkey != null;

  ScrollController get _scrollController =>
      widget.scrollController ?? _fallbackScrollController;

  /// Submission needs a reason; "Other" additionally needs details, but that
  /// stays a tap-time inline error so the reason for the block is explained.
  bool get _canSubmit => _selectedReason != null && !_isSubmitting;

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
    setState(() {
      _selectedReason = reason;
      _errorMessage = null;
    });

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
    // One scroll view across both states so the sheet's scroll controller
    // stays attached to a single position when the form is swapped for the
    // confirmation — the actions ride in the pinned footer instead.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
            child: _submitted
                ? ReportConfirmationBody(
                    moderationDmFailed: _moderationDmFailed,
                  )
                : _ReportFormBody(
                    selectedReason: _selectedReason,
                    onReasonSelected: _onReasonSelected,
                    detailsController: _detailsController,
                    detailsFocusNode: _detailsFocusNode,
                    detailsFieldKey: _detailsFieldKey,
                    otherCardKey: _otherCardKey,
                    onDetailsChanged: _clearErrorMessage,
                  ),
          ),
        ),
        // The error rides the footer rather than the end of the scroll
        // content: with the submit action pinned, the user can submit from
        // any scroll offset, and an error appended below eleven reason cards
        // lands off-screen — the tap would look like it did nothing.
        VineKeyboardAwareFooter(
          includeSafeArea: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _submitted
                ? ReportConfirmationActions(
                    isFromShareMenu: widget.isFromShareMenu,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      if (_errorMessage case final message?)
                        _InlineError(message: message),
                      DivineButton(
                        label: context.l10n.reportSubmit,
                        expanded: true,
                        onPressed: _canSubmit ? _handleSubmitReport : null,
                        isLoading: _isSubmitting,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _clearErrorMessage() {
    if (_errorMessage == null) return;
    setState(() => _errorMessage = null);
  }

  void _handleSubmitReport() {
    if (_isSubmitting) return;
    if (_selectedReason == ContentFilterReason.other &&
        _detailsController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = context.l10n.reportOtherRequiresDetails;
      });
      return;
    }
    _submitReport();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
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
              sourceRelay: widget.video?.sourceRelay,
            );

      if (mounted) {
        if (result.success && result.delivery == ReportDelivery.localOnly) {
          // Nothing left the device — every channel refused, which usually
          // means no connectivity. The confirmation screen would be false in
          // four places at once (its title, the review promise, the green
          // check, and any DM caveat), so don't show it: surface the failure
          // and leave Submit live so retrying is one tap. The moderation DM
          // is deliberately not attempted either — a retry re-sends
          // everything, and a queued DM plus a resubmit would deliver the
          // same report twice.
          setState(() {
            _errorMessage = context.l10n.reportFailed(
              context.l10n.commonSomethingWentWrong,
            );
          });
        } else if (result.success) {
          // Send DM to moderation team with report details (TC-025/026)
          final dmRepo = ref.read(dmRepositoryProvider);
          final labelService = ref.read(moderationLabelServiceProvider);
          final moderationPubkey = labelService.divineModerationPubkeyHex;
          var moderationDmFailed = false;
          try {
            final dmResult = await dmRepo.sendMessage(
              recipientPubkey: moderationPubkey,
              content: _formatReportDm(
                reason: _selectedReason!,
                eventId: _eventId,
                details: _detailsController.text.trim(),
              ),
              // Moderation reports carry user identity + reported content;
              // never let them degrade to a metadata-leaking NIP-04
              // plaintext duplicate. NIP-17 gift wrap only.
              skipNip04Fallback: true,
            );
            // sendMessage signals non-delivery by RETURNING a failure, not
            // by throwing, so the catch below cannot see it. Switch over the
            // sealed type rather than reading `.success` so a new variant
            // becomes a compile error here instead of a silent success.
            moderationDmFailed = switch (dmResult) {
              // Includes selfWrapPublished: false — the team received the
              // report; only the sender's own cross-device copy is missing.
              NIP17SendSuccess() => false,
              // blocked, retryablePending, and hard failures alike.
              NIP17SendFailure() => true,
            };
            if (dmResult case final NIP17SendFailure failure) {
              Log.warning(
                'Moderation DM not delivered '
                '(recipient=$moderationPubkey, '
                'blocked=${failure.blocked}, '
                'retryablePending=${failure.retryablePending}): '
                '${failure.error}',
                name: 'ReportContentDialog',
                category: LogCategory.system,
              );
            }
          } catch (e) {
            // The report reached the team through another channel; the
            // moderation DM is a secondary notification. Don't fail the
            // flow, but surface the outcome instead of swallowing it so
            // the user isn't told the team was reached when it wasn't.
            // Reachable for pre-flight throws only (uninitialized
            // repository, invalid recipient) — never for a delivery
            // outcome, which arrives as a returned value above.
            moderationDmFailed = true;
            Log.warning(
              'Failed to send moderation DM: $e',
              name: 'ReportContentDialog',
              category: LogCategory.system,
            );
          }

          if (mounted) {
            setState(() {
              _submitted = true;
              _moderationDmFailed = moderationDmFailed;
            });
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
          setState(() {
            _errorMessage = context.l10n.reportFailed(result.error ?? '');
          });
        }
      }
    } catch (e) {
      Log.error(
        'Failed to submit report: $e',
        name: 'ReportContentDialog',
        category: LogCategory.ui,
      );

      if (mounted) {
        setState(() => _errorMessage = context.l10n.reportFailed(e));
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
    _fallbackScrollController.dispose();
    super.dispose();
  }
}

// =============================================================================
// Report form
// =============================================================================

class _ReportFormBody extends StatelessWidget {
  const _ReportFormBody({
    required this.selectedReason,
    required this.onReasonSelected,
    required this.detailsController,
    required this.detailsFocusNode,
    required this.detailsFieldKey,
    required this.otherCardKey,
    required this.onDetailsChanged,
  });

  final ContentFilterReason? selectedReason;
  final ValueChanged<ContentFilterReason> onReasonSelected;
  final TextEditingController detailsController;
  final FocusNode detailsFocusNode;
  final GlobalKey detailsFieldKey;

  /// Anchors the "Other" card so it can be scrolled back into view once the
  /// keyboard pushes the details field up.
  final GlobalKey otherCardKey;

  /// Clears a pending validation error as soon as the user edits the details.
  final VoidCallback onDetailsChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.reportWhyReporting,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.reportPolicyNotice,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 16),
        ...ContentFilterReason.values.map(
          (reason) => Padding(
            key: reason == ContentFilterReason.other ? otherCardKey : null,
            padding: const EdgeInsets.only(bottom: 8),
            child: _ReasonCard(
              title: l10n.reportReasonTitle(reason),
              subtitle: l10n.reportReasonSubtitle(reason),
              isSelected: selectedReason == reason,
              onTap: () => onReasonSelected(reason),
            ),
          ),
        ),
        if (selectedReason == ContentFilterReason.other) ...[
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
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
                    style: VineTheme.labelSmallFont(color: VineTheme.vineGreen),
                  ),
                  TextField(
                    key: detailsFieldKey,
                    controller: detailsController,
                    focusNode: detailsFocusNode,
                    enableInteractiveSelection: true,
                    onChanged: (_) => onDetailsChanged(),
                    style: VineTheme.bodyLargeFont(
                      color: context.vineColors.primaryText,
                    ),
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
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    // `container` makes this its own node and absorbs the Text below, so the
    // live region already reads [message]. Repeating it as a `label:` here
    // would prepend a second copy.
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.error.withValues(alpha: 0.1),
          border: Border.all(color: VineTheme.error),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const DivineIcon(
                icon: DivineIconName.warningCircle,
                color: VineTheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: VineTheme.bodySmallFont(color: VineTheme.error),
                ),
              ),
            ],
          ),
        ),
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
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? VineTheme.vineGreen
                  : context.vineColors.surfaceContainer,
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
                      style: VineTheme.bodyLargeFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.onSurfaceMuted,
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
            ? Center(
                child: DivineIcon(
                  icon: DivineIconName.check,
                  size: 14,
                  color: context.vineColors.surface,
                ),
              )
            : null,
      ),
    );
  }
}
