// ABOUTME: Dialog widget for submitting bug reports to Zendesk
// ABOUTME: Collects structured data (subject, description, steps, expected behavior)
// ABOUTME: Submits directly to Zendesk REST API with custom fields

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show LogEntry, LogLevel;
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/support_dialog_utils.dart';

/// Build a log summary prioritizing errors/warnings with recent context.
/// Returns null if logs are empty.
/// Takes up to 200 most recent error/warning entries plus the last 50
/// entries of any level, deduplicates, and sorts chronologically.
String? buildLogsSummary(List<LogEntry> logs) {
  if (logs.isEmpty) return null;

  // Last 200 error/warning entries
  final errorWarnings = logs
      .where((l) => l.level == LogLevel.error || l.level == LogLevel.warning)
      .toList();
  final recentErrors = errorWarnings.length > 200
      ? errorWarnings.sublist(errorWarnings.length - 200)
      : errorWarnings;

  // Last 50 entries of any level
  final recentContext = logs.length > 50
      ? logs.sublist(logs.length - 50)
      : logs;

  // Merge, deduplicate, sort chronologically
  final merged = <LogEntry>{...recentErrors, ...recentContext}.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  return merged.map((log) => log.toFormattedString()).join('\n');
}

/// Dialog for collecting and submitting bug reports
class BugReportDialog extends StatefulWidget {
  const BugReportDialog({
    required this.bugReportService,
    super.key,
    this.currentScreen,
    this.userPubkey,
    this.testMode = false, // If true, sends to yourself instead of support
  });

  final BugReportService bugReportService;
  final String? currentScreen;
  final String? userPubkey;
  final bool testMode;

  @override
  State<BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<BugReportDialog> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  final _expectedController = TextEditingController();
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
    _stepsController.dispose();
    _expectedController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_isSubmitting &&
      _subjectController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty;

  Future<void> _submitReport() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _resultMessage = null;
      _isSuccess = null;
    });

    try {
      // Collect diagnostics for device info
      final description = _descriptionController.text.trim();
      final reportData = await widget.bugReportService.collectDiagnostics(
        userDescription: description,
        currentScreen: widget.currentScreen,
        userPubkey: widget.userPubkey,
      );

      // Submit directly to Zendesk with structured fields
      final subject = _subjectController.text.trim();
      final success = await ZendeskSupportService.createStructuredBugReport(
        subject: subject,
        description: description,
        stepsToReproduce: _stepsController.text.trim(),
        expectedBehavior: _expectedController.text.trim(),
        reportId: reportData.reportId,
        appVersion: reportData.appVersion,
        deviceInfo: reportData.deviceInfo,
        currentScreen: widget.currentScreen,
        userPubkey: widget.userPubkey,
        errorCounts: reportData.errorCounts,
        logsSummary: _buildLogsSummary(reportData.recentLogs),
      );

      if (!_isDisposed && mounted) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = success;
          if (success) {
            _resultMessage =
                "Thank you! We've received your report and will use it to make Divine better.";
          } else {
            _resultMessage =
                'Failed to send bug report. Please try again later.';
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
        'Error submitting bug report: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );

      if (!_isDisposed && mounted) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = false;
          _resultMessage = 'Bug report failed to send: $e';
        });
      }
    }
  }

  String? _buildLogsSummary(List<LogEntry> logs) => buildLogsSummary(logs);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        'Report a Bug',
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
                  hint: 'Brief summary of the issue',
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
                  label: 'What happened? *',
                  hint: 'Describe the issue you encountered',
                  helper: 'Required',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Steps to reproduce field
              TextField(
                controller: _stepsController,
                maxLines: 3,
                enabled: !_isSubmitting,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: buildSupportInputDecoration(
                  label: 'Steps to Reproduce',
                  hint: '1. Go to...\n2. Tap on...\n3. See error',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Expected behavior field
              TextField(
                controller: _expectedController,
                maxLines: 2,
                enabled: !_isSubmitting,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: buildSupportInputDecoration(
                  label: 'Expected Behavior',
                  hint: 'What should have happened instead?',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 8),

              // Info text
              Text(
                'Device info and logs will be included automatically.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
                        : VineTheme.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isSuccess == true
                          ? VineTheme.vineGreen
                          : VineTheme.error,
                    ),
                  ),
                  child: Text(
                    _resultMessage!,
                    style: TextStyle(
                      color: _isSuccess == true
                          ? VineTheme.vineGreen
                          : VineTheme.error,
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.lightText),
            ),
          ),

        // Send/Close button
        ElevatedButton(
          onPressed: _isSuccess == true
              ? context.pop
              : (_canSubmit ? _submitReport : null),
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
            foregroundColor: VineTheme.whiteText,
          ),
          child: Text(_isSuccess == true ? 'Close' : 'Send Report'),
        ),
      ],
    );
  }
}
