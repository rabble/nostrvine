// ABOUTME: Dialog widget for submitting bug reports to Zendesk
// ABOUTME: Collects structured data (subject, description, steps, expected behavior)
// ABOUTME: Submits directly to Zendesk REST API with custom fields

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/widgets/support_dialog_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// Build a log summary prioritizing errors/warnings with recent context.
/// Returns null if logs are empty.
/// Takes up to 200 most recent error/warning entries plus the last 50
/// entries of any level, deduplicates, and sorts chronologically.
/// Individual entries are truncated to [BugReportConfig.maxLogEntryLength]
/// characters and the total summary is capped at
/// [BugReportConfig.maxLogSummaryLength] characters.
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

  final buffer = StringBuffer();
  for (var i = 0; i < merged.length; i++) {
    var line = merged[i].toFormattedString();
    if (line.length > BugReportConfig.maxLogEntryLength) {
      line =
          '${line.substring(0, BugReportConfig.maxLogEntryLength)}... [truncated]';
    }
    if (buffer.length + line.length + 1 > BugReportConfig.maxLogSummaryLength) {
      final remaining = merged.length - i;
      final noun = remaining == 1 ? 'entry' : 'entries';
      buffer.writeln('... [$remaining $noun truncated]');
      break;
    }
    buffer.writeln(line);
  }

  final result = buffer.toString().trimRight();
  return result.isEmpty ? null : result;
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
            _resultMessage = context.l10n.bugReportSuccessMessage;
          } else {
            _resultMessage = context.l10n.bugReportSendFailed;
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
          _resultMessage = context.l10n.bugReportFailedWithError('$e');
        });
      }
    }
  }

  String? _buildLogsSummary(List<LogEntry> logs) => buildLogsSummary(logs);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: Text(
        context.l10n.supportReportBug,
        style: const TextStyle(color: VineTheme.whiteText),
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
                  label: context.l10n.supportSubjectRequiredLabel,
                  hint: context.l10n.bugReportSubjectHint,
                  helper: context.l10n.supportRequiredHelper,
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
                  label: context.l10n.bugReportDescriptionRequiredLabel,
                  hint: context.l10n.bugReportDescriptionHint,
                  helper: context.l10n.supportRequiredHelper,
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
                  label: context.l10n.bugReportStepsLabel,
                  hint: context.l10n.bugReportStepsHint,
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
                  label: context.l10n.bugReportExpectedBehaviorLabel,
                  hint: context.l10n.bugReportExpectedBehaviorHint,
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 8),

              // Info text
              Text(
                context.l10n.bugReportDiagnosticsNotice,
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
            child: Text(
              context.l10n.commonCancel,
              style: const TextStyle(color: VineTheme.lightText),
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
          child: Text(
            _isSuccess == true
                ? context.l10n.commonClose
                : context.l10n.bugReportSendReport,
          ),
        ),
      ],
    );
  }
}
