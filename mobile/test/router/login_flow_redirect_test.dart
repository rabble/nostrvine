// ABOUTME: Tests the redirect logic for login flow navigation
// ABOUTME: Tests redirect function behavior without full router instantiation

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/router/route_utils.dart';

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
      location.startsWith('/welcome') ||
      location.startsWith('/import-key') ||
      location.startsWith('/login-options') ||
      location.startsWith('/auth-native');

  // Rule 1: Authenticated users on auth routes go to home
  if (authState == AuthState.authenticated && isAuthRoute) {
    return '/home/0';
  }

  // Rule 2: Non-auth routes require TOS AND authentication
  if (!isAuthRoute) {
    if (!tosAccepted) {
      return '/welcome';
    }
    if (authState == AuthState.unauthenticated) {
      return '/welcome';
    }
  }

  // Rule 3: Welcome with TOS+auth -> explore
  if (location.startsWith('/welcome')) {
    if (tosAccepted && authState == AuthState.authenticated) {
      return '/explore';
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
            location: '/welcome',
            authState: AuthState.unauthenticated,
            tosAccepted: false,
          );
          expect(redirect, isNull, reason: '/welcome should not redirect');
        },
      );

      test('unauthenticated user can access /login-options', () {
        final redirect = testRedirectLogic(
          location: '/login-options',
          authState: AuthState.unauthenticated,
          tosAccepted: false, // TOS not yet accepted
        );
        expect(
          redirect,
          isNull,
          reason: '/login-options is an auth route, should not redirect',
        );
      });

      test('unauthenticated user can access /login-options (TOS accepted)', () {
        final redirect = testRedirectLogic(
          location: '/login-options',
          authState: AuthState.unauthenticated,
          tosAccepted: true, // User accepted TOS but logged out
        );
        expect(
          redirect,
          isNull,
          reason:
              '/login-options is an auth route, TOS status should not matter',
        );
      });

      test('unauthenticated user can access /auth-native', () {
        final redirect = testRedirectLogic(
          location: '/auth-native',
          authState: AuthState.unauthenticated,
          tosAccepted: false,
        );
        expect(
          redirect,
          isNull,
          reason: '/auth-native is an auth route, should not redirect',
        );
      });

      test('unauthenticated user can access /import-key', () {
        final redirect = testRedirectLogic(
          location: '/import-key',
          authState: AuthState.unauthenticated,
          tosAccepted: false,
        );
        expect(
          redirect,
          isNull,
          reason: '/import-key is an auth route, should not redirect',
        );
      });

      test('unauthenticated user on /home/0 redirects to /welcome', () {
        final redirect = testRedirectLogic(
          location: '/home/0',
          authState: AuthState.unauthenticated,
          tosAccepted: true, // Even with TOS, need auth for /home
        );
        expect(
          redirect,
          equals('/welcome'),
          reason: 'Protected route should redirect unauthenticated user',
        );
      });

      test('unauthenticated user on /explore redirects to /welcome', () {
        final redirect = testRedirectLogic(
          location: '/explore',
          authState: AuthState.unauthenticated,
          tosAccepted: true,
        );
        expect(
          redirect,
          equals('/welcome'),
          reason: 'Protected route should redirect unauthenticated user',
        );
      });
    });

    group('Authenticated user scenarios', () {
      test('authenticated user on /welcome redirects to /home/0', () {
        // Note: The actual router redirects to /home/0 first (Rule 1),
        // not /explore. This is because /welcome is treated as an auth route.
        final redirect = testRedirectLogic(
          location: '/welcome',
          authState: AuthState.authenticated,
          tosAccepted: true,
        );
        expect(
          redirect,
          equals('/home/0'),
          reason: 'Authenticated user on auth route goes to /home/0',
        );
      });

      test('authenticated user on /login-options redirects to /home/0', () {
        final redirect = testRedirectLogic(
          location: '/login-options',
          authState: AuthState.authenticated,
          tosAccepted: true,
        );
        expect(
          redirect,
          equals('/home/0'),
          reason: 'Authenticated user on auth route should go to home',
        );
      });

      test('authenticated user on /home/0 stays there', () {
        final redirect = testRedirectLogic(
          location: '/home/0',
          authState: AuthState.authenticated,
          tosAccepted: true,
        );
        expect(redirect, isNull, reason: '/home/0 should not redirect');
      });

      test('authenticated user on /explore stays there', () {
        final redirect = testRedirectLogic(
          location: '/explore',
          authState: AuthState.authenticated,
          tosAccepted: true,
        );
        expect(redirect, isNull, reason: '/explore should not redirect');
      });
    });

    group('TOS not accepted scenarios', () {
      test('user without TOS on /home/0 redirects to /welcome', () {
        final redirect = testRedirectLogic(
          location: '/home/0',
          authState: AuthState.authenticated,
          tosAccepted: false,
        );
        expect(
          redirect,
          equals('/welcome'),
          reason: 'User must accept TOS to access protected routes',
        );
      });
    });

    group('Edge cases for the bug', () {
      test(
        '/login-options should NEVER redirect to /welcome for unauthenticated users',
        () {
          // This is the core bug scenario
          final redirect = testRedirectLogic(
            location: '/login-options',
            authState: AuthState.unauthenticated,
            tosAccepted: false,
          );

          expect(
            redirect,
            isNot(equals('/welcome')),
            reason:
                'BUG: /login-options is an auth route and should be accessible '
                'to unauthenticated users trying to log in!',
          );
        },
      );

      test('/auth-native?mode=register should be accessible', () {
        final redirect = testRedirectLogic(
          location: '/auth-native',
          authState: AuthState.unauthenticated,
          tosAccepted: false,
        );

        expect(
          redirect,
          isNull,
          reason: '/auth-native should be accessible for registration',
        );
      });
    });
  });

  group('Route normalization bug - THE ROOT CAUSE', () {
    test(
      '/login-options should parse and rebuild to /login-options (not /home/0)',
      () {
        final parsed = parseRoute('/login-options');
        final rebuilt = buildRoute(parsed);

        expect(
          parsed.type,
          equals(RouteType.loginOptions),
          reason: '/login-options should parse to loginOptions type, not home',
        );
        expect(
          rebuilt,
          equals('/login-options'),
          reason: 'Rebuilding /login-options should NOT become /home/0',
        );
      },
    );

    test(
      '/auth-native should parse and rebuild to /auth-native (not /home/0)',
      () {
        final parsed = parseRoute('/auth-native');
        final rebuilt = buildRoute(parsed);

        expect(
          parsed.type,
          equals(RouteType.authNative),
          reason: '/auth-native should parse to authNative type, not home',
        );
        expect(
          rebuilt,
          equals('/auth-native'),
          reason: 'Rebuilding /auth-native should NOT become /home/0',
        );
      },
    );

    test('/welcome should parse and rebuild to /welcome', () {
      final parsed = parseRoute('/welcome');
      final rebuilt = buildRoute(parsed);

      expect(parsed.type, equals(RouteType.welcome));
      expect(rebuilt, equals('/welcome'));
    });

    test('/import-key should parse and rebuild to /import-key', () {
      final parsed = parseRoute('/import-key');
      final rebuilt = buildRoute(parsed);

      expect(parsed.type, equals(RouteType.importKey));
      expect(rebuilt, equals('/import-key'));
    });
  });
}
