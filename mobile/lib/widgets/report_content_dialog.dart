// ABOUTME: Standalone report content dialog for Apple-compliant content reporting
// ABOUTME: Extracted from share_video_menu.dart for reuse across the app

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dialog for reporting content
/// Public report content dialog that can be used from anywhere
class ReportContentDialog extends ConsumerStatefulWidget {
  const ReportContentDialog({
    required this.video,
    super.key,
    this.isFromShareMenu = false,
  });
  final VideoEvent video;
  final bool isFromShareMenu;

  @override
  ConsumerState<ReportContentDialog> createState() =>
      _ReportContentDialogState();
}

class _ReportContentDialogState extends ConsumerState<ReportContentDialog> {
  ContentFilterReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _blockUser = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: Text(
        l10n.reportTitle,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.reportWhyReporting,
                style: const TextStyle(color: VineTheme.whiteText),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.reportPolicyNotice,
                style: const TextStyle(
                  color: VineTheme.secondaryText,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              RadioGroup<ContentFilterReason>(
                groupValue: _selectedReason,
                onChanged: (value) => setState(() => _selectedReason = value),
                child: Column(
                  children: ContentFilterReason.values
                      .map(
                        (reason) => RadioListTile<ContentFilterReason>(
                          title: Text(
                            _getReasonDisplayName(reason),
                            style: const TextStyle(color: VineTheme.whiteText),
                          ),
                          value: reason,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _detailsController,
                enableInteractiveSelection: true,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: InputDecoration(
                  labelText: l10n.reportAdditionalDetails,
                  labelStyle: const TextStyle(color: VineTheme.secondaryText),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: Text(
                  l10n.reportBlockUser,
                  style: const TextStyle(color: VineTheme.whiteText),
                ),
                value: _blockUser,
                onChanged: (value) =>
                    setState(() => _blockUser = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: context.pop, child: Text(l10n.reportCancel)),
        TextButton(
          onPressed: _isSubmitting ? null : _handleSubmitReport,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.reportSubmit),
        ),
      ],
    );
  }

  void _handleSubmitReport() {
    if (_isSubmitting) return;
    if (_selectedReason == null) {
      // Show error when no reason selected (Apple requires button to be visible)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.reportSelectReason),
          backgroundColor: VineTheme.error,
        ),
      );
      return;
    }
    _submitReport();
  }

  String _getReasonDisplayName(ContentFilterReason reason) {
    final l10n = context.l10n;
    switch (reason) {
      case ContentFilterReason.spam:
        return l10n.reportReasonSpam;
      case ContentFilterReason.harassment:
        return l10n.reportReasonHarassment;
      case ContentFilterReason.violence:
        return l10n.reportReasonViolence;
      case ContentFilterReason.sexualContent:
        return l10n.reportReasonSexualContent;
      case ContentFilterReason.copyright:
        return l10n.reportReasonCopyright;
      case ContentFilterReason.falseInformation:
        return l10n.reportReasonFalseInfo;
      case ContentFilterReason.csam:
        return l10n.reportReasonCsam;
      case ContentFilterReason.aiGenerated:
        return l10n.reportReasonAiGenerated;
      case ContentFilterReason.other:
        return l10n.reportReasonOther;
    }
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
            ? _getReasonDisplayName(_selectedReason!)
            : _detailsController.text.trim(),
      );

      if (mounted) {
        context.pop(); // Close report dialog
        if (widget.isFromShareMenu) {
          context.pop(); // Close share menu (only if opened from share menu)
        }

        if (result.success) {
          // Block user if checkbox was checked.
          // The Kind 1984 published by reportContent() already includes the
          // author pubkey in the `p` tag, so no second Kind 1984 is needed.
          if (_blockUser) {
            // 1. Add to mute list (publishes kind 10000 NIP-51 mute list)
            final muteService = await ref.read(muteServiceProvider.future);
            await muteService.muteUser(
              widget.video.pubkey,
              reason:
                  'Reported and blocked for ${_getReasonDisplayName(_selectedReason!)}',
            );

            // 2. Also add to local blocklist for immediate filtering
            final blocklistService = ref.read(contentBlocklistServiceProvider);
            final nostrClient = ref.read(nostrServiceProvider);
            blocklistService.blockUser(
              widget.video.pubkey,
              ourPubkey: nostrClient.publicKey,
            );

            Log.info(
              'User blocked: kind 10000 mute list published for ${widget.video.pubkey}',
              name: 'ReportContentDialog',
              category: LogCategory.ui,
            );
          }

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
            // Report was already submitted via NIP-56 + ZenDesk;
            // DM is a supplementary notification channel.
            Log.warning(
              'Failed to send moderation DM: $e',
              name: 'ReportContentDialog',
              category: LogCategory.system,
            );
          }

          // Show success confirmation dialog using root navigator
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => const ReportConfirmationDialog(),
            );
          }
        } else {
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.reportFailed(result.error ?? ''),
              ),
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
      ..writeln('Reason: ${_getReasonDisplayName(reason)}')
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

/// Confirmation dialog shown after successfully reporting content
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
          const Icon(
            Icons.check_circle,
            color: VineTheme.vineGreen,
            size: 28,
          ),
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
          onPressed: context.pop,
          child: Text(
            l10n.reportClose,
            style: const TextStyle(color: VineTheme.vineGreen),
          ),
        ),
      ],
    );
  }
}
