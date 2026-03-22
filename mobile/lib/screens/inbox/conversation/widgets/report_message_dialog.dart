// ABOUTME: Report dialog for DM messages.
// ABOUTME: Same category selection and submission flow as ReportContentDialog
// ABOUTME: but accepts a message ID and sender pubkey instead of VideoEvent.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/report_content_dialog.dart';

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
    title: const Text(
      'Report Message',
      style: TextStyle(color: VineTheme.whiteText),
    ),
    content: SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Why are you reporting this message?',
              style: TextStyle(color: VineTheme.whiteText),
            ),
            const SizedBox(height: 8),
            const Text(
              'Divine will act on content reports within 24 hours by '
              'removing the content and ejecting the user who provided '
              'the offending content.',
              style: TextStyle(
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
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                labelStyle: TextStyle(color: VineTheme.secondaryText),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text(
                'Block this user',
                style: TextStyle(color: VineTheme.whiteText),
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
      TextButton(onPressed: context.pop, child: const Text('Cancel')),
      TextButton(
        onPressed: _isSubmitting ? null : _handleSubmitReport,
        child: _isSubmitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Report'),
      ),
    ],
  );

  void _handleSubmitReport() {
    if (_isSubmitting) return;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason for reporting this message'),
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

    try {
      final reportService = await ref.read(
        contentReportingServiceProvider.future,
      );
      final result = await reportService.reportContent(
        eventId: widget.messageId,
        authorPubkey: widget.senderPubkey,
        reason: _selectedReason!,
        details: _detailsController.text.trim().isEmpty
            ? _getReasonDisplayName(_selectedReason!)
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
                  '${_getReasonDisplayName(_selectedReason!)}',
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
            SnackBar(
              content: Text('Failed to report message: ${result.error}'),
              backgroundColor: VineTheme.error,
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
          SnackBar(
            content: Text('Failed to report message: $e'),
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

  String _getReasonDisplayName(ContentFilterReason reason) {
    return switch (reason) {
      ContentFilterReason.spam => 'Spam or Unwanted Content',
      ContentFilterReason.harassment => 'Harassment, Bullying, or Threats',
      ContentFilterReason.violence => 'Violent or Extremist Content',
      ContentFilterReason.sexualContent => 'Sexual or Adult Content',
      ContentFilterReason.copyright => 'Copyright Violation',
      ContentFilterReason.falseInformation => 'False Information',
      ContentFilterReason.csam => 'Child Safety Violation',
      ContentFilterReason.aiGenerated => 'AI-Generated Content',
      ContentFilterReason.other => 'Other Policy Violation',
    };
  }

  String _formatReportDm({
    required ContentFilterReason reason,
    required String messageId,
    required String details,
  }) {
    final buffer = StringBuffer()
      ..writeln('DM Message Report')
      ..writeln('Reason: ${_getReasonDisplayName(reason)}')
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
