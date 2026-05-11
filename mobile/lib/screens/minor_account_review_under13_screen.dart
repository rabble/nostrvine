import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';

class MinorAccountReviewUnder13Screen extends StatelessWidget {
  static const routeName = 'minor-account-review-under13';
  static const path = '/account-review/under-13';

  const MinorAccountReviewUnder13Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.minorAccountReviewTitle,
        showBackButton: true,
        onBackPressed: () => _close(context),
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
                _CalloutCard(
                  title: context.l10n.minorAccountReviewUnder13FamilyTitle,
                  body: context.l10n.minorAccountReviewUnder13FamilyBody,
                  backgroundColor: VineTheme.accentPinkBackground,
                  borderColor: VineTheme.accentPink,
                ),
                const SizedBox(height: 16),
                _CalloutCard(
                  title: context.l10n.minorAccountReviewUnder13ComeBackTitle,
                  body: context.l10n.minorAccountReviewUnder13ComeBackBody,
                  backgroundColor: VineTheme.surfaceContainer,
                  borderColor: VineTheme.outlineVariant,
                ),
                const SizedBox(height: 24),
                DivineButton(
                  label: context.l10n.commonClose,
                  expanded: true,
                  onPressed: () => _close(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _close(BuildContext context) async {
    final popped = await Navigator.of(context).maybePop();
    if (!context.mounted || popped) return;
    context.go(WelcomeScreen.path);
  }
}

class _CalloutCard extends StatelessWidget {
  const _CalloutCard({
    required this.title,
    required this.body,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String title;
  final String body;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: VineTheme.titleMediumFont()),
          const SizedBox(height: 8),
          Text(
            body,
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurface),
          ),
        ],
      ),
    );
  }
}
