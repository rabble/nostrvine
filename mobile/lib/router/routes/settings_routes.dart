// ABOUTME: Settings-cluster routes (settings, apps-adjacent settings, diagnostics, dev)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings/app_language_screen.dart';
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/screens/settings/legal_screen.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';

List<RouteBase> settingsRoutes() {
  return [
    GoRoute(
      path: SettingsScreen.path,
      name: SettingsScreen.routeName,
      builder: (_, _) => const SettingsScreen(),
    ),
    GoRoute(
      path: BadgesScreen.path,
      name: BadgesScreen.routeName,
      builder: (_, _) => const BadgesScreen(),
    ),
    GoRoute(
      path: InvitesScreen.path,
      name: InvitesScreen.routeName,
      builder: (_, _) => const InvitesScreen(),
    ),
    GoRoute(
      path: SupportCenterScreen.path,
      name: SupportCenterScreen.routeName,
      builder: (_, _) => const SupportCenterScreen(),
    ),
    GoRoute(
      path: LegalScreen.path,
      name: LegalScreen.routeName,
      builder: (_, _) => const LegalScreen(),
    ),
    GoRoute(
      path: ContentPreferencesScreen.path,
      name: ContentPreferencesScreen.routeName,
      builder: (_, _) => const ContentPreferencesScreen(),
    ),
    GoRoute(
      path: GeneralSettingsScreen.path,
      name: GeneralSettingsScreen.routeName,
      builder: (_, _) => const GeneralSettingsScreen(),
    ),
    GoRoute(
      path: AppLanguageScreen.path,
      name: AppLanguageScreen.routeName,
      builder: (_, _) => const AppLanguageScreen(),
    ),
    GoRoute(
      path: BlueskySettingsScreen.path,
      name: BlueskySettingsScreen.routeName,
      builder: (_, _) => const BlueskySettingsScreen(),
    ),
    GoRoute(
      path: NostrSettingsScreen.path,
      name: NostrSettingsScreen.routeName,
      builder: (_, _) => const NostrSettingsScreen(),
      routes: [
        GoRoute(
          path: Nip05SettingsScreen.subpath,
          name: Nip05SettingsScreen.routeName,
          builder: (_, _) => const Nip05SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: RelaySettingsScreen.path,
      name: RelaySettingsScreen.routeName,
      builder: (_, _) => const RelaySettingsScreen(),
    ),
    GoRoute(
      path: BlossomSettingsScreen.path,
      name: BlossomSettingsScreen.routeName,
      builder: (_, _) => const BlossomSettingsScreen(),
    ),
    GoRoute(
      path: NotificationSettingsScreen.path,
      name: NotificationSettingsScreen.routeName,
      builder: (_, _) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      path: KeyManagementScreen.path,
      name: KeyManagementScreen.routeName,
      builder: (_, _) => const KeyManagementScreen(),
    ),
    GoRoute(
      path: RelayDiagnosticScreen.path,
      name: RelayDiagnosticScreen.routeName,
      builder: (_, _) => const RelayDiagnosticScreen(),
    ),
    GoRoute(
      path: SafetySettingsScreen.path,
      name: SafetySettingsScreen.routeName,
      builder: (_, _) => const SafetySettingsScreen(),
    ),
    GoRoute(
      path: ContentFiltersScreen.path,
      name: ContentFiltersScreen.routeName,
      builder: (_, _) => const ContentFiltersScreen(),
    ),
    GoRoute(
      path: DeveloperOptionsScreen.path,
      name: DeveloperOptionsScreen.routeName,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const DeveloperOptionsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    ),
  ];
}
