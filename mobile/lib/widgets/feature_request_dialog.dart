// ABOUTME: Dialog widget for submitting feature requests to Zendesk
// ABOUTME: Collects structured data (subject, description, usefulness, when to use)
// ABOUTME: Submits directly to Zendesk via SDK or REST API with custom fields

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/feature_request/feature_request_cubit.dart';
import 'package:openvine/blocs/feature_request/feature_request_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/support_dialog_utils.dart';

/// Dialog for collecting and submitting feature requests.
///
/// `BlocProvider` wraps the inner [_FeatureRequestForm] so the form's
/// `TextEditingController`s (the hybrid pattern) stay in the View while
/// the submission lifecycle lives in [FeatureRequestCubit].
class FeatureRequestDialog extends StatelessWidget {
  const FeatureRequestDialog({super.key, this.userPubkey});

  final String? userPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FeatureRequestCubit(),
      child: _FeatureRequestForm(userPubkey: userPubkey),
    );
  }
}

class _FeatureRequestForm extends StatefulWidget {
  const _FeatureRequestForm({this.userPubkey});

  final String? userPubkey;

  @override
  State<_FeatureRequestForm> createState() => _FeatureRequestFormState();
}

class _FeatureRequestFormState extends State<_FeatureRequestForm> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _usefulnessController = TextEditingController();
  final _whenToUseController = TextEditingController();
  Timer? _closeTimer;

  @override
  void dispose() {
    _closeTimer?.cancel();
    _subjectController.dispose();
    _descriptionController.dispose();
    _usefulnessController.dispose();
    _whenToUseController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeatureRequestCubit, FeatureRequestState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          curr.status == FeatureRequestStatus.success,
      listener: (context, _) => _scheduleAutoClose(context),
      builder: (context, state) {
        final isSubmitting = state.status == FeatureRequestStatus.submitting;
        final isSuccess = state.status == FeatureRequestStatus.success;
        final isFailure = state.status == FeatureRequestStatus.failure;
        return AlertDialog(
          backgroundColor: VineTheme.cardBackground,
          title: Text(
            context.l10n.supportRequestFeature,
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
                      hint: context.l10n.featureRequestSubjectHint,
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
                      label:
                          context.l10n.featureRequestDescriptionRequiredLabel,
                      hint: context.l10n.featureRequestDescriptionHint,
                      helper: context.l10n.supportRequiredHelper,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usefulnessController,
                    maxLines: 3,
                    enabled: !isSubmitting,
                    style: const TextStyle(color: VineTheme.whiteText),
                    decoration: buildSupportInputDecoration(
                      label: context.l10n.featureRequestUsefulnessLabel,
                      hint: context.l10n.featureRequestUsefulnessHint,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _whenToUseController,
                    maxLines: 2,
                    enabled: !isSubmitting,
                    style: const TextStyle(color: VineTheme.whiteText),
                    decoration: buildSupportInputDecoration(
                      label: context.l10n.featureRequestWhenLabel,
                      hint: context.l10n.featureRequestWhenHint,
                    ),
                    onChanged: (_) => setState(() {}),
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
                      message: context.l10n.featureRequestSuccessMessage,
                      isSuccess: true,
                    ),
                  if (isFailure)
                    _ResultBanner(
                      message: context.l10n.featureRequestSendFailed,
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
                        ? () => context.read<FeatureRequestCubit>().submit(
                            subject: _subjectController.text,
                            description: _descriptionController.text,
                            usefulness: _usefulnessController.text,
                            whenToUse: _whenToUseController.text,
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
                    : context.l10n.featureRequestSendRequest,
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
