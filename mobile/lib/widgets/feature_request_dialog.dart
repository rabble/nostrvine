// ABOUTME: Bottom sheet for submitting feature requests to Zendesk
// ABOUTME: Collects structured data (subject, description, usefulness, when to use)
// ABOUTME: Submits directly to Zendesk via SDK or REST API with custom fields

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/feature_request/feature_request_cubit.dart';
import 'package:openvine/blocs/feature_request/feature_request_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/support_failure_banner.dart';
import 'package:openvine/widgets/support_form_scope.dart';

/// Shows the feature request form in a [VineBottomSheet].
///
/// The fields scroll while the actions stay pinned in the sheet footer.
/// [VineBottomSheet] renders those as sibling slots rather than one subtree,
/// so `contentWrapper` puts both the [FeatureRequestCubit] and the
/// [FeatureRequestFields] controllers above them.
Future<void> showFeatureRequestSheet(
  BuildContext context, {
  String? userPubkey,
}) {
  return VineBottomSheet.show<void>(
    context: context,
    title: Text(context.l10n.supportRequestFeature),
    initialChildSize: 1,
    minChildSize: 0.75,
    maxChildSize: 1,
    contentWrapper: (_, child) => SupportFormScope<FeatureRequestFields>(
      create: FeatureRequestFields.new,
      onDispose: (fields) => fields.dispose(),
      child: BlocProvider(create: (_) => FeatureRequestCubit(), child: child),
    ),
    bottomInput: FeatureRequestActions(userPubkey: userPubkey),
    buildScrollBody: (scrollController) =>
        FeatureRequestForm(scrollController: scrollController),
  );
}

/// Form state shared between the sheet's scroll body and its pinned footer.
@visibleForTesting
class FeatureRequestFields {
  final subject = TextEditingController();
  final description = TextEditingController();
  final usefulness = TextEditingController();
  final whenToUse = TextEditingController();

  /// Target of the subject field's keyboard "next" action. The remaining
  /// fields are multiline, so their action key inserts a newline instead of
  /// advancing.
  final descriptionFocus = FocusNode();

  /// Notifies when a required field changes, so the footer can re-evaluate
  /// whether the request can be sent.
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
    usefulness.dispose();
    whenToUse.dispose();
    descriptionFocus.dispose();
  }
}

/// Scrollable body of the feature request sheet.
///
/// [scrollController] comes from the sheet's `DraggableScrollableSheet`, so
/// dragging the form down collapses and dismisses the sheet.
@visibleForTesting
class FeatureRequestForm extends StatelessWidget {
  const FeatureRequestForm({required this.scrollController, super.key});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fields = SupportFormScope.of<FeatureRequestFields>(context);
    final isSubmitting = context.select(
      (FeatureRequestCubit cubit) =>
          cubit.state.status == FeatureRequestStatus.submitting,
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
            hintText: l10n.featureRequestSubjectHint,
            helperText: l10n.supportRequiredHelper,
            enabled: !isSubmitting,
            filled: true,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => fields.descriptionFocus.requestFocus(),
          ),
          DivineTextField(
            controller: fields.description,
            focusNode: fields.descriptionFocus,
            labelText: l10n.featureRequestDescriptionRequiredLabel,
            hintText: l10n.featureRequestDescriptionHint,
            helperText: l10n.supportRequiredHelper,
            enabled: !isSubmitting,
            filled: true,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
          ),
          DivineTextField(
            controller: fields.usefulness,
            labelText: l10n.featureRequestUsefulnessLabel,
            hintText: l10n.featureRequestUsefulnessHint,
            enabled: !isSubmitting,
            filled: true,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
          ),
          DivineTextField(
            controller: fields.whenToUse,
            labelText: l10n.featureRequestWhenLabel,
            hintText: l10n.featureRequestWhenHint,
            enabled: !isSubmitting,
            filled: true,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
    );
  }
}

/// Pinned footer of the feature request sheet: failure banner plus actions.
@visibleForTesting
class FeatureRequestActions extends StatelessWidget {
  const FeatureRequestActions({this.userPubkey, super.key});

  final String? userPubkey;

  /// Closes the sheet and confirms on the screen behind it. Read the
  /// messenger and the message before popping — the sheet's context is
  /// defunct afterwards.
  void _onSuccess(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.featureRequestSuccessMessage;
    context.pop();
    messenger.showSnackBar(DivineSnackbarContainer.snackBar(message));
  }

  void _submit(BuildContext context, FeatureRequestFields fields) {
    context.read<FeatureRequestCubit>().submit(
      subject: fields.subject.text,
      description: fields.description.text,
      usefulness: fields.usefulness.text,
      whenToUse: fields.whenToUse.text,
      userPubkey: userPubkey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = SupportFormScope.of<FeatureRequestFields>(context);

    return BlocConsumer<FeatureRequestCubit, FeatureRequestState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          curr.status == FeatureRequestStatus.success,
      listener: (context, _) => _onSuccess(context),
      builder: (context, state) {
        final l10n = context.l10n;
        final isSubmitting = state.status == FeatureRequestStatus.submitting;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              if (state.status == FeatureRequestStatus.failure)
                SupportFailureBanner(message: l10n.featureRequestSendFailed),
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
                        label: l10n.featureRequestSendRequest,
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
