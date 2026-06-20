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
  bool _moderationDmFailed = false;
  String? _errorMessage;
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
    if (_submitted) {
      final currentPubkey = ref.read(authServiceProvider).currentPublicKeyHex;
      final moderationPubkey = ref
          .read(moderationLabelServiceProvider)
          .divineModerationPubkeyHex;
      // The moderation conversation is an ordinary NIP-17 thread; deep-link
      // straight to it so the user can follow up about their report. Null
      // when we have no current pubkey (signed out) — the button hides.
      final moderationConversationId =
          (currentPubkey != null && currentPubkey.isNotEmpty)
          ? DmRepository.computeConversationId([
              currentPubkey,
              moderationPubkey,
            ])
          : null;
      return _ReportConfirmationView(
        isFromShareMenu: widget.isFromShareMenu,
        moderationDmFailed: _moderationDmFailed,
        moderationPubkey: moderationPubkey,
        moderationConversationId: moderationConversationId,
      );
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
                      onChanged: (_) {
                        if (_errorMessage == null) return;
                        setState(() => _errorMessage = null);
                      },
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
          if (_errorMessage case final errorMessage?) ...[
            const SizedBox(height: 16),
            Semantics(
              container: true,
              liveRegion: true,
              label: errorMessage,
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
                          errorMessage,
                          style: VineTheme.bodySmallFont(
                            color: VineTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
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
      setState(() {
        _errorMessage = context.l10n.reportSelectReason;
      });
      return;
    }
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
    _scrollController.dispose();
    super.dispose();
  }
}

// =============================================================================
// Confirmation view (shown inside the sheet after successful submission)
// =============================================================================

class _ReportConfirmationView extends StatelessWidget {
  const _ReportConfirmationView({
    required this.isFromShareMenu,
    required this.moderationDmFailed,
    required this.moderationPubkey,
    required this.moderationConversationId,
  });

  final bool isFromShareMenu;

  /// Whether the secondary NIP-17 DM to the moderation team failed to
  /// send. The report itself still succeeded; this only drives a calm
  /// informational notice so the user isn't misled.
  final bool moderationDmFailed;

  /// The Divine moderation account pubkey, passed to the conversation
  /// route so it can render the thread.
  final String moderationPubkey;

  /// The 1:1 conversation id between the current user and the moderation
  /// account. Null when signed out — the "Message the moderation team"
  /// affordance is hidden in that case.
  final String? moderationConversationId;

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
          if (moderationDmFailed) ...[
            const SizedBox(height: 12),
            Text(
              l10n.reportModerationDmDelayed,
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
            ),
          ],
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
          if (moderationConversationId case final conversationId?) ...[
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
            const SizedBox(height: 8),
          ],
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
          const DivineIcon(
            icon: DivineIconName.checkCircle,
            color: VineTheme.vineGreen,
            size: 28,
          ),
          Text(l10n.reportReceivedTitle, style: VineTheme.titleMediumFont()),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.reportReceivedThankYou, style: VineTheme.bodyLargeFont()),
          const SizedBox(height: 16),
          Text(
            l10n.reportReceivedReviewNotice,
            style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
          ),
          const SizedBox(height: 20),
          Semantics(
            button: true,
            label: l10n.reportLearnMore,
            child: InkWell(
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
                    const DivineIcon(
                      icon: DivineIconName.info,
                      color: VineTheme.vineGreen,
                      size: 20,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.reportLearnMore,
                            style: VineTheme.titleSmallFont(),
                          ),
                          Text(
                            l10n.reportSafetyUrl,
                            style: VineTheme.labelSmallFont(
                              color: VineTheme.vineGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const DivineIcon(
                      icon: DivineIconName.arrowUpRight,
                      color: VineTheme.vineGreen,
                      size: 18,
                    ),
                  ],
                ),
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
            style: VineTheme.labelLargeFont(color: VineTheme.vineGreen),
          ),
        ),
      ],
    );
  }
}
