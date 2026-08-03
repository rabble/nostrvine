// ABOUTME: Bottom sheet for submitting feature requests to Zendesk
// ABOUTME: Collects structured data (subject, description, usefulness, when to use)
// ABOUTME: Submits directly to Zendesk via SDK or REST API with custom fields

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/feature_request/feature_request_cubit.dart';
import 'package:openvine/blocs/feature_request/feature_request_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/support_form_fields.dart';
import 'package:openvine/widgets/support_form_scope.dart';
import 'package:openvine/widgets/support_sheet_actions.dart';

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
      child: BlocProvider(create: (_) => FeatureRequestCubit(), child: child),
    ),
    bottomInput: FeatureRequestActions(userPubkey: userPubkey),
    buildScrollBody: (scrollController) =>
        FeatureRequestForm(scrollController: scrollController),
  );
}

/// Form state shared between the sheet's scroll body and its pinned footer.
@visibleForTesting
class FeatureRequestFields extends SupportFormFields {
  final usefulness = TextEditingController();
  final whenToUse = TextEditingController();

  @override
  void dispose() {
    usefulness.dispose();
    whenToUse.dispose();
    super.dispose();
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
      listener: (context, _) => closeSupportSheetWithConfirmation(
        context,
        message: context.l10n.featureRequestSuccessMessage,
      ),
      builder: (context, state) => SupportSheetActions(
        fields: fields,
        sendLabel: context.l10n.featureRequestSendRequest,
        isSubmitting: state.status == FeatureRequestStatus.submitting,
        failureMessage: state.status == FeatureRequestStatus.failure
            ? context.l10n.featureRequestSendFailed
            : null,
        onSubmit: () => _submit(context, fields),
      ),
    );
  }
}
