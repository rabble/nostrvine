// ABOUTME: Nostr-apps routes (directory, permissions, sandbox, iframe, app detail)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/router/widgets/resolved_app_route_screen.dart';
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
    // Both sandbox routes resolve their entry from the `appId` path
    // parameter, so a pasted URL or a browser refresh reaches the app
    // instead of a dead end; `extra` is only a warm-start hint (#3335).
    GoRoute(
      path: NostrAppSandboxScreen.path,
      name: NostrAppSandboxScreen.routeName,
      builder: (_, state) => ResolvedAppRouteScreen(
        appId: state.pathParameters['appId'] ?? '',
        initialApp: extraAs<NostrAppDirectoryEntry>(state.extra),
        onResolved: (app) => NostrAppSandboxScreen(app: app),
      ),
    ),
    GoRoute(
      path: WebIframeSandboxScreen.path,
      name: WebIframeSandboxScreen.routeName,
      builder: (_, state) => ResolvedAppRouteScreen(
        appId: state.pathParameters['appId'] ?? '',
        initialApp: extraAs<NostrAppDirectoryEntry>(state.extra),
        onResolved: (app) => WebIframeSandboxScreen(app: app),
      ),
    ),
    GoRoute(
      path: AppDetailScreen.path,
      name: AppDetailScreen.routeName,
      builder: (_, state) {
        final slug = state.pathParameters['slug'] ?? '';
        final initialEntry = extraAs<NostrAppDirectoryEntry>(state.extra);
        return AppDetailScreen(slug: slug, initialEntry: initialEntry);
      },
    ),
  ];
}
