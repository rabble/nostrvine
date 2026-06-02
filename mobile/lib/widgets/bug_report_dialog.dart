// ABOUTME: Dialog widget for submitting bug reports to Zendesk
// ABOUTME: Collects structured data (subject, description, steps, expected behavior)
// ABOUTME: Submits directly to Zendesk REST API with custom fields

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/blocs/bug_report/bug_report_cubit.dart';
import 'package:openvine/blocs/bug_report/bug_report_state.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/widgets/image_attachment_picker.dart';
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

/// Dialog for collecting and submitting bug reports.
///
/// `BlocProvider` wraps the inner [_BugReportForm] so the form's
/// `TextEditingController`s and attachment list (the hybrid pattern) stay
/// in the View while the submission lifecycle + Zendesk integration lives
/// in [BugReportCubit].
class BugReportDialog extends StatelessWidget {
  const BugReportDialog({
    required this.bugReportService,
    super.key,
    this.currentScreen,
    this.userPubkey,
  });

  final BugReportService bugReportService;
  final String? currentScreen;
  final String? userPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BugReportCubit(
        bugReportService: bugReportService,
        buildLogsSummary: buildLogsSummary,
      ),
      child: _BugReportForm(
        currentScreen: currentScreen,
        userPubkey: userPubkey,
      ),
    );
  }
}

class _BugReportForm extends StatefulWidget {
  const _BugReportForm({this.currentScreen, this.userPubkey});

  final String? currentScreen;
  final String? userPubkey;

  @override
  State<_BugReportForm> createState() => _BugReportFormState();
}

class _BugReportFormState extends State<_BugReportForm> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  final _expectedController = TextEditingController();
  Timer? _closeTimer;
  List<XFile> _attachments = [];

  @override
  void dispose() {
    _closeTimer?.cancel();
    _subjectController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    _expectedController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _subjectController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty;

  void _scheduleAutoClose(BuildContext context) {
    _closeTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      context.pop();
    });
  }

  String _failureMessage(BugReportFailureKey? key, BuildContext context) {
    return switch (key) {
      BugReportFailureKey.attachmentUpload =>
        context.l10n.bugReportUploadFailed,
      BugReportFailureKey.generic || null => context.l10n.bugReportSendFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BugReportCubit, BugReportState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status && curr.status == BugReportStatus.success,
      listener: (context, _) => _scheduleAutoClose(context),
      builder: (context, state) {
        final isSubmitting = state.status == BugReportStatus.submitting;
        final isSuccess = state.status == BugReportStatus.success;
        final isFailure = state.status == BugReportStatus.failure;
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
                  TextField(
                    controller: _subjectController,
                    enabled: !isSubmitting,
                    style: const TextStyle(color: VineTheme.whiteText),
                    decoration: buildSupportInputDecoration(
                      label: context.l10n.supportSubjectRequiredLabel,
                      hint: context.l10n.bugReportSubjectHint,
                      helper: context.l10n.supportRequiredHelper,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    enabled: !isSubmitting,
                    style: const TextStyle(color: VineTheme.whiteText),
                    decoration: buildSupportInputDecoration(
                      label: context.l10n.bugReportDescriptionRequiredLabel,
                      hint: context.l10n.bugReportDescriptionHint,
                      helper: context.l10n.supportRequiredHelper,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _stepsController,
                    maxLines: 3,
                    enabled: !isSubmitting,
                    style: const TextStyle(color: VineTheme.whiteText),
                    decoration: buildSupportInputDecoration(
                      label: context.l10n.bugReportStepsLabel,
                      hint: context.l10n.bugReportStepsHint,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _expectedController,
                    maxLines: 2,
                    enabled: !isSubmitting,
                    style: const TextStyle(color: VineTheme.whiteText),
                    decoration: buildSupportInputDecoration(
                      label: context.l10n.bugReportExpectedBehaviorLabel,
                      hint: context.l10n.bugReportExpectedBehaviorHint,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  ImageAttachmentPicker(
                    enabled: !isSubmitting,
                    onChanged: (files) => setState(() => _attachments = files),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.bugReportDiagnosticsNotice,
                    style: VineTheme.bodySmallFont(color: VineTheme.lightText),
                  ),
                  const SizedBox(height: 16),
                  if (isSubmitting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          color: VineTheme.vineGreen,
                        ),
                      ),
                    ),
                  if (isSuccess)
                    _ResultBanner(
                      message: context.l10n.bugReportSuccessMessage,
                      isSuccess: true,
                    ),
                  if (isFailure)
                    _ResultBanner(
                      message: _failureMessage(state.failureKey, context),
                      isSuccess: false,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            if (!isSuccess)
              TextButton(
                onPressed: isSubmitting ? null : context.pop,
                child: Text(
                  context.l10n.commonCancel,
                  style: const TextStyle(color: VineTheme.lightText),
                ),
              ),
            ElevatedButton(
              onPressed: isSuccess
                  ? context.pop
                  : (_canSubmit && !isSubmitting
                        ? () => context.read<BugReportCubit>().submit(
                            subject: _subjectController.text,
                            description: _descriptionController.text,
                            stepsToReproduce: _stepsController.text,
                            expectedBehavior: _expectedController.text,
                            attachments: _attachments,
                            currentScreen: widget.currentScreen,
                            userPubkey: widget.userPubkey,
                          )
                        : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.whiteText,
              ),
              child: Text(
                isSuccess
                    ? context.l10n.commonClose
                    : context.l10n.bugReportSendReport,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.message, required this.isSuccess});

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess
            ? VineTheme.vineGreen.withValues(alpha: 0.2)
            : VineTheme.error.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess ? VineTheme.vineGreen : VineTheme.error,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isSuccess ? VineTheme.vineGreen : VineTheme.error,
        ),
      ),
    );
  }
}
