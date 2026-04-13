// ABOUTME: Report dialog for DM messages.
// ABOUTME: Same category selection and submission flow as ReportContentDialog
// ABOUTME: but accepts a message ID and sender pubkey instead of VideoEvent.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:unified_logger/unified_logger.dart';

/// Dialog for reporting a DM message.
///
/// Follows the same pattern as [ReportConfirmationDialog] but accepts
/// a [messageId] (rumor event ID) and [senderPubkey] instead of a video.
class ReportMessageDialog extends ConsumerStatefulWidget {
  const ReportMessageDialog({
    required this.messageId,
    required this.senderPubkey,
    super.key,
  });

  /// The rumor event ID (kind 14) of the message being reported.
  final String messageId;

  /// The public key of the message sender.
  final String senderPubkey;

  @override
  ConsumerState<ReportMessageDialog> createState() =>
      _ReportMessageDialogState();
}

class _ReportMessageDialogState extends ConsumerState<ReportMessageDialog> {
  ContentFilterReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _blockUser = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: Text(
      'Report Message',
      style: VineTheme.titleMediumFont(),
    ),
    content: SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Why are you reporting this message?',
              style: VineTheme.bodyMediumFont(),
            ),
            const SizedBox(height: 8),
            Text(
              'Divine will act on content reports within 24 hours by '
              'removing the content and ejecting the user who provided '
              'the offending content.',
              style: VineTheme.bodySmallFont(
                color: VineTheme.secondaryText,
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
                          reason.description,
                          style: VineTheme.bodyMediumFont(),
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
              style: VineTheme.bodyMediumFont(),
              decoration: InputDecoration(
                labelText: 'Additional details (optional)',
                labelStyle: VineTheme.bodyMediumFont(
                  color: VineTheme.secondaryText,
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: Text(
                'Block this user',
                style: VineTheme.bodyMediumFont(),
              ),
              value: _blockUser,
              onChanged: (value) => setState(() => _blockUser = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: context.pop,
        child: Text(context.l10n.reportDialogCancel),
      ),
      TextButton(
        onPressed: _isSubmitting ? null : _handleSubmitReport,
        child: _isSubmitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(context.l10n.reportDialogReport),
      ),
    ],
  );

  void _handleSubmitReport() {
    if (_isSubmitting) return;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          'Please select a reason for reporting this message',
          error: true,
        ),
      );
      return;
    }
    _submitReport();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isSubmitting = true);

    try {
      final reportService = await ref.read(
        contentReportingServiceProvider.future,
      );
      final result = await reportService.reportContent(
        eventId: widget.messageId,
        authorPubkey: widget.senderPubkey,
        reason: _selectedReason!,
        details: _detailsController.text.trim().isEmpty
            ? _selectedReason!.description
            : _detailsController.text.trim(),
      );

      if (mounted) {
        context.pop();

        if (result.success) {
          if (_blockUser) {
            final muteService = await ref.read(muteServiceProvider.future);
            await muteService.muteUser(
              widget.senderPubkey,
              reason:
                  'Reported and blocked for '
                  '${_selectedReason!.description}',
            );

            final blocklistService = ref.read(contentBlocklistServiceProvider);
            final nostrClient = ref.read(nostrServiceProvider);
            blocklistService.blockUser(
              widget.senderPubkey,
              ourPubkey: nostrClient.publicKey,
            );

            Log.info(
              'User blocked: kind 10000 mute list published for '
              '${widget.senderPubkey}',
              name: 'ReportMessageDialog',
              category: LogCategory.ui,
            );
          }

          // Send DM to moderation team with report details
          final dmRepo = ref.read(dmRepositoryProvider);
          final labelService = ref.read(moderationLabelServiceProvider);
          try {
            await dmRepo.sendMessage(
              recipientPubkey: labelService.divineModerationPubkeyHex,
              content: _formatReportDm(
                reason: _selectedReason!,
                messageId: widget.messageId,
                details: _detailsController.text.trim(),
              ),
            );
          } catch (e) {
            Log.warning(
              'Failed to send moderation DM: $e',
              name: 'ReportMessageDialog',
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
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(
              'Failed to report message: ${result.error}',
              error: true,
            ),
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to submit report: $e',
        name: 'ReportMessageDialog',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            'Failed to report message: $e',
            error: true,
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
    required String messageId,
    required String details,
  }) {
    final buffer = StringBuffer()
      ..writeln('DM Message Report')
      ..writeln('Reason: ${reason.description}')
      ..writeln('Message ID: $messageId');
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
