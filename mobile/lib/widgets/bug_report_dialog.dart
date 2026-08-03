// ABOUTME: Bottom sheet for submitting bug reports to Zendesk
// ABOUTME: Collects structured data (subject, description, steps, expected behavior)
// ABOUTME: Submits directly to Zendesk REST API with custom fields

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
import 'package:openvine/widgets/support_failure_banner.dart';
import 'package:openvine/widgets/support_form_scope.dart';
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

/// Shows the bug report form in a [VineBottomSheet].
///
/// The fields scroll while the actions stay pinned in the sheet footer.
/// [VineBottomSheet] renders those as sibling slots rather than one subtree,
/// so `contentWrapper` puts both the [BugReportCubit] and the
/// [BugReportFields] controllers above them.
Future<void> showBugReportSheet(
  BuildContext context, {
  required BugReportService bugReportService,
  String? currentScreen,
  String? userPubkey,
}) {
  return VineBottomSheet.show<void>(
    context: context,
    title: Text(context.l10n.supportReportBug),
    initialChildSize: 1,
    minChildSize: 0.75,
    maxChildSize: 1,
    contentWrapper: (_, child) => SupportFormScope<BugReportFields>(
      create: BugReportFields.new,
      onDispose: (fields) => fields.dispose(),
      child: BlocProvider(
        create: (_) => BugReportCubit(
          bugReportService: bugReportService,
          buildLogsSummary: buildLogsSummary,
        ),
        child: child,
      ),
    ),
    bottomInput: BugReportActions(
      currentScreen: currentScreen,
      userPubkey: userPubkey,
    ),
    buildScrollBody: (scrollController) =>
        BugReportForm(scrollController: scrollController),
  );
}

/// Form state shared between the sheet's scroll body and its pinned footer.
@visibleForTesting
class BugReportFields {
  final subject = TextEditingController();
  final description = TextEditingController();
  final steps = TextEditingController();
  final expected = TextEditingController();
  final attachments = ValueNotifier<List<XFile>>(const []);

  /// Target of the subject field's keyboard "next" action. The remaining
  /// fields are multiline, so their action key inserts a newline instead of
  /// advancing.
  final descriptionFocus = FocusNode();

  /// Notifies when a required field changes, so the footer can re-evaluate
  /// whether the report can be sent.
  ///
  /// Built once: a fresh `Listenable.merge` per read would make every rebuild
  /// re-subscribe, and a rebuild during the sheet's exit animation would then
  /// touch controllers that are already disposed.
  late final Listenable requiredFields = Listenable.merge([
    subject,
    description,
  ]);

  bool get canSubmit =>
      subject.text.trim().isNotEmpty && description.text.trim().isNotEmpty;

  void dispose() {
    subject.dispose();
    description.dispose();
    steps.dispose();
    expected.dispose();
    attachments.dispose();
    descriptionFocus.dispose();
  }
}

/// Scrollable body of the bug report sheet.
///
/// [scrollController] comes from the sheet's `DraggableScrollableSheet`, so
/// dragging the form down collapses and dismisses the sheet.
@visibleForTesting
class BugReportForm extends StatelessWidget {
  const BugReportForm({required this.scrollController, super.key});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fields = SupportFormScope.of<BugReportFields>(context);
    final isSubmitting = context.select(
      (BugReportCubit cubit) =>
          cubit.state.status == BugReportStatus.submitting,
    );

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          DivineTextField(
            controller: fields.subject,
            labelText: l10n.supportSubjectRequiredLabel,
            hintText: l10n.bugReportSubjectHint,
            helperText: l10n.supportRequiredHelper,
            enabled: !isSubmitting,
            filled: true,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => fields.descriptionFocus.requestFocus(),
          ),
          DivineTextField(
            controller: fields.description,
            focusNode: fields.descriptionFocus,
            labelText: l10n.bugReportDescriptionRequiredLabel,
            hintText: l10n.bugReportDescriptionHint,
            helperText: l10n.supportRequiredHelper,
            enabled: !isSubmitting,
            filled: true,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
          ),
          DivineTextField(
            controller: fields.steps,
            labelText: l10n.bugReportStepsLabel,
            hintText: l10n.bugReportStepsHint,
            enabled: !isSubmitting,
            filled: true,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
          ),
          DivineTextField(
            controller: fields.expected,
            labelText: l10n.bugReportExpectedBehaviorLabel,
            hintText: l10n.bugReportExpectedBehaviorHint,
            enabled: !isSubmitting,
            filled: true,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
          ),
          ImageAttachmentPicker(
            enabled: !isSubmitting,
            onChanged: (files) => fields.attachments.value = files,
          ),
          Text(
            l10n.bugReportDiagnosticsNotice,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned footer of the bug report sheet: failure banner plus actions.
@visibleForTesting
class BugReportActions extends StatelessWidget {
  const BugReportActions({this.currentScreen, this.userPubkey, super.key});

  final String? currentScreen;
  final String? userPubkey;

  /// Closes the sheet and confirms on the screen behind it. Read the
  /// messenger and the message before popping — the sheet's context is
  /// defunct afterwards.
  void _onSuccess(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.bugReportSuccessMessage;
    context.pop();
    messenger.showSnackBar(DivineSnackbarContainer.snackBar(message));
  }

  String _failureMessage(BugReportFailureKey? key, BuildContext context) {
    return switch (key) {
      BugReportFailureKey.attachmentUpload =>
        context.l10n.bugReportUploadFailed,
      BugReportFailureKey.generic || null => context.l10n.bugReportSendFailed,
    };
  }

  void _submit(BuildContext context, BugReportFields fields) {
    context.read<BugReportCubit>().submit(
      subject: fields.subject.text,
      description: fields.description.text,
      stepsToReproduce: fields.steps.text,
      expectedBehavior: fields.expected.text,
      attachments: fields.attachments.value,
      currentScreen: currentScreen,
      userPubkey: userPubkey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = SupportFormScope.of<BugReportFields>(context);

    return BlocConsumer<BugReportCubit, BugReportState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status && curr.status == BugReportStatus.success,
      listener: (context, _) => _onSuccess(context),
      builder: (context, state) {
        final l10n = context.l10n;
        final isSubmitting = state.status == BugReportStatus.submitting;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              if (state.status == BugReportStatus.failure)
                SupportFailureBanner(
                  message: _failureMessage(state.failureKey, context),
                ),
              ListenableBuilder(
                listenable: fields.requiredFields,
                builder: (context, _) => Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: DivineButton(
                        label: l10n.commonCancel,
                        type: DivineButtonType.secondary,
                        onPressed: isSubmitting ? null : context.pop,
                      ),
                    ),
                    Expanded(
                      child: DivineButton(
                        label: l10n.bugReportSendReport,
                        isLoading: isSubmitting,
                        onPressed: fields.canSubmit && !isSubmitting
                            ? () => _submit(context, fields)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
