import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/support_email_composer.dart';

class MinorAccountReviewParentConsentScreen extends ConsumerWidget {
  static const routeName = 'minor-account-review-parent-consent';
  static const path = '/account-review/parent-consent';

  static final _supportEmailComposer = SupportEmailComposer();

  const MinorAccountReviewParentConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.minorAccountReviewTitle,
        showBackButton: true,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                Text(
                  context.l10n.minorAccountReviewParentConsentTitle,
                  style: VineTheme.headlineMediumFont(),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.minorAccountReviewParentConsentBody,
                  style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
                ),
                const SizedBox(height: 24),
                _ChecklistCard(
                  title: context.l10n.minorAccountReviewParentConsentChecklist,
                  items: [
                    context.l10n.minorAccountReviewParentConsentChecklistKid,
                    context
                        .l10n
                        .minorAccountReviewParentConsentChecklistPermission,
                    context
                        .l10n
                        .minorAccountReviewParentConsentChecklistAgeBand,
                    context
                        .l10n
                        .minorAccountReviewParentConsentChecklistSupervision,
                  ],
                ),
                const SizedBox(height: 16),
                _ChecklistCard(
                  title: context.l10n.minorAccountReviewParentConsentPrivacy,
                  items: [
                    context.l10n.minorAccountReviewParentConsentNeverPost,
                    context.l10n.minorAccountReviewParentConsentDoNotSave,
                    context.l10n.minorAccountReviewParentConsentOneMove,
                  ],
                ),
                const SizedBox(height: 24),
                DivineButton(
                  label: context.l10n.minorAccountReviewParentConsentEmailCta,
                  expanded: true,
                  onPressed: () => _emailSupport(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _emailSupport(BuildContext context) async {
    try {
      await _supportEmailComposer.compose(
        toEmail: AppConstants.supportEmail,
        subject: context.l10n.minorAccountReviewParentConsentEmailSubject,
        body: context.l10n.minorAccountReviewParentConsentEmailBody,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.authCouldNotOpenEmail(AppConstants.supportEmail),
        ),
      );
    }
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: VineTheme.titleMediumFont()),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: VineTheme.vineGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.lightText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
