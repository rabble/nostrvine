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
      backgroundColor: VineTheme.backgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              _LegalTile(
                icon: Icons.description,
                title: l10n.legalTermsOfService,
                subtitle: l10n.legalTermsOfServiceSubtitle,
                isExternal: true,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/terms',
                  l10n.legalTermsOfService,
                ),
              ),
              _LegalTile(
                icon: Icons.privacy_tip,
                title: l10n.legalPrivacyPolicy,
                subtitle: l10n.legalPrivacyPolicySubtitle,
                isExternal: true,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/privacy',
                  l10n.legalPrivacyPolicy,
                ),
              ),
              _LegalTile(
                icon: Icons.shield,
                title: l10n.legalSafetyStandards,
                subtitle: l10n.legalSafetyStandardsSubtitle,
                isExternal: true,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/safety',
                  l10n.legalSafetyStandards,
                ),
              ),
              _LegalTile(
                icon: Icons.copyright,
                title: l10n.legalDmca,
                subtitle: l10n.legalDmcaSubtitle,
                isExternal: true,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/dmca',
                  l10n.legalDmca,
                ),
              ),
              _LegalTile(
                icon: Icons.source,
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
            SnackBar(
              content: Text(context.l10n.legalCouldNotOpenPage(pageName)),
              backgroundColor: VineTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.legalErrorOpeningPage(pageName, e)),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isExternal = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isExternal;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: VineTheme.vineGreen),
      title: Text(
        title,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: VineTheme.lightText, fontSize: 14),
      ),
      trailing: Icon(
        isExternal ? Icons.open_in_new : Icons.chevron_right,
        color: VineTheme.lightText,
        size: isExternal ? 20 : 24,
      ),
      onTap: onTap,
    );
  }
}
