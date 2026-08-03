// ABOUTME: Report content bottom sheet for Apple-compliant content reporting.
// ABOUTME: Replaces the legacy AlertDialog with a VineBottomSheet-based flow.

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/content_filter_reason_localizations.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/services/content_moderation_types.dart';
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
                ? _ReportConfirmationBody(
                    moderationDmFailed: _moderationDmFailed,
                  )
                : _ReportFormBody(
                    selectedReason: _selectedReason,
                    onReasonSelected: _onReasonSelected,
                    detailsController: _detailsController,
                    detailsFocusNode: _detailsFocusNode,
                    detailsFieldKey: _detailsFieldKey,
                    otherCardKey: _otherCardKey,
                    errorMessage: _errorMessage,
                    onDetailsChanged: _clearErrorMessage,
                  ),
          ),
        ),
        _SheetFooter(
          child: _submitted
              ? _ReportConfirmationActions(
                  isFromShareMenu: widget.isFromShareMenu,
                )
              : DivineButton(
                  label: context.l10n.reportSubmit,
                  expanded: true,
                  onPressed: _canSubmit ? _handleSubmitReport : null,
                  isLoading: _isSubmitting,
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
        if (result.success) {
          // Send DM to moderation team with report details (TC-025/026)
          final dmRepo = ref.read(dmRepositoryProvider);
          final labelService = ref.read(moderationLabelServiceProvider);
          var moderationDmFailed = false;
          try {
            await dmRepo.sendMessage(
              recipientPubkey: labelService.divineModerationPubkeyHex,
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
          } catch (e) {
            // The report itself already succeeded (relay + Zendesk); the
            // moderation DM is a secondary notification. Don't fail the
            // flow, but surface the outcome instead of swallowing it so
            // the user isn't told the team was reached when it wasn't.
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

/// Action area pinned below the sheet's scrollable content.
///
/// Rides above the keyboard the same way [VineBottomSheet]'s `bottomInput`
/// slot does — the report form's details field lives in the scroll area
/// above, and a footer flush with the keyboard would put the button under it.
class _SheetFooter extends StatelessWidget {
  const _SheetFooter({required this.child});

  /// Gap kept between a raised keyboard and the footer.
  static const double _keyboardClearance = 12;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: keyboardInset > 0 ? keyboardInset + _keyboardClearance : 0,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      ),
    );
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
    required this.errorMessage,
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

  final String? errorMessage;
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
        if (errorMessage case final message?) ...[
          const SizedBox(height: 16),
          _InlineError(message: message),
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
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
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
// Confirmation view (shown inside the sheet after successful submission)
// =============================================================================

class _ReportConfirmationBody extends StatelessWidget {
  const _ReportConfirmationBody({required this.moderationDmFailed});

  /// Whether the secondary NIP-17 DM to the moderation team failed to
  /// send. The report itself still succeeded; this only drives a calm
  /// informational notice so the user isn't misled.
  final bool moderationDmFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
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
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.reportReceivedThankYou,
          style: VineTheme.bodyLargeFont(color: context.vineColors.primaryText),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.reportReceivedReviewNotice,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        if (moderationDmFailed) ...[
          const SizedBox(height: 12),
          Text(
            l10n.reportModerationDmDelayed,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
        ],
        const SizedBox(height: 8),
        const _SafetyPolicyLink(),
      ],
    );
  }
}

class _SafetyPolicyLink extends StatelessWidget {
  const _SafetyPolicyLink();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.reportSafetyUrl,
      child: GestureDetector(
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
                  color: context.vineColors.onSurfaceMuted,
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
    );
  }
}

/// Footer actions for the post-submission confirmation.
class _ReportConfirmationActions extends ConsumerWidget {
  const _ReportConfirmationActions({required this.isFromShareMenu});

  final bool isFromShareMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currentPubkey = ref.read(authServiceProvider).currentPublicKeyHex;
    final moderationPubkey = ref
        .read(moderationLabelServiceProvider)
        .divineModerationPubkeyHex;
    // The moderation conversation is an ordinary NIP-17 thread; deep-link
    // straight to it so the user can follow up about their report. Null
    // when we have no current pubkey (signed out) — the button hides.
    final moderationConversationId =
        (currentPubkey != null && currentPubkey.isNotEmpty)
        ? DmRepository.computeConversationId([currentPubkey, moderationPubkey])
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (moderationConversationId case final conversationId?)
          DivineButton(
            label: l10n.reportContactModeration,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: () {
              // Capture the router before popping the sheet so the push
              // doesn't run against a defunct context.
              final router = GoRouter.of(context);
              final navigator = Navigator.of(context);
              navigator.pop();
              if (isFromShareMenu) {
                navigator.pop();
              }
              router.push(
                ConversationPage.pathForId(conversationId),
                extra: [moderationPubkey],
              );
            },
          ),
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
