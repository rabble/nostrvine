// ABOUTME: Legal screen with links to Terms of Service, Privacy Policy,
// ABOUTME: Safety Standards, DMCA, and Open Source Licenses

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalScreen extends StatelessWidget {
  static const routeName = 'legal';
  static const path = '/legal';

  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: 'Legal',
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
                title: 'Terms of Service',
                subtitle: 'Usage terms and conditions',
                isExternal: true,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/terms',
                  'Terms of Service',
                ),
              ),
              _LegalTile(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                isExternal: true,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/privacy',
                  'Privacy Policy',
                ),
              ),
              _LegalTile(
                icon: Icons.shield,
                title: 'Safety Standards',
                subtitle: 'Community guidelines and safety',
                isExternal: true,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/safety',
                  'Safety Standards',
                ),
              ),
              _LegalTile(
                icon: Icons.copyright,
                title: 'DMCA',
                subtitle: 'Copyright and takedown policy',
                isExternal: true,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/dmca',
                  'DMCA',
                ),
              ),
              _LegalTile(
                icon: Icons.source,
                title: 'Open Source Licenses',
                subtitle: 'Third-party package attributions',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Divine',
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
              content: Text('Could not open $pageName'),
              backgroundColor: VineTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening $pageName: $e'),
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
