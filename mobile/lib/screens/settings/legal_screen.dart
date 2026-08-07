// ABOUTME: Legal screen with links to Terms of Service, Privacy Policy,
// ABOUTME: Safety Standards, DMCA, and Open Source Licenses

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalScreen extends StatelessWidget {
  static const routeName = 'legal';
  static const path = '/legal';

  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.legalTitle,
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              DivineListTile(
                leading: Icon(
                  Icons.description,
                  size: MediaQuery.textScalerOf(context).scale(24),
                  color: VineTheme.vineGreen,
                ),
                title: l10n.legalTermsOfService,
                subtitle: l10n.legalTermsOfServiceSubtitle,
                trailingIcon: DivineIconName.arrowUpRight,
                trailingIconSize: 20,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/terms',
                  l10n.legalTermsOfService,
                ),
              ),
              DivineListTile(
                leading: Icon(
                  Icons.privacy_tip,
                  size: MediaQuery.textScalerOf(context).scale(24),
                  color: VineTheme.vineGreen,
                ),
                title: l10n.legalPrivacyPolicy,
                subtitle: l10n.legalPrivacyPolicySubtitle,
                trailingIcon: DivineIconName.arrowUpRight,
                trailingIconSize: 20,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/privacy',
                  l10n.legalPrivacyPolicy,
                ),
              ),
              DivineListTile(
                icon: DivineIconName.shieldCheck,
                iconColor: VineTheme.vineGreen,
                title: l10n.legalSafetyStandards,
                subtitle: l10n.legalSafetyStandardsSubtitle,
                trailingIcon: DivineIconName.arrowUpRight,
                trailingIconSize: 20,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/safety',
                  l10n.legalSafetyStandards,
                ),
              ),
              DivineListTile(
                leading: Icon(
                  Icons.copyright,
                  size: MediaQuery.textScalerOf(context).scale(24),
                  color: VineTheme.vineGreen,
                ),
                title: l10n.legalDmca,
                subtitle: l10n.legalDmcaSubtitle,
                trailingIcon: DivineIconName.arrowUpRight,
                trailingIconSize: 20,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/dmca',
                  l10n.legalDmca,
                ),
              ),
              DivineListTile(
                leading: Icon(
                  Icons.source,
                  size: MediaQuery.textScalerOf(context).scale(24),
                  color: VineTheme.vineGreen,
                ),
                title: l10n.legalOpenSourceLicenses,
                subtitle: l10n.legalOpenSourceLicensesSubtitle,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: l10n.legalAppName,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(
    BuildContext context,
    String urlString,
    String pageName,
  ) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(
              context.l10n.legalCouldNotOpenPage(pageName),
              error: true,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.legalErrorOpeningPage(pageName, e),
            error: true,
          ),
        );
      }
    }
  }
}
