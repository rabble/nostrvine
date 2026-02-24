// ABOUTME: Tests the redirect logic for login flow navigation
// ABOUTME: Tests redirect function behavior without full router instantiation

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/login_options_screen.dart';
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/services/auth_service.dart';

/// Isolated test of the redirect logic that mirrors app_router.dart redirect
/// function. This helps us understand what SHOULD happen without Firebase
/// dependencies.
///
/// IMPORTANT: This must stay in sync with the `redirect` callback in
/// `app_router.dart`. When you add a new auth route there, add it here too.
///
/// The actual redirect logic is:
/// 1. If authenticated AND on auth route -> redirect to /home/0
/// 2. If NOT on auth route AND unauthenticated -> redirect to /welcome
/// 3. Otherwise -> null (no redirect)
String? testRedirectLogic({
  required String location,
  required AuthState authState,
}) {
  // Auth routes that should be accessible without authentication.
  // Mirrors the isAuthRoute check in app_router.dart.
  final isAuthRoute =
      location.startsWith(WelcomeScreen.path) ||
      location.startsWith(KeyImportScreen.path) ||
      location.startsWith(NostrConnectScreen.path) ||
      location.startsWith(WelcomeScreen.resetPasswordPath) ||
      location.startsWith(ResetPasswordScreen.path) ||
      location.startsWith(EmailVerificationScreen.path);

  // Rule 1: Authenticated users on auth routes go to home
  if (authState == AuthState.authenticated && isAuthRoute) {
    return HomeScreenRouter.pathForIndex(0);
  }

  // Rule 2: Unauthenticated users on non-auth routes go to welcome
  if (!isAuthRoute && authState == AuthState.unauthenticated) {
    return WelcomeScreen.path;
  }

  // Rule 3: No redirect needed
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Login Flow Redirect Logic', () {
    group('Unauthenticated user scenarios', () {
      test('unauthenticated user on /welcome stays there', () {
        final redirect = testRedirectLogic(
          location: WelcomeScreen.path,
          authState: AuthState.unauthenticated,
        );
        expect(
          redirect,
          isNull,
          reason: '${WelcomeScreen.path} should not redirect',
        );
      });

      test(
        'unauthenticated user can access ${WelcomeScreen.loginOptionsPath}',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.loginOptionsPath,
            authState: AuthState.unauthenticated,
          );
          expect(
            redirect,
            isNull,
            reason:
                '${WelcomeScreen.loginOptionsPath} is an auth route, should not redirect',
          );
        },
      );

      test('unauthenticated user can access ${KeyImportScreen.path}', () {
        final redirect = testRedirectLogic(
          location: KeyImportScreen.path,
          authState: AuthState.unauthenticated,
        );
        expect(
          redirect,
          isNull,
          reason:
              '${KeyImportScreen.path} is an auth route, should not redirect',
        );
      });

      test(
        'unauthenticated user can access ${ResetPasswordScreen.path} deep link',
        () {
          final redirect = testRedirectLogic(
            location: ResetPasswordScreen.path,
            authState: AuthState.unauthenticated,
          );
          expect(
            redirect,
            isNull,
            reason:
                '${ResetPasswordScreen.path} is a deep link auth route, '
                'should not redirect to /welcome',
          );
        },
      );

      test(
        'unauthenticated user can access ${WelcomeScreen.resetPasswordPath}',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.resetPasswordPath,
            authState: AuthState.unauthenticated,
          );
          expect(
            redirect,
            isNull,
            reason:
                '${WelcomeScreen.resetPasswordPath} is an auth route, '
                'should not redirect',
          );
        },
      );

      test(
        'unauthenticated user can access ${EmailVerificationScreen.path}',
        () {
          final redirect = testRedirectLogic(
            location: EmailVerificationScreen.path,
            authState: AuthState.unauthenticated,
          );
          expect(
            redirect,
            isNull,
            reason:
                '${EmailVerificationScreen.path} is an auth route, '
                'should not redirect',
          );
        },
      );

      test(
        'unauthenticated user on ${HomeScreenRouter.pathForIndex(0)} redirects to /welcome',
        () {
          final redirect = testRedirectLogic(
            location: HomeScreenRouter.pathForIndex(0),
            authState: AuthState.unauthenticated,
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
          final redirect = testRedirectLogic(
            location: WelcomeScreen.path,
            authState: AuthState.authenticated,
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
        );
        expect(
          redirect,
          isNull,
          reason: '${ExploreScreen.path} should not redirect',
        );
      });
    });

    group('Edge cases', () {
      test(
        '${WelcomeScreen.loginOptionsPath} should NEVER redirect to ${WelcomeScreen.path} for unauthenticated users',
        () {
          final redirect = testRedirectLogic(
            location: WelcomeScreen.loginOptionsPath,
            authState: AuthState.unauthenticated,
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

      test('${ResetPasswordScreen.path} deep link should NEVER redirect to '
          '${WelcomeScreen.path} for unauthenticated users', () {
        final redirect = testRedirectLogic(
          location: ResetPasswordScreen.path,
          authState: AuthState.unauthenticated,
        );

        expect(
          redirect,
          isNot(equals(WelcomeScreen.path)),
          reason:
              'BUG: ${ResetPasswordScreen.path} is a deep link auth route '
              'and must be accessible to unauthenticated users resetting '
              'their password!',
        );
      });
    });
  });

  group('Route normalization bug - THE ROOT CAUSE', () {
    test(
      '${WelcomeScreen.loginOptionsPath} should parse and rebuild correctly (not /home/0)',
      () {
        final parsed = parseRoute(WelcomeScreen.loginOptionsPath);
        final rebuilt = buildRoute(parsed);

        expect(
          parsed.type,
          equals(RouteType.loginOptions),
          reason:
              '${WelcomeScreen.loginOptionsPath} should parse to loginOptions type, not home',
        );
        expect(
          rebuilt,
          equals(WelcomeScreen.loginOptionsPath),
          reason:
              'Rebuilding ${WelcomeScreen.loginOptionsPath} should NOT become /home/0',
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
