// ABOUTME: Navigation drawer providing access to settings, relays, bug reports and other app options
// ABOUTME: Reusable sidebar menu that appears from the top right on all main screens

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings_screen.dart';
// import 'package:openvine/screens/p2p_sync_screen.dart'; // Hidden for release
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Navigation drawer with app settings and configuration options
class VineDrawer extends ConsumerStatefulWidget {
  const VineDrawer({super.key});

  @override
  ConsumerState<VineDrawer> createState() => _VineDrawerState();
}

class _VineDrawerState extends ConsumerState<VineDrawer> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  /// Launch a URL in the external browser
  Future<void> _launchWebPage(
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
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening $pageName: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: EdgeInsets.only(top: statusBarHeight),
        decoration: const BoxDecoration(
          color: VineTheme.surfaceBackground,
          borderRadius: BorderRadius.only(topRight: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 24),
                  // Menu items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _DrawerItem(
                          title: 'Settings',
                          onTap: () {
                            // Push the settings route before closing the drawer.
                            //
                            // This ensures the overlay flag (isDrawerOpen) stays
                            // true while the route isbeing pushed,
                            // preventing a brief video resume.
                            //
                            // The drawer closes after the push,
                            // and onDrawerChanged(false) fires only once the
                            // settings screen is already on top.
                            context.push(SettingsScreen.path);
                            Navigator.of(context).pop();
                          },
                        ),

                        const Divider(
                          color: VineTheme.outlineDisabled,
                          height: 1,
                        ),

                        _DrawerItem(
                          title: 'Support',
                          onTap: () async {
                            Log.debug(
                              '🎫 Contact Support tapped',
                              category: LogCategory.ui,
                            );

                            final isZendeskAvailable =
                                ZendeskSupportService.isAvailable;
                            Log.debug(
                              '🔍 Zendesk available: $isZendeskAvailable',
                              category: LogCategory.ui,
                            );

                            final bugReportService = ref.read(
                              bugReportServiceProvider,
                            );
                            final userProfileService = ref.read(
                              userProfileServiceProvider,
                            );
                            final userPubkey = authService.currentPublicKeyHex;

                            final navigatorContext = Navigator.of(
                              context,
                            ).context;

                            Navigator.of(context).pop();

                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );
                            if (!navigatorContext.mounted) {
                              Log.warning(
                                '⚠️ Context not mounted after drawer close',
                                category: LogCategory.ui,
                              );
                              return;
                            }

                            _showSupportOptionsDialog(
                              navigatorContext,
                              bugReportService,
                              userProfileService,
                              userPubkey,
                              isZendeskAvailable,
                            );
                          },
                        ),

                        const Divider(
                          color: VineTheme.outlineDisabled,
                          height: 1,
                        ),

                        _DrawerItem(
                          title: 'Privacy policy',
                          onTap: () {
                            Navigator.of(context).pop();
                            _launchWebPage(
                              context,
                              'https://divine.video/privacy',
                              'Privacy Policy',
                            );
                          },
                        ),

                        const Divider(
                          color: VineTheme.outlineDisabled,
                          height: 1,
                        ),

                        _DrawerItem(
                          title: 'Safety center',
                          onTap: () {
                            Navigator.of(context).pop();
                            _launchWebPage(
                              context,
                              'https://divine.video/safety',
                              'Safety Center',
                            );
                          },
                        ),

                        const Divider(
                          color: VineTheme.outlineDisabled,
                          height: 1,
                        ),

                        _DrawerItem(
                          title: 'FAQ',
                          onTap: () {
                            Navigator.of(context).pop();
                            _launchWebPage(
                              context,
                              'https://divine.video/faq',
                              'FAQ',
                            );
                          },
                        ),

                        const Divider(
                          color: VineTheme.outlineDisabled,
                          height: 1,
                        ),
                      ],
                    ),
                  ),

                  // Logo and version at bottom
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 128, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SvgPicture.asset(
                          'assets/icon/logo.svg',
                          width: 125,
                          height: 32,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'App version v$_appVersion',
                          style: VineTheme.bodySmallFont(
                            color: VineTheme.onSurfaceDisabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: -18,
                right: -44,
                child: Transform.rotate(
                  angle: 19.07 * pi / 180,
                  child: Image.asset(
                    'assets/icon/MascotCropped=yes.png',
                    width: 148,
                    height: 148,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show support options dialog
  /// NOTE: All services and values must be captured BEFORE the drawer
  /// is closed, because ref becomes invalid after widget unmounts.
  void _showSupportOptionsDialog(
    BuildContext context,
    dynamic bugReportService,
    dynamic userProfileService,
    String? userPubkey,
    bool isZendeskAvailable,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'How can we help?',
          style: TextStyle(color: Colors.white),
        ),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SupportOption(
              icon: Icons.bug_report,
              title: 'Report a Bug',
              subtitle: 'Technical issues with the app',
              onTap: () {
                dialogContext.pop();
                _handleBugReportWithServices(
                  context,
                  bugReportService,
                  userProfileService,
                  userPubkey,
                  isZendeskAvailable,
                );
              },
            ),
            const SizedBox(height: 12),
            _SupportOption(
              icon: Icons.chat,
              title: 'View Past Messages',
              subtitle: 'Check responses from support',
              onTap: () async {
                dialogContext.pop();
                if (isZendeskAvailable) {
                  // Ensure identity is set before viewing tickets
                  await _setZendeskIdentityWithService(
                    userPubkey,
                    userProfileService,
                  );
                  Log.debug(
                    '💬 Opening Zendesk ticket list',
                    category: LogCategory.ui,
                  );
                  await ZendeskSupportService.showTicketList();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Support chat not available'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            _SupportOption(
              icon: Icons.help,
              title: 'View FAQ',
              subtitle: 'Common questions & answers',
              onTap: () {
                dialogContext.pop();
                _launchWebPage(context, 'https://divine.video/faq', 'FAQ');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
  }

  /// Set Zendesk user identity from user pubkey using pre-captured service
  /// This version doesn't use ref, so it works after drawer is closed
  Future<void> _setZendeskIdentityWithService(
    String? userPubkey,
    dynamic userProfileService,
  ) async {
    if (userPubkey == null) {
      // Users always have pubkey in this app, but handle edge case gracefully
      Log.warning(
        '⚠️ Zendesk: No userPubkey, using baseline anonymous identity',
        category: LogCategory.system,
      );
      return;
    }

    try {
      final npub = NostrKeyUtils.encodePubKey(userPubkey);
      final profile = userProfileService.getCachedProfile(userPubkey);

      Log.debug(
        '🎫 Zendesk: Setting identity for ${profile?.bestDisplayName ?? npub}',
        category: LogCategory.system,
      );
      Log.debug(
        '🎫 Zendesk: NIP-05: ${profile?.nip05 ?? "none"}',
        category: LogCategory.system,
      );

      await ZendeskSupportService.setUserIdentity(
        displayName: profile?.bestDisplayName,
        nip05: profile?.nip05,
        npub: npub,
      );

      Log.debug(
        '✅ Zendesk: Identity set successfully',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        '❌ Zendesk: Failed to set identity: $e',
        category: LogCategory.system,
      );
    }
  }

  /// Handle bug report submission
  Future<void> _handleBugReportWithServices(
    BuildContext context,
    dynamic bugReportService,
    dynamic userProfileService,
    String? userPubkey,
    bool isZendeskAvailable,
  ) async {
    // Set Zendesk identity for all paths (native SDK and REST API)
    await _setZendeskIdentityWithService(userPubkey, userProfileService);

    if (isZendeskAvailable) {
      // Get device and app info
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      final description =
          '''
Please describe the bug you encountered:

---
App Version: $appVersion
Platform: ${Theme.of(context).platform.name}
''';

      Log.debug('🐛 Opening Zendesk for bug report', category: LogCategory.ui);
      final success = await ZendeskSupportService.showNewTicketScreen(
        subject: 'Bug Report',
        description: description,
        tags: ['mobile', 'bug', 'ios'],
      );

      if (!success && context.mounted) {
        _showSupportFallbackWithServices(context, bugReportService, userPubkey);
      }
    } else {
      _showSupportFallbackWithServices(context, bugReportService, userPubkey);
    }
  }

  /// Show fallback support options when Zendesk is not available
  /// Note: Zendesk identity is already set by the calling method
  void _showSupportFallbackWithServices(
    BuildContext context,
    dynamic bugReportService,
    String? userPubkey,
  ) {
    showDialog(
      context: context,
      builder: (context) => BugReportDialog(
        bugReportService: bugReportService,
        currentScreen: 'VineDrawer',
        userPubkey: userPubkey,
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
      ),
      trailing: SvgPicture.asset(
        'assets/icon/caret_right.svg',
        width: 24,
        height: 24,
        colorFilter: const ColorFilter.mode(
          VineTheme.vineGreen,
          BlendMode.srcIn,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _SupportOption extends StatelessWidget {
  const _SupportOption({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VineTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Row(
          children: [
            Icon(icon, color: VineTheme.vineGreen, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}
