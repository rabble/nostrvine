import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/support_email_composer.dart';

class MinorAccountReviewUnder13Screen extends ConsumerWidget {
  static const routeName = 'minor-account-review-under13';
  static const path = '/account-review/under-13';

  static final _supportEmailComposer = SupportEmailComposer();

  const MinorAccountReviewUnder13Screen({super.key});

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
                  context.l10n.minorAccountReviewUnder13PublicTitle,
                  style: VineTheme.headlineMediumFont(),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.minorAccountReviewUnder13PublicBody,
                  style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
                ),
                const SizedBox(height: 24),
                _DetailCard(
                  title: context.l10n.minorAccountReviewUnder13EmailTitle,
                  body: AppConstants.supportEmail,
                ),
                const SizedBox(height: 16),
                _DetailCard(
                  title: context.l10n.minorAccountReviewUnder13ParentTitle,
                  body: context.l10n.minorAccountReviewUnder13ParentBody,
                ),
                const SizedBox(height: 24),
                DivineButton(
                  label: context.l10n.minorAccountReviewUnder13EmailCta,
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
        subject: context.l10n.minorAccountReviewUnder13PublicEmailSubject,
        body: context.l10n.minorAccountReviewUnder13PublicEmailBody,
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

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.body});

  final String title;
  final String body;

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
          Text(
            title,
            style: VineTheme.labelMediumFont(color: VineTheme.secondaryText),
          ),
          const SizedBox(height: 8),
          Text(body, style: VineTheme.bodyMediumFont()),
        ],
      ),
    );
  }
}
