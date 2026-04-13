// ABOUTME: Support center screen with bug report, feature request, logs, FAQ, and legal links
// ABOUTME: Replaces the old support dialog and drawer legal links

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportCenterScreen extends ConsumerWidget {
  static const routeName = 'support-center';
  static const path = '/support-center';

  const SupportCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final userPubkey = authService.currentPublicKeyHex;
    final bugReportService = ref.read(bugReportServiceProvider);

    final l10n = context.l10n;
    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.supportTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              _SupportTile(
                icon: Icons.chat,
                title: l10n.supportContactSupport,
                subtitle: l10n.supportContactSupportSubtitle,
                onTap: () => _viewSupportMessages(context),
              ),
              _SupportTile(
                icon: Icons.bug_report,
                title: l10n.supportReportBug,
                subtitle: l10n.supportReportBugSubtitle,
                onTap: () => _showBugReport(
                  context,
                  bugReportService,
                  userPubkey,
                ),
              ),
              _SupportTile(
                icon: Icons.lightbulb,
                title: l10n.supportRequestFeature,
                subtitle: l10n.supportRequestFeatureSubtitle,
                onTap: () => _showFeatureRequest(context, userPubkey),
              ),
              _SupportTile(
                icon: Icons.save,
                title: l10n.supportSaveLogs,
                subtitle: l10n.supportSaveLogsSubtitle,
                onTap: () => _exportLogs(
                  context,
                  bugReportService,
                  userPubkey,
                ),
              ),
              _SupportTile(
                icon: Icons.help,
                title: l10n.supportFaq,
                subtitle: l10n.supportFaqSubtitle,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/faq',
                  l10n.supportFaq,
                ),
              ),
              _SupportTile(
                icon: Icons.verified_user,
                title: l10n.supportProofMode,
                subtitle: l10n.supportProofModeSubtitle,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/proofmode',
                  l10n.supportProofMode,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBugReport(
    BuildContext context,
    BugReportService bugReportService,
    String? userPubkey,
  ) {
    if (userPubkey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.supportLoginRequired),
          backgroundColor: VineTheme.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => BugReportDialog(
        bugReportService: bugReportService,
        currentScreen: 'SupportCenterScreen',
        userPubkey: userPubkey,
      ),
    );
  }

  void _showFeatureRequest(BuildContext context, String? userPubkey) {
    showDialog(
      context: context,
      builder: (context) => FeatureRequestDialog(userPubkey: userPubkey),
    );
  }

  Future<void> _exportLogs(
    BuildContext context,
    BugReportService bugReportService,
    String? userPubkey,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.supportExportingLogs),
        duration: const Duration(seconds: 2),
      ),
    );

    final success = await bugReportService.exportLogsToFile(
      currentScreen: 'SupportCenterScreen',
      userPubkey: userPubkey,
    );

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.supportExportLogsFailed),
          backgroundColor: VineTheme.error,
        ),
      );
    }
  }

  Future<void> _viewSupportMessages(BuildContext context) async {
    if (!ZendeskSupportService.isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.supportChatNotAvailable),
            backgroundColor: VineTheme.error,
          ),
        );
      }
      return;
    }

    // JWT refresh is handled internally by showTicketListScreen via _ensureFreshJwt
    final shown = await ZendeskSupportService.showTicketListScreen();
    if (!shown && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.supportCouldNotOpenMessages),
          backgroundColor: VineTheme.error,
        ),
      );
    }
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
              content: Text(
                context.l10n.supportCouldNotOpenPage(pageName),
              ),
              backgroundColor: VineTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.supportErrorOpeningPage(pageName, e),
            ),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
      trailing: const Icon(Icons.chevron_right, color: VineTheme.lightText),
      onTap: onTap,
    );
  }
}
