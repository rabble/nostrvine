// ABOUTME: Support center with help tools, resource links, and account deletion
// ABOUTME: Replaces the old support dialog and drawer legal links

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/support_email_composer.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/delete_account_action.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportCenterScreen extends ConsumerWidget {
  static const routeName = 'support-center';
  static const String path = RoutePaths.supportCenter;

  const SupportCenterScreen({
    this.composeEmail,
    this.openZendeskSupport,
    super.key,
  });

  final SupportEmailCompose? composeEmail;
  final Future<bool> Function()? openZendeskSupport;

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
        onBackPressed: () => context.safePop(fallback: WelcomeScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              _SupportTile(
                icon: DivineIconName.chat,
                title: l10n.supportContactSupport,
                subtitle: l10n.supportContactSupportSubtitle,
                onTap: () => _contactSupport(context),
              ),
              if (isAuthenticated)
                _SupportTile(
                  icon: DivineIconName.warningCircle,
                  title: l10n.supportReportBug,
                  subtitle: l10n.supportReportBugSubtitle,
                  onTap: () =>
                      _showBugReport(context, bugReportService, userPubkey),
                ),
              if (isAuthenticated)
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
              // Separate from Save Logs because the share sheet cannot serve
              // a copy on Android — its Copy chip copies EXTRA_TEXT and never
              // the attached file (#8112).
              _SupportTile(
                icon: DivineIconName.copy,
                title: l10n.supportCopyLogs,
                subtitle: l10n.supportCopyLogsSubtitle,
                onTap: () => _copyLogs(context, bugReportService, userPubkey),
              ),
              // #6335 was filed from here by someone who could not find
              // deletion, so it has to be reachable from here too. It sits
              // above the outbound links rather than last so it stays on
              // screen without scrolling on a 667pt phone.
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
                icon: DivineIconName.users,
                title: l10n.supportFamily,
                subtitle: l10n.supportFamilySubtitle,
                onTap: () => _launchUrl(
                  context,
                  AppConstants.familyResourcesUrl,
                  l10n.supportFamily,
                ),
              ),
              _SupportTile(
                icon: DivineIconName.userFocus,
                title: l10n.supportKids,
                subtitle: l10n.supportKidsSubtitle,
                onTap: () => _launchUrl(
                  context,
                  AppConstants.kidsPolicyUrl,
                  l10n.supportKids,
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
    final sharePositionOrigin = shareAnchorForContext(context);
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

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();

    switch (result.status) {
      case LogExportStatus.cancelled:
        // User backed out of the share sheet or Save As dialog.
        return;
      case LogExportStatus.noLogs:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.supportNoLogsToExport,
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      case LogExportStatus.unconfirmed:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.supportExportLogsUnconfirmed,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      case LogExportStatus.failed:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.supportExportLogsFailed,
            error: true,
          ),
        );
        return;
      case LogExportStatus.shared:
      case LogExportStatus.saved:
        break;
    }

    final filePath = result.filePath;
    if (filePath != null) {
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

  Future<void> _copyLogs(
    BuildContext context,
    BugReportService bugReportService,
    String? userPubkey,
  ) async {
    final text = await bugReportService.buildLogClipboardText(
      currentScreen: 'SupportCenterScreen',
      userPubkey: userPubkey,
    );
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (text == null) {
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.supportNoLogsToExport,
          duration: const Duration(seconds: 8),
        ),
      );
      return;
    }

    // copyVerified reads the value back, so a clipboard blocked by a work
    // profile or a device policy reports failure instead of looking fine.
    final copied = await ClipboardUtils.copyVerified(
      context,
      text,
      message: context.l10n.supportLogsCopied,
    );
    if (!context.mounted || copied) return;

    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.supportCopyLogsFailed,
        error: true,
      ),
    );
  }

  Future<bool> _viewSupportMessages() async {
    // JWT refresh is handled internally by showTicketListScreen via _ensureFreshJwt
    return ZendeskSupportService.showTicketListScreen();
  }

  Future<void> _contactSupport(BuildContext context) async {
    final l10n = context.l10n;
    var emailBody = l10n.supportContactSupportSubtitle;
    final openZendesk =
        openZendeskSupport ??
        (ZendeskSupportService.isAvailable ? _viewSupportMessages : null);
    if (openZendesk != null) {
      if (await openZendesk()) return;
      emailBody = '${l10n.supportCouldNotOpenMessages}\n\n$emailBody';
    } else {
      emailBody = '${l10n.supportChatNotAvailable}\n\n$emailBody';
    }
    if (!context.mounted) return;

    final sharePositionOrigin = shareAnchorForContext(context);
    try {
      await (composeEmail ?? SupportEmailComposer().compose)(
        toEmail: AppConstants.supportEmail,
        subject: l10n.supportContactSupport,
        body: emailBody,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          l10n.authCouldNotOpenEmail(AppConstants.supportEmail),
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
      leading: DivineIcon(
        icon: icon,
        color: iconColor ?? context.vineColors.accentPositive,
      ),
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
