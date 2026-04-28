// ABOUTME: Parent-contact submission screen for 13-15 minor-account review
// ABOUTME: cases. Sends a parent or guardian email to the backend.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/validators.dart';

class MinorAccountReviewParentContactScreen extends ConsumerStatefulWidget {
  static const routeName = 'minor-account-review-parent-contact';
  static const path = '/account-review/parent-contact';

  const MinorAccountReviewParentContactScreen({super.key});

  @override
  ConsumerState<MinorAccountReviewParentContactScreen> createState() =>
      _MinorAccountReviewParentContactScreenState();
}

class _MinorAccountReviewParentContactScreenState
    extends ConsumerState<MinorAccountReviewParentContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _submittedEmail;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(currentMinorAccountReviewStatusProvider);

    return Scaffold(
      appBar: DiVineAppBar(
        title: 'Parent Contact',
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: statusAsync.when(
              loading: () => const Center(
                child: PartialCircleSpinner(progress: 0.33),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '$error',
                    style: VineTheme.bodyMediumFont(
                      color: VineTheme.secondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (status) => _buildBody(context, status),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MinorAccountReviewStatus status) {
    final reviewCase = status.currentCase;
    if (reviewCase == null) {
      return const _MissingCaseView();
    }

    if (_submittedEmail != null) {
      return _SuccessView(
        email: _submittedEmail!,
        onCheckAgain: () => ref.invalidate(currentMinorAccountReviewStatusProvider),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a parent or guardian email',
                style: VineTheme.headlineMediumFont(),
              ),
              const SizedBox(height: 12),
              Text(
                'We will use this address for the parental consent review on case ${reviewCase.id}.',
                style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
              ),
              const SizedBox(height: 24),
              DivineAuthTextField(
                label: 'Parent or guardian email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: Validators.validateEmail,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: VineTheme.bodyMediumFont(color: VineTheme.error),
                ),
              ],
              const SizedBox(height: 24),
              DivineButton(
                label: _isSubmitting ? 'Submitting...' : 'Submit Email',
                expanded: true,
                onPressed: _isSubmitting ? null : () => _submit(reviewCase),
              ),
              const SizedBox(height: 12),
              DivineButton(
                label: 'Back to Account Review',
                type: DivineButtonType.secondary,
                expanded: true,
                onPressed: _isSubmitting ? null : context.pop,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(MinorReviewCase reviewCase) async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final overrideService = ref.read(minorAccountReviewOverrideServiceProvider);
      final localOverride = overrideService.getOverride();
      if (localOverride?.currentCase?.id == reviewCase.id) {
        await overrideService.setOverride(
          localOverride!.copyWith(
            currentCase: localOverride.currentCase!.copyWith(
              state: MinorReviewCaseState.submittedForReview,
              instructions: const MinorReviewInstructions(
                title: 'Submission received',
                body:
                    'We received the parent or guardian contact for this account. Our team will review it before restoring access.',
              ),
            ),
          ),
        );
      } else {
      await ref.read(minorAccountReviewRepositoryProvider).submitParentContact(
            caseId: reviewCase.id,
            email: email,
          );
      }
      ref.invalidate(currentMinorAccountReviewStatusProvider);
      if (!mounted) return;
      setState(() {
        _submittedEmail = email;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not submit the parent email. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.email,
    required this.onCheckAgain,
  });

  final String email;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Email submitted', style: VineTheme.headlineMediumFont()),
          const SizedBox(height: 12),
          Text(
            'We submitted $email for review. If we update your case status, use Check Again from the account review screen.',
            style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
          ),
          const SizedBox(height: 24),
          DivineButton(
            label: 'Back to Account Review',
            expanded: true,
            onPressed: () => context.go('/account-review'),
          ),
          const SizedBox(height: 12),
          DivineButton(
            label: 'Check Again',
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: () {
              onCheckAgain();
              context.go('/account-review');
            },
          ),
        ],
      ),
    );
  }
}

class _MissingCaseView extends StatelessWidget {
  const _MissingCaseView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'We could not find an active review case for this account.',
          style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
