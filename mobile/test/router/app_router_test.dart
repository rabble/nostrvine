// ABOUTME: Regression tests for goRouterProvider lifecycle cleanup
// ABOUTME: Verifies stale auth refreshes do not reach a disposed container

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _AuthStateBus {
  AuthState state = AuthState.unauthenticated;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetNavigationState);

  test(
    'disposes the router refresh listener before a late auth refresh fires',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final authStateController = StreamController<AuthState>.broadcast(
        sync: true,
      );
      addTearDown(authStateController.close);

      final authStateBus = _AuthStateBus();

      ProviderContainer createContainer() {
        return ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWith((ref) {
              final authService = _MockAuthService();
              when(
                () => authService.authStateStream,
              ).thenAnswer((_) => authStateController.stream);
              when(
                () => authService.authState,
              ).thenAnswer((_) => authStateBus.state);
              when(() => authService.hasExpiredOAuthSession).thenReturn(false);
              return authService;
            }),
          ],
        );
      }

      final containerA = createContainer();
      final routerA = containerA.read(goRouterProvider);
      expect(routerA, isA<GoRouter>());

      containerA.dispose();

      authStateBus.state = AuthState.authenticated;
      expect(
        () => authStateController.add(AuthState.authenticated),
        returnsNormally,
      );

      authStateBus.state = AuthState.unauthenticated;
      final containerB = createContainer();
      addTearDown(containerB.dispose);

      final routerB = containerB.read(goRouterProvider);
      expect(routerB, isA<GoRouter>());
    },
  );
}
