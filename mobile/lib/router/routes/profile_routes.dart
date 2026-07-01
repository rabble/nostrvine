// ABOUTME: Profile routes (profile setup edit/setup, followers, following, other profile)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/widgets/followers_screen_router.dart';
import 'package:openvine/router/widgets/following_screen_router.dart';
import 'package:openvine/router/widgets/other_profile_screen_router.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:unified_logger/unified_logger.dart';

List<RouteBase> profileRoutes() {
  return [
    GoRoute(
      path: ProfileSetupScreen.editPath,
      name: ProfileSetupScreen.editRouteName,
      builder: (context, state) {
        Log.debug(
          '${ProfileSetupScreen.editPath} route builder called',
          name: 'AppRouter',
          category: LogCategory.ui,
        );
        Log.debug(
          '${ProfileSetupScreen.editPath} state.uri = ${state.uri}',
          name: 'AppRouter',
          category: LogCategory.ui,
        );
        Log.debug(
          '${ProfileSetupScreen.editPath} state.matchedLocation = ${state.matchedLocation}',
          name: 'AppRouter',
          category: LogCategory.ui,
        );
        Log.debug(
          '${ProfileSetupScreen.editPath} state.fullPath = ${state.fullPath}',
          name: 'AppRouter',
          category: LogCategory.ui,
        );
        return const ProfileSetupScreen(isNewUser: false);
      },
    ),
    GoRoute(
      path: ProfileSetupScreen.setupPath,
      name: ProfileSetupScreen.setupRouteName,
      builder: (context, state) {
        Log.debug(
          '${ProfileSetupScreen.setupPath} route builder called',
          name: 'AppRouter',
          category: LogCategory.ui,
        );
        Log.debug(
          '${ProfileSetupScreen.setupPath} state.uri = ${state.uri}',
          name: 'AppRouter',
          category: LogCategory.ui,
        );
        Log.debug(
          '${ProfileSetupScreen.setupPath} state.matchedLocation = ${state.matchedLocation}',
          name: 'AppRouter',
          category: LogCategory.ui,
        );
        Log.debug(
          '${ProfileSetupScreen.setupPath} state.fullPath = ${state.fullPath}',
          name: 'AppRouter',
          category: LogCategory.ui,
        );
        return const ProfileSetupScreen(isNewUser: true);
      },
    ),
    // Followers screen - routes to My or Others based on pubkey
    GoRoute(
      path: FollowersScreenRouter.path,
      name: FollowersScreenRouter.routeName,
      builder: (ctx, st) {
        final pubkey = st.pathParameters['pubkey'];
        final displayName = st.extra as String?;
        if (pubkey == null || pubkey.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidUserId);
        }
        return FollowersScreenRouter(
          pubkey: pubkey,
          displayName: displayName,
        );
      },
    ),
    // Following screen - routes to My or Others based on pubkey
    GoRoute(
      path: FollowingScreenRouter.path,
      name: FollowingScreenRouter.routeName,
      builder: (ctx, st) {
        final pubkey = st.pathParameters['pubkey'];
        final displayName = st.extra as String?;
        if (pubkey == null || pubkey.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidUserId);
        }
        return FollowingScreenRouter(
          pubkey: pubkey,
          displayName: displayName,
        );
      },
    ),
    // Other user's profile screen (no bottom nav, pushed from feeds/search)
    // Uses router widget to redirect self-visits to own profile tab
    GoRoute(
      path: OtherProfileScreen.pathWithNpub,
      name: OtherProfileScreen.routeName,
      builder: (ctx, st) {
        final npub = st.pathParameters['npub'];
        if (npub == null || npub.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidProfileId);
        }
        // Extract profile hints from extra (for users without Kind 0 profiles)
        final extra = st.extra as Map<String, String?>?;
        final displayNameHint = extra?['displayName'];
        final avatarUrlHint = extra?['avatarUrl'];
        return OtherProfileScreenRouter(
          npub: npub,
          displayNameHint: displayNameHint,
          avatarUrlHint: avatarUrlHint,
        );
      },
    ),
  ];
}
