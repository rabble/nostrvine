// ABOUTME: Navigation drawer providing access to settings, relays, bug reports and other app options
// ABOUTME: Reusable sidebar menu that appears from the top right on all main screens

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/bug_report_service.dart';
// import 'package:openvine/screens/p2p_sync_screen.dart'; // Hidden for release
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';
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
              backgroundColor: VineTheme.error,
            ),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening $pageName: $error'),
            backgroundColor: VineTheme.error,
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
      backgroundColor: VineTheme.transparent,
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
                            context.pushWithVideoPause(SettingsScreen.path);
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

                            final userPubkey = authService.currentPublicKeyHex;
                            if (userPubkey == null) {
                              Navigator.of(context).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Log in to contact support',
                                    ),
                                    backgroundColor: VineTheme.error,
                                  ),
                                );
                              }
                              return;
                            }

                            final isZendeskAvailable =
                                ZendeskSupportService.isAvailable;
                            Log.debug(
                              'Zendesk available: $isZendeskAvailable',
                              category: LogCategory.ui,
                            );

                            final bugReportService = ref.read(
                              bugReportServiceProvider,
                            );
                            final userProfile = ref
                                .read(
                                  userProfileReactiveProvider(userPubkey),
                                )
                                .value;

                            // Capture services before drawer closes — ref
                            // becomes invalid after widget unmounts.
                            final nip98Service = ref.read(
                              nip98AuthServiceProvider,
                            );
                            final relayManagerUrl = ref
                                .read(
                                  currentEnvironmentProvider,
                                )
                                .relayManagerApiUrl;

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
                              userProfile,
                              userPubkey,
                              isZendeskAvailable,
                              nip98Service: nip98Service,
                              relayManagerUrl: relayManagerUrl,
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
    BugReportService bugReportService,
    UserProfile? userProfile,
    String? userPubkey,
    bool isZendeskAvailable, {
    required Nip98AuthService nip98Service,
    required String relayManagerUrl,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'How can we help?',
          style: TextStyle(color: VineTheme.whiteText),
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
                  userProfile,
                  userPubkey,
                  isZendeskAvailable,
                  nip98Service: nip98Service,
                  relayManagerUrl: relayManagerUrl,
                );
              },
            ),
            const SizedBox(height: 12),
            _SupportOption(
              icon: Icons.lightbulb_outline,
              title: 'Request a Feature',
              subtitle: 'Suggest improvements or new features',
              onTap: () {
                dialogContext.pop();
                _handleFeatureRequest(
                  context,
                  userPubkey,
                  isZendeskAvailable,
                  nip98Service: nip98Service,
                  relayManagerUrl: relayManagerUrl,
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
                  // Set JWT identity for ticket list (Zendesk configured for JWT auth)
                  // Don't set anonymous identity first - causes auth type mismatch
                  if (userPubkey != null) {
                    final jwtSet = await ZendeskSupportService.setJwtIdentity(
                      nip98Service: nip98Service,
                      relayManagerUrl: relayManagerUrl,
                    );
                    if (!jwtSet && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not authenticate with support',
                          ),
                          backgroundColor: VineTheme.error,
                        ),
                      );
                      return;
                    }
                  }

                  Log.debug(
                    '💬 Opening Zendesk ticket list',
                    category: LogCategory.ui,
                  );
                  await ZendeskSupportService.showTicketListScreen();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Support chat not available'),
                        backgroundColor: VineTheme.error,
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

  /// Handle bug report submission
  /// JWT identity is set at login by zendeskIdentitySync provider.
  Future<void> _handleBugReportWithServices(
    BuildContext context,
    BugReportService bugReportService,
    UserProfile? userProfile,
    String? userPubkey,
    bool isZendeskAvailable, {
    required Nip98AuthService nip98Service,
    required String relayManagerUrl,
  }) async {
    if (!context.mounted) return;

    Log.debug('🐛 Opening bug report dialog', category: LogCategory.ui);
    _showSupportFallbackWithServices(context, bugReportService, userPubkey);
  }

  /// Show fallback support options when Zendesk is not available
  /// Note: Zendesk identity is already set by the calling method
  void _showSupportFallbackWithServices(
    BuildContext context,
    BugReportService bugReportService,
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

  /// Handle feature request submission
  /// JWT identity is set at login by zendeskIdentitySync provider.
  Future<void> _handleFeatureRequest(
    BuildContext context,
    String? userPubkey,
    bool isZendeskAvailable, {
    required Nip98AuthService nip98Service,
    required String relayManagerUrl,
  }) async {
    if (!context.mounted) return;

    Log.debug('💡 Opening feature request dialog', category: LogCategory.ui);
    showDialog(
      context: context,
      builder: (context) => FeatureRequestDialog(userPubkey: userPubkey),
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
          border: Border.all(color: VineTheme.cardBackground),
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
                      color: VineTheme.whiteText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: VineTheme.lightText),
          ],
        ),
      ),
    );
  }
}
