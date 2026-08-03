// ABOUTME: Support center screen with bug report, feature request, logs, FAQ, and legal links
// ABOUTME: Replaces the old support dialog and drawer legal links

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/delete_account_action.dart';
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
    final isAuthenticated =
        ref.watch(currentAuthStateProvider) == AuthState.authenticated;
    final bugReportService = ref.read(bugReportServiceProvider);

    final l10n = context.l10n;
    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.supportTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              if (ZendeskSupportService.isAvailable)
                _SupportTile(
                  icon: DivineIconName.chat,
                  title: l10n.supportContactSupport,
                  subtitle: l10n.supportContactSupportSubtitle,
                  onTap: () => _viewSupportMessages(context),
                ),
              _SupportTile(
                icon: DivineIconName.warningCircle,
                title: l10n.supportReportBug,
                subtitle: l10n.supportReportBugSubtitle,
                onTap: () =>
                    _showBugReport(context, bugReportService, userPubkey),
              ),
              _SupportTile(
                icon: DivineIconName.sparkle,
                title: l10n.supportRequestFeature,
                subtitle: l10n.supportRequestFeatureSubtitle,
                onTap: () => _showFeatureRequest(context),
              ),
              _SupportTile(
                icon: DivineIconName.save,
                title: l10n.supportSaveLogs,
                subtitle: l10n.supportSaveLogsSubtitle,
                onTap: () => _exportLogs(context, bugReportService, userPubkey),
              ),
              _SupportTile(
                icon: DivineIconName.question,
                title: l10n.supportFaq,
                subtitle: l10n.supportFaqSubtitle,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/faq',
                  l10n.supportFaq,
                ),
              ),
              _SupportTile(
                icon: DivineIconName.shieldCheck,
                title: l10n.supportProofMode,
                subtitle: l10n.supportProofModeSubtitle,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/proofmode',
                  l10n.supportProofMode,
                ),
              ),

              // #6335 was filed from here by someone who could not find
              // deletion, so it has to be reachable from here too.
              if (isAuthenticated)
                _SupportTile(
                  icon: DivineIconName.trash,
                  title: l10n.nostrSettingsDeleteAccount,
                  subtitle: l10n.nostrSettingsDeleteAccountSubtitle,
                  iconColor: VineTheme.error,
                  titleColor: VineTheme.error,
                  trailingColor: VineTheme.error,
                  onTap: () => startAccountDeletionFlow(
                    context: context,
                    ref: ref,
                    screenName: 'SupportCenterScreen',
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
        DivineSnackbarContainer.snackBar(
          context.l10n.supportLoginRequired,
          error: true,
        ),
      );
      return;
    }

    context.push(BugReportScreen.path);
  }

  void _showFeatureRequest(BuildContext context) {
    context.push(FeatureRequestScreen.path);
  }

  Future<void> _exportLogs(
    BuildContext context,
    BugReportService bugReportService,
    String? userPubkey,
  ) async {
    // Resolve the popover anchor before any await — iPad idiom (including
    // iOS builds on Apple Silicon Macs) rejects the share sheet without it.
    final sharePositionOrigin = sharePositionOriginForContext(context);
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.supportExportingLogs,
        duration: const Duration(seconds: 2),
      ),
    );

    final result = await bugReportService.exportLogsToFile(
      currentScreen: 'SupportCenterScreen',
      userPubkey: userPubkey,
      sharePositionOrigin: sharePositionOrigin,
    );
    if (!context.mounted) return;

    if (result.cancelled) {
      // User dismissed the Save As dialog; nothing to report.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      return;
    }

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.supportExportLogsFailed,
          error: true,
        ),
      );
      return;
    }

    final filePath = result.filePath;
    if (filePath != null) {
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.supportLogsSavedTo(filePath),
          duration: const Duration(seconds: 8),
          actionLabel: context.l10n.supportRevealLogsAction,
          onActionPressed: () {
            // DivineSnackbarContainer's action is a plain button, so unlike
            // SnackBarAction it does not dismiss the banner for us.
            messenger.hideCurrentSnackBar();
            bugReportService.revealExportedFile(filePath);
          },
        ),
      );
    }
  }

  Future<void> _viewSupportMessages(BuildContext context) async {
    if (!ZendeskSupportService.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.supportChatNotAvailable,
          error: true,
        ),
      );
      return;
    }

    // JWT refresh is handled internally by showTicketListScreen via _ensureFreshJwt
    final shown = await ZendeskSupportService.showTicketListScreen();
    if (!shown && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.supportCouldNotOpenMessages,
          error: true,
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
            DivineSnackbarContainer.snackBar(
              context.l10n.supportCouldNotOpenPage(pageName),
              error: true,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.supportErrorOpeningPage(pageName, e),
            error: true,
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
    this.iconColor,
    this.titleColor,
    this.trailingColor,
  });

  final DivineIconName icon;
  final Color? iconColor;

  /// Overrides the title colour, for destructive entries.
  final Color? titleColor;
  final Color? trailingColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: DivineIcon(icon: icon, color: iconColor ?? VineTheme.vineGreen),
      title: Text(
        title,
        style: VineTheme.titleMediumFont(
          color: titleColor ?? context.vineColors.primaryText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
      ),
      trailing: DivineIcon(
        icon: DivineIconName.caretRight,
        color: trailingColor ?? context.vineColors.mutedText,
      ),
      onTap: onTap,
    );
  }
}
