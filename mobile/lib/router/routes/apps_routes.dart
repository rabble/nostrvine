// ABOUTME: Nostr-apps routes (directory, permissions, sandbox, iframe, app detail)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/widgets/resolved_sandbox_route_screen.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/apps/apps_permissions_screen.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/screens/apps/web_iframe_sandbox_screen.dart';

List<RouteBase> appsRoutes(Ref ref) {
  return [
    GoRoute(
      path: AppsDirectoryScreen.path,
      name: AppsDirectoryScreen.routeName,
      builder: (_, _) => const AppsDirectoryScreen(),
    ),
    GoRoute(
      path: AppsPermissionsScreen.path,
      name: AppsPermissionsScreen.routeName,
      builder: (_, state) {
        final authService = ref.read(authServiceProvider);
        final grantStore = ref.read(nostrAppGrantStoreProvider);
        return AppsPermissionsScreen(
          grantStore: grantStore,
          currentUserPubkey: authService.currentPublicKeyHex,
        );
      },
    ),
    GoRoute(
      path: NostrAppSandboxScreen.path,
      name: NostrAppSandboxScreen.routeName,
      builder: (_, state) {
        final app = state.extra is NostrAppDirectoryEntry
            ? state.extra! as NostrAppDirectoryEntry
            : null;
        final appId = state.pathParameters['appId'] ?? '';
        return ResolvedSandboxRouteScreen(appId: appId, initialApp: app);
      },
    ),
    GoRoute(
      path: WebIframeSandboxScreen.path,
      name: WebIframeSandboxScreen.routeName,
      builder: (_, state) {
        final app = state.extra is NostrAppDirectoryEntry
            ? state.extra! as NostrAppDirectoryEntry
            : null;
        if (app == null) {
          // No NostrAppDirectoryEntry passed in — bounce to the apps
          // directory. The web iframe screen needs the entry's
          // launchUrl + origin, which we can't reconstruct from the
          // path parameter alone.
          return const SizedBox.shrink();
        }
        return WebIframeSandboxScreen(app: app);
      },
    ),
    GoRoute(
      path: AppDetailScreen.path,
      name: AppDetailScreen.routeName,
      builder: (_, state) {
        final slug = state.pathParameters['slug'] ?? '';
        final initialEntry = state.extra is NostrAppDirectoryEntry
            ? state.extra! as NostrAppDirectoryEntry
            : null;
        return AppDetailScreen(slug: slug, initialEntry: initialEntry);
      },
    ),
  ];
}
