// ABOUTME: Tests app-level quick-action auth gating and routing decisions.
// ABOUTME: Covers cold-start deferral without building the whole app shell.

import 'dart:async';

import 'package:divine_quick_actions/divine_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
import 'package:openvine/services/quick_actions_coordinator.dart';

void main() {
  group('QuickActionsCoordinator', () {
    test('defers a launch action while auth is checking', () async {
      final client = _FakeQuickActionsClient();
      final navigator = _FakeQuickActionsNavigator();
      var authState = AuthState.checking;
      final coordinator = _coordinator(
        client: client,
        navigator: navigator,
        readAuthState: () => authState,
      );

      coordinator.handleAction(
        const DivineQuickActionEvent(
          type: quickActionCameraType,
          isLaunchAction: true,
        ),
      );

      expect(navigator.openedRoutes, isEmpty);

      authState = AuthState.authenticated;
      coordinator.handleAuthStateChanged(authState);
      await _flushAsyncWork();

      expect(navigator.openedRoutes, equals(<String>['camera']));
    });

    test(
      'drops a deferred action when auth resolves unauthenticated',
      () async {
        final client = _FakeQuickActionsClient();
        final navigator = _FakeQuickActionsNavigator();
        var authState = AuthState.checking;
        final coordinator = _coordinator(
          client: client,
          navigator: navigator,
          readAuthState: () => authState,
        );

        coordinator.handleAction(
          const DivineQuickActionEvent(type: quickActionCameraType),
        );
        authState = AuthState.unauthenticated;
        coordinator.handleAuthStateChanged(authState);
        await _flushAsyncWork();

        expect(navigator.openedRoutes, isEmpty);
        expect(client.clearCount, isZero);
      },
    );

    test('ignores and clears shortcuts while unauthenticated', () async {
      final client = _FakeQuickActionsClient();
      final navigator = _FakeQuickActionsNavigator();
      final coordinator = _coordinator(
        client: client,
        navigator: navigator,
        readAuthState: () => AuthState.unauthenticated,
      );

      coordinator.handleAction(
        const DivineQuickActionEvent(type: quickActionCameraType),
      );
      await _flushAsyncWork();

      expect(navigator.openedRoutes, isEmpty);
      expect(client.clearCount, 1);
    });

    test('routes camera and notifications actions when authenticated', () {
      final client = _FakeQuickActionsClient();
      final navigator = _FakeQuickActionsNavigator();
      final coordinator = _coordinator(
        client: client,
        navigator: navigator,
        readAuthState: () => AuthState.authenticated,
      );

      coordinator
        ..handleAction(
          const DivineQuickActionEvent(type: quickActionCameraType),
        )
        ..handleAction(
          const DivineQuickActionEvent(type: quickActionNotificationsType),
        );

      expect(
        navigator.openedRoutes,
        equals(<String>['camera', 'notifications']),
      );
    });

    test('suppresses and then clears auth-route redirect for camera route', () {
      final client = _FakeQuickActionsClient();
      final navigator = _FakeQuickActionsNavigator();
      void Function()? scheduledClear;
      final coordinator = _coordinator(
        client: client,
        navigator: navigator,
        readAuthState: () => AuthState.authenticated,
        scheduleRedirectSuppressionClear: (callback) {
          scheduledClear = callback;
        },
      );

      coordinator.handleAction(
        const DivineQuickActionEvent(type: quickActionCameraType),
      );

      expect(navigator.suppressCount, 1);
      expect(navigator.clearSuppressionCount, isZero);
      expect(scheduledClear, isNotNull);

      scheduledClear!();

      expect(navigator.clearSuppressionCount, 1);
    });

    test(
      'dismisses the launch cover after the camera frame settles on Android',
      () {
        final client = _FakeQuickActionsClient();
        final navigator = _FakeQuickActionsNavigator();
        void Function()? scheduled;
        final coordinator = _coordinator(
          client: client,
          navigator: navigator,
          readAuthState: () => AuthState.authenticated,
          isAndroid: true,
          scheduleRedirectSuppressionClear: (callback) => scheduled = callback,
        );

        coordinator.handleAction(
          const DivineQuickActionEvent(type: quickActionCameraType),
        );

        // Cover stays up until the post-frame callback confirms navigation.
        expect(client.dismissLaunchCoverCount, isZero);

        scheduled!();

        expect(client.dismissLaunchCoverCount, 1);
        expect(navigator.openedRoutes, equals(<String>['camera']));
      },
    );

    test('does not dismiss a launch cover off Android', () {
      final client = _FakeQuickActionsClient();
      final navigator = _FakeQuickActionsNavigator();
      void Function()? scheduled;
      final coordinator = _coordinator(
        client: client,
        navigator: navigator,
        readAuthState: () => AuthState.authenticated,
        scheduleRedirectSuppressionClear: (callback) => scheduled = callback,
      );

      coordinator.handleAction(
        const DivineQuickActionEvent(type: quickActionCameraType),
      );
      scheduled!();

      expect(client.dismissLaunchCoverCount, isZero);
    });

    test(
      'dismisses the launch cover even when already on the camera route',
      () {
        final client = _FakeQuickActionsClient();
        final navigator = _FakeQuickActionsNavigator()
          ..currentPath = '/video-recorder';
        void Function()? scheduled;
        final coordinator = _coordinator(
          client: client,
          navigator: navigator,
          readAuthState: () => AuthState.authenticated,
          isAndroid: true,
          scheduleRedirectSuppressionClear: (callback) => scheduled = callback,
        );

        coordinator.handleAction(
          const DivineQuickActionEvent(type: quickActionCameraType),
        );

        expect(navigator.openedRoutes, isEmpty);
        expect(navigator.suppressCount, isZero);

        scheduled!();

        // The cover was drawn natively before the action reached Dart, so it
        // must still be dropped even though no navigation was needed.
        expect(client.dismissLaunchCoverCount, 1);
        expect(navigator.clearSuppressionCount, isZero);
      },
    );

    test('dismisses the launch cover when ignoring an unauthenticated action '
        'on Android', () {
      final client = _FakeQuickActionsClient();
      final navigator = _FakeQuickActionsNavigator();
      final coordinator = _coordinator(
        client: client,
        navigator: navigator,
        readAuthState: () => AuthState.unauthenticated,
        isAndroid: true,
      );

      coordinator.handleAction(
        const DivineQuickActionEvent(type: quickActionCameraType),
      );

      expect(client.dismissLaunchCoverCount, 1);
      expect(navigator.openedRoutes, isEmpty);
    });

    test(
      'dismisses the launch cover when dropping a deferred action on Android',
      () {
        final client = _FakeQuickActionsClient();
        final navigator = _FakeQuickActionsNavigator();
        var authState = AuthState.checking;
        final coordinator = _coordinator(
          client: client,
          navigator: navigator,
          readAuthState: () => authState,
          isAndroid: true,
        );

        coordinator.handleAction(
          const DivineQuickActionEvent(
            type: quickActionCameraType,
            isLaunchAction: true,
          ),
        );
        expect(client.dismissLaunchCoverCount, isZero);

        authState = AuthState.unauthenticated;
        coordinator.handleAuthStateChanged(authState);

        expect(client.dismissLaunchCoverCount, 1);
        expect(navigator.openedRoutes, isEmpty);
      },
    );

    test('does not reopen camera when already on the camera route', () {
      final client = _FakeQuickActionsClient();
      final navigator = _FakeQuickActionsNavigator()
        ..currentPath = '/video-recorder';
      final coordinator = _coordinator(
        client: client,
        navigator: navigator,
        readAuthState: () => AuthState.authenticated,
      );

      coordinator.handleAction(
        const DivineQuickActionEvent(type: quickActionCameraType),
      );

      expect(navigator.openedRoutes, isEmpty);
      expect(navigator.suppressCount, isZero);
    });

    test('syncs authenticated actions and clears first on Android', () async {
      final client = _FakeQuickActionsClient();
      final navigator = _FakeQuickActionsNavigator();
      final coordinator = _coordinator(
        client: client,
        navigator: navigator,
        readAuthState: () => AuthState.authenticated,
        isAndroid: true,
      );

      await coordinator.syncActions();

      expect(client.clearCount, 1);
      expect(
        client.actions.map((action) => action.type),
        equals(<String>[quickActionCameraType, quickActionNotificationsType]),
      );
    });
  });
}

QuickActionsCoordinator _coordinator({
  required _FakeQuickActionsClient client,
  required _FakeQuickActionsNavigator navigator,
  required AuthState Function() readAuthState,
  QuickActionCallbackScheduler? scheduleRedirectSuppressionClear,
  bool isAndroid = false,
}) {
  return QuickActionsCoordinator(
    client: client,
    authStateStream: const Stream<AuthState>.empty(),
    readAuthState: readAuthState,
    readTitles: () => const QuickActionTitles(
      camera: 'Camera',
      notifications: 'Notifications',
    ),
    navigator: navigator,
    reportError: (error, stackTrace, reason) async {},
    waitForAuthRedirectToSettle: () async => true,
    scheduleRedirectSuppressionClear:
        scheduleRedirectSuppressionClear ?? (callback) {},
    isAndroid: isAndroid,
  );
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeQuickActionsClient implements QuickActionsClient {
  bool supported = true;
  int clearCount = 0;
  int dismissLaunchCoverCount = 0;
  List<DivineQuickAction> actions = const <DivineQuickAction>[];
  void Function(DivineQuickActionEvent action)? onAction;

  @override
  Future<bool> get isSupported async => supported;

  @override
  Future<DivineQuickActionEvent?> initialize({
    void Function(DivineQuickActionEvent action)? onAction,
  }) async {
    this.onAction = onAction;
    return null;
  }

  @override
  Future<bool> setActions(List<DivineQuickAction> actions) async {
    this.actions = actions;
    return true;
  }

  @override
  Future<bool> clearActions() async {
    clearCount += 1;
    return true;
  }

  @override
  Future<void> dismissLaunchCover() async {
    dismissLaunchCoverCount += 1;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeQuickActionsNavigator implements QuickActionsNavigator {
  @override
  String currentPath = '/home/0';

  final openedRoutes = <String>[];
  int suppressCount = 0;
  int clearSuppressionCount = 0;

  @override
  void openCamera() {
    openedRoutes.add('camera');
    currentPath = '/video-recorder';
  }

  @override
  void openNotifications() {
    openedRoutes.add('notifications');
    currentPath = '/inbox';
  }

  @override
  void suppressAuthenticatedAuthRouteRedirect() {
    suppressCount += 1;
  }

  @override
  void clearAuthRouteRedirectSuppression() {
    clearSuppressionCount += 1;
  }
}
