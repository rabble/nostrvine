// ABOUTME: Tests the redirect logic for login flow navigation
// ABOUTME: Tests redirect function behavior without full router instantiation

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/auth/divine_auth_screen.dart';
import 'package:openvine/screens/auth/login_options_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';

/// Isolated test of the redirect logic that mirrors app_router.dart redirect function
/// This helps us understand what SHOULD happen without Firebase dependencies
///
/// The actual redirect logic is:
/// 1. If authenticated AND on auth route -> redirect to /home/0
/// 2. If NOT on auth route AND (TOS not accepted OR unauthenticated) -> redirect to /welcome
/// 3. If on /welcome AND TOS accepted AND authenticated -> redirect to /explore
/// 4. Otherwise -> null (no redirect)
String? testRedirectLogic({
  required String location,
  required AuthState authState,
  required bool tosAccepted,
}) {
  // Auth routes that should be accessible without authentication
  final isAuthRoute =
      location.startsWith(WelcomeScreen.path) ||
      location.startsWith(KeyImportScreen.path) ||
      location.startsWith(WelcomeScreen.loginOptionsPath) ||
      location.startsWith(WelcomeScreen.authNativePath);

  // Rule 1: Authenticated users on auth routes go to home
  if (authState == AuthState.authenticated && isAuthRoute) {
    return HomeScreenRouter.pathForIndex(0);
  }

  // Rule 2: Non-auth routes require TOS AND authentication
  if (!isAuthRoute) {
    if (!tosAccepted) {
      return WelcomeScreen.path;
    }
    if (authState == AuthState.unauthenticated) {
      return WelcomeScreen.path;
    }
  }

  // Rule 3: Welcome with TOS+auth -> explore
  if (location.startsWith(WelcomeScreen.path)) {
    if (tosAccepted && authState == AuthState.authenticated) {
      return ExploreScreen.path;
    }
  }

  // Rule 4: No redirect needed
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Login Flow Redirect Logic', () {
    group('Unauthenticated user scenarios', () {
      test(
        'unauthenticated user on /welcome stays there (TOS not accepted)',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.path,
            authState: AuthState.unauthenticated,
            tosAccepted: false,
          );
          expect(
            redirect,
            isNull,
            reason: '${WelcomeScreen.path} should not redirect',
          );
        },
      );

      test(
        'unauthenticated user can access ${WelcomeScreen.loginOptionsPath}',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.loginOptionsPath,
            authState: AuthState.unauthenticated,
            tosAccepted: false, // TOS not yet accepted
          );
          expect(
            redirect,
            isNull,
            reason:
                '${WelcomeScreen.loginOptionsPath} is an auth route, should not redirect',
          );
        },
      );

      test(
        'unauthenticated user can access ${WelcomeScreen.loginOptionsPath} (TOS accepted)',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.loginOptionsPath,
            authState: AuthState.unauthenticated,
            tosAccepted: true, // User accepted TOS but logged out
          );
          expect(
            redirect,
            isNull,
            reason:
                '${WelcomeScreen.loginOptionsPath} is an auth route, TOS status should not matter',
          );
        },
      );

      test('unauthenticated user can access ${WelcomeScreen.authNativePath}', () {
        final redirect = testRedirectLogic(
          location: WelcomeScreen.authNativePath,
          authState: AuthState.unauthenticated,
          tosAccepted: false,
        );
        expect(
          redirect,
          isNull,
          reason:
              '${WelcomeScreen.authNativePath} is an auth route, should not redirect',
        );
      });

      test('unauthenticated user can access ${KeyImportScreen.path}', () {
        final redirect = testRedirectLogic(
          location: KeyImportScreen.path,
          authState: AuthState.unauthenticated,
          tosAccepted: false,
        );
        expect(
          redirect,
          isNull,
          reason:
              '${KeyImportScreen.path} is an auth route, should not redirect',
        );
      });

      test(
        'unauthenticated user on ${HomeScreenRouter.pathForIndex(0)} redirects to /welcome',
        () {
          final redirect = testRedirectLogic(
            location: HomeScreenRouter.pathForIndex(0),
            authState: AuthState.unauthenticated,
            tosAccepted: true, // Even with TOS, need auth for /home
          );
          expect(
            redirect,
            equals(WelcomeScreen.path),
            reason: 'Protected route should redirect unauthenticated user',
          );
        },
      );

      test(
        'unauthenticated user on ${ExploreScreen.path} redirects to ${WelcomeScreen.path}',
        () {
          final redirect = testRedirectLogic(
            location: ExploreScreen.path,
            authState: AuthState.unauthenticated,
            tosAccepted: true,
          );
          expect(
            redirect,
            equals(WelcomeScreen.path),
            reason: 'Protected route should redirect unauthenticated user',
          );
        },
      );
    });

    group('Authenticated user scenarios', () {
      test(
        'authenticated user on ${WelcomeScreen.path} redirects to ${HomeScreenRouter.pathForIndex(0)}',
        () {
          // Note: The actual router redirects to /home/0 first (Rule 1),
          // not /explore. This is because /welcome is treated as an auth route.
          final redirect = testRedirectLogic(
            location: WelcomeScreen.path,
            authState: AuthState.authenticated,
            tosAccepted: true,
          );
          expect(
            redirect,
            equals(HomeScreenRouter.pathForIndex(0)),
            reason:
                'Authenticated user on auth route goes to ${HomeScreenRouter.pathForIndex(0)}',
          );
        },
      );

      test(
        'authenticated user on ${WelcomeScreen.loginOptionsPath} redirects to ${HomeScreenRouter.pathForIndex(0)}',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.loginOptionsPath,
            authState: AuthState.authenticated,
            tosAccepted: true,
          );
          expect(
            redirect,
            equals(HomeScreenRouter.pathForIndex(0)),
            reason: 'Authenticated user on auth route should go to home',
          );
        },
      );

      test(
        'authenticated user on ${HomeScreenRouter.pathForIndex(0)} stays there',
        () {
          final redirect = testRedirectLogic(
            location: HomeScreenRouter.pathForIndex(0),
            authState: AuthState.authenticated,
            tosAccepted: true,
          );
          expect(
            redirect,
            isNull,
            reason: '${HomeScreenRouter.pathForIndex(0)} should not redirect',
          );
        },
      );

      test('authenticated user on ${ExploreScreen.path} stays there', () {
        final redirect = testRedirectLogic(
          location: ExploreScreen.path,
          authState: AuthState.authenticated,
          tosAccepted: true,
        );
        expect(
          redirect,
          isNull,
          reason: '${ExploreScreen.path} should not redirect',
        );
      });
    });

    group('TOS not accepted scenarios', () {
      test(
        'user without TOS on ${HomeScreenRouter.pathForIndex(0)} redirects to /welcome',
        () {
          final redirect = testRedirectLogic(
            location: HomeScreenRouter.pathForIndex(0),
            authState: AuthState.authenticated,
            tosAccepted: false,
          );
          expect(
            redirect,
            equals(WelcomeScreen.path),
            reason: 'User must accept TOS to access protected routes',
          );
        },
      );
    });

    group('Edge cases for the bug', () {
      test(
        '${WelcomeScreen.loginOptionsPath} should NEVER redirect to ${WelcomeScreen.path} for unauthenticated users',
        () {
          // This is the core bug scenario
          final redirect = testRedirectLogic(
            location: WelcomeScreen.loginOptionsPath,
            authState: AuthState.unauthenticated,
            tosAccepted: false,
          );

          expect(
            redirect,
            isNot(equals(WelcomeScreen.path)),
            reason:
                'BUG: ${LoginOptionsScreen.path} is an auth route and should be accessible '
                'to unauthenticated users trying to log in!',
          );
        },
      );

      test('${DivineAuthScreen.path}?mode=register should be accessible', () {
        final redirect = testRedirectLogic(
          location: WelcomeScreen.authNativePath,
          authState: AuthState.unauthenticated,
          tosAccepted: false,
        );

        expect(
          redirect,
          isNull,
          reason:
              '${DivineAuthScreen.path} should be accessible for registration',
        );
      });
    });
  });

  group('Route normalization bug - THE ROOT CAUSE', () {
    test(
      '${LoginOptionsScreen.path} should parse and rebuild to ${LoginOptionsScreen.path} (not /home/0)',
      () {
        final parsed = parseRoute(LoginOptionsScreen.path);
        final rebuilt = buildRoute(parsed);

        expect(
          parsed.type,
          equals(RouteType.loginOptions),
          reason:
              '${LoginOptionsScreen.path} should parse to loginOptions type, not home',
        );
        expect(
          rebuilt,
          equals(LoginOptionsScreen.path),
          reason:
              'Rebuilding ${LoginOptionsScreen.path} should NOT become /home/0',
        );
      },
    );

    test(
      '${DivineAuthScreen.path} should parse and rebuild to ${DivineAuthScreen.path} (not /home/0)',
      () {
        final parsed = parseRoute(DivineAuthScreen.path);
        final rebuilt = buildRoute(parsed);

        expect(
          parsed.type,
          equals(RouteType.authNative),
          reason:
              '${DivineAuthScreen.path} should parse to authNative type, not home',
        );
        expect(
          rebuilt,
          equals(DivineAuthScreen.path),
          reason:
              'Rebuilding ${DivineAuthScreen.path} should NOT become /home/0',
        );
      },
    );

    test(
      '${WelcomeScreen.path} should parse and rebuild to ${WelcomeScreen.path}',
      () {
        final parsed = parseRoute(WelcomeScreen.path);
        final rebuilt = buildRoute(parsed);

        expect(parsed.type, equals(RouteType.welcome));
        expect(rebuilt, equals(WelcomeScreen.path));
      },
    );

    test(
      '${KeyImportScreen.path} should parse and rebuild to ${KeyImportScreen.path}',
      () {
        final parsed = parseRoute(KeyImportScreen.path);
        final rebuilt = buildRoute(parsed);

        expect(parsed.type, equals(RouteType.importKey));
        expect(rebuilt, equals(KeyImportScreen.path));
      },
    );
  });
}
