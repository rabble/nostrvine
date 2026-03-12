// ABOUTME: Dialog widget for submitting feature requests to Zendesk
// ABOUTME: Collects structured data (subject, description, usefulness, when to use)
// ABOUTME: Submits directly to Zendesk via SDK or REST API with custom fields

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/support_dialog_utils.dart';

/// Dialog for collecting and submitting feature requests
class FeatureRequestDialog extends StatefulWidget {
  const FeatureRequestDialog({super.key, this.userPubkey});

  final String? userPubkey;

  @override
  State<FeatureRequestDialog> createState() => _FeatureRequestDialogState();
}

class _FeatureRequestDialogState extends State<FeatureRequestDialog> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _usefulnessController = TextEditingController();
  final _whenToUseController = TextEditingController();
  bool _isSubmitting = false;
  String? _resultMessage;
  bool? _isSuccess;
  bool _isDisposed = false;
  Timer? _closeTimer;

  @override
  void dispose() {
    _isDisposed = true;
    _closeTimer?.cancel();
    _subjectController.dispose();
    _descriptionController.dispose();
    _usefulnessController.dispose();
    _whenToUseController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_isSubmitting &&
      _subjectController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty;

  Future<void> _submitRequest() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _resultMessage = null;
      _isSuccess = null;
    });

    try {
      // Submit feature request to Zendesk
      // Prefix subject with "feat:" for ticket categorization
      final subject = 'feat: ${_subjectController.text.trim()}';
      final success = await ZendeskSupportService.createFeatureRequest(
        subject: subject,
        description: _descriptionController.text.trim(),
        usefulness: _usefulnessController.text.trim(),
        whenToUse: _whenToUseController.text.trim(),
        userPubkey: widget.userPubkey,
      );

      if (!_isDisposed && mounted) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = success;
          if (success) {
            _resultMessage =
                "Thank you! We've received your feature request and will review it.";
          } else {
            _resultMessage =
                'Failed to send feature request. Please try again later.';
          }
        });

        // Close dialog after delay if successful
        if (success) {
          _closeTimer = Timer(const Duration(milliseconds: 1500), () {
            if (!_isDisposed && mounted) {
              context.pop();
            }
          });
        }
      }
    } catch (e, stackTrace) {
      Log.error(
        'Error submitting feature request: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );

      if (!_isDisposed && mounted) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = false;
          _resultMessage = 'Feature request failed to send: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        'Request a Feature',
        style: TextStyle(color: VineTheme.whiteText),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subject field (required)
              TextField(
                controller: _subjectController,
                enabled: !_isSubmitting,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: buildSupportInputDecoration(
                  label: 'Subject *',
                  hint: 'Brief summary of your idea',
                  helper: 'Required',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Description field (required)
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                enabled: !_isSubmitting,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: buildSupportInputDecoration(
                  label: 'What would you like? *',
                  hint: 'Describe the feature you want',
                  helper: 'Required',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Usefulness field
              TextField(
                controller: _usefulnessController,
                maxLines: 3,
                enabled: !_isSubmitting,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: buildSupportInputDecoration(
                  label: 'How would this be useful?',
                  hint: 'Explain the benefit this feature would provide',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // When to use field
              TextField(
                controller: _whenToUseController,
                maxLines: 2,
                enabled: !_isSubmitting,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: buildSupportInputDecoration(
                  label: 'When would you use this?',
                  hint: 'Describe the situations where this would help',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Loading indicator
              if (_isSubmitting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                    ),
                  ),
                ),

              // Result message
              if (_resultMessage != null && !_isSubmitting)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccess == true
                        ? VineTheme.vineGreen.withValues(alpha: 0.2)
                        : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isSuccess == true
                          ? VineTheme.vineGreen
                          : Colors.red,
                    ),
                  ),
                  child: Text(
                    _resultMessage!,
                    style: TextStyle(
                      color: _isSuccess == true
                          ? VineTheme.vineGreen
                          : Colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        // Cancel button (hide after success)
        if (_isSuccess != true)
          TextButton(
            onPressed: _isSubmitting ? null : context.pop,
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),

        // Send/Close button
        ElevatedButton(
          onPressed: _isSuccess == true
              ? context.pop
              : (_canSubmit ? _submitRequest : null),
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
            foregroundColor: VineTheme.whiteText,
          ),
          child: Text(_isSuccess == true ? 'Close' : 'Send Request'),
        ),
      ],
    );
  }
}
