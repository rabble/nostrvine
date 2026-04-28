// ABOUTME: Support instructions screen for likely under-13 cases in the
// ABOUTME: parental consent / minor-account review flow.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';

class MinorAccountReviewUnder13SupportScreen extends ConsumerWidget {
  static const routeName = 'minor-account-review-under13-support';
  static const path = '/account-review/under-13-support';

  const MinorAccountReviewUnder13SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(currentMinorAccountReviewStatusProvider);

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.minorAccountReviewUnder13SupportTitle,
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
              loading: () =>
                  const Center(child: PartialCircleSpinner(progress: 0.33)),
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
              data: (status) {
                final l10n = context.l10n;
                final reviewCase = status.currentCase;
                final supportEmail =
                    reviewCase?.supportEmail ?? AppConstants.supportEmail;
                final caseId =
                    reviewCase?.id ?? l10n.minorAccountReviewUnavailable;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.minorAccountReviewUnder13Heading,
                        style: VineTheme.headlineMediumFont(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.minorAccountReviewUnder13SupportBody,
                        style: VineTheme.bodyMediumFont(
                          color: VineTheme.lightText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ValueCard(
                        title: l10n.minorAccountReviewSupportEmailLabel,
                        value: supportEmail,
                        onCopy: () => _copy(
                          context,
                          supportEmail,
                          l10n.minorAccountReviewSupportEmailCopied,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ValueCard(
                        title: l10n.minorAccountReviewCaseIdShortLabel,
                        value: caseId,
                        onCopy: () => _copy(
                          context,
                          caseId,
                          l10n.minorAccountReviewCaseIdCopied,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.minorAccountReviewUnder13Instructions,
                        style: VineTheme.bodyMediumFont(
                          color: VineTheme.lightText,
                        ),
                      ),
                      const Spacer(),
                      DivineButton(
                        label: l10n.minorAccountReviewBackToReview,
                        expanded: true,
                        onPressed: () =>
                            context.go(MinorAccountReviewScreen.path),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copy(
    BuildContext context,
    String text,
    String successMessage,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(DivineSnackbarContainer.snackBar(successMessage));
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.title,
    required this.value,
    required this.onCopy,
  });

  final String title;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: VineTheme.labelMediumFont(
                    color: VineTheme.secondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(value, style: VineTheme.bodyMediumFont()),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, color: VineTheme.vineGreen),
          ),
        ],
      ),
    );
  }
}
