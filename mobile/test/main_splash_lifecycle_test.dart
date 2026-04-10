// ABOUTME: Unit tests for SplashLifecycleController — verifies the native
// splash is held until auth resolves (or a 2-second timeout fires),
// preventing the welcome-screen flash from issue #2749.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;

void main() {
  group(SplashLifecycleController, () {
    test(
      'removes splash when auth transitions from checking to authenticated',
      () {
        fakeAsync((async) {
          final controller = StreamController<AuthState>.broadcast();
          var removeCount = 0;

          final lifecycle = SplashLifecycleController(
            authStateStream: controller.stream,
            initialAuthState: AuthState.checking,
            onRemove: (_) => removeCount++,
          );

          lifecycle.start();
          async.flushMicrotasks();
          expect(removeCount, 0, reason: 'should wait for first emission');

          controller.add(AuthState.authenticated);
          async.flushMicrotasks();
          expect(
            removeCount,
            1,
            reason: 'authenticated emission must trigger removal',
          );

          lifecycle.dispose();
          controller.close();
        });
      },
    );

    test(
      'removes splash when auth transitions from checking to unauthenticated',
      () {
        // Covers the new-user-on-cold-start path: auth runs, finds no saved
        // session, and transitions to unauthenticated. The splash should
        // still be removed so the user sees the welcome screen underneath.
        fakeAsync((async) {
          final controller = StreamController<AuthState>.broadcast();
          var removeCount = 0;

          final lifecycle = SplashLifecycleController(
            authStateStream: controller.stream,
            initialAuthState: AuthState.checking,
            onRemove: (_) => removeCount++,
          );

          lifecycle.start();
          controller.add(AuthState.unauthenticated);
          async.flushMicrotasks();

          expect(removeCount, 1);
          lifecycle.dispose();
          controller.close();
        });
      },
    );

    test(
      'removes splash when auth transitions to authenticating '
      '(not just checking or authenticated)',
      () {
        // `authenticating` is not `checking`, so the splash should release.
        // This covers the case where the saved session triggers a sign-in
        // flow (bunker reconnect, amber, OAuth refresh) that reaches
        // `authenticating` before `authenticated`.
        fakeAsync((async) {
          final controller = StreamController<AuthState>.broadcast();
          var removeCount = 0;

          final lifecycle = SplashLifecycleController(
            authStateStream: controller.stream,
            initialAuthState: AuthState.checking,
            onRemove: (_) => removeCount++,
          );

          lifecycle.start();
          controller.add(AuthState.authenticating);
          async.flushMicrotasks();

          expect(removeCount, 1);
          lifecycle.dispose();
          controller.close();
        });
      },
    );

    test(
      'removes splash immediately when initial state is already resolved',
      () {
        // Hot-reload, or a test scenario where the caller constructs the
        // controller after auth has already resolved synchronously.
        fakeAsync((async) {
          final controller = StreamController<AuthState>.broadcast();
          var removeCount = 0;

          final lifecycle = SplashLifecycleController(
            authStateStream: controller.stream,
            initialAuthState: AuthState.authenticated,
            onRemove: (_) => removeCount++,
          );

          lifecycle.start();
          async.flushMicrotasks();

          expect(
            removeCount,
            1,
            reason: 'already-resolved state must fire synchronously',
          );
          lifecycle.dispose();
          controller.close();
        });
      },
    );

    test(
      'removes splash on timeout when auth never emits',
      () {
        // Catastrophic failure path: auth hangs or never emits. The 2-second
        // timeout must fire to avoid an infinite splash.
        fakeAsync((async) {
          final controller = StreamController<AuthState>.broadcast();
          var removeCount = 0;

          final lifecycle = SplashLifecycleController(
            authStateStream: controller.stream,
            initialAuthState: AuthState.checking,
            onRemove: (_) => removeCount++,
          );

          lifecycle.start();

          async.elapse(const Duration(seconds: 1));
          expect(removeCount, 0, reason: 'too early for timeout');

          async.elapse(
            const Duration(seconds: 1, milliseconds: 1),
          );
          expect(
            removeCount,
            1,
            reason: 'timeout must fire at 2 seconds',
          );

          lifecycle.dispose();
          controller.close();
        });
      },
    );

    test(
      'is idempotent: multiple transitions only trigger removal once',
      () {
        fakeAsync((async) {
          final controller = StreamController<AuthState>.broadcast();
          var removeCount = 0;

          final lifecycle = SplashLifecycleController(
            authStateStream: controller.stream,
            initialAuthState: AuthState.checking,
            onRemove: (_) => removeCount++,
          );

          lifecycle.start();
          controller
            ..add(AuthState.authenticated)
            ..add(AuthState.authenticating)
            ..add(AuthState.authenticated)
            ..add(AuthState.unauthenticated);
          async.flushMicrotasks();

          expect(
            removeCount,
            1,
            reason: 'subsequent transitions must not re-trigger',
          );
          lifecycle.dispose();
          controller.close();
        });
      },
    );

    test(
      'race: stream emits and timeout fires together — only one removal',
      () {
        fakeAsync((async) {
          final controller = StreamController<AuthState>.broadcast();
          var removeCount = 0;

          final lifecycle = SplashLifecycleController(
            authStateStream: controller.stream,
            initialAuthState: AuthState.checking,
            onRemove: (_) => removeCount++,
          );

          lifecycle.start();
          async.elapse(const Duration(seconds: 2));
          controller.add(AuthState.authenticated);
          async.flushMicrotasks();

          expect(removeCount, 1);
          lifecycle.dispose();
          controller.close();
        });
      },
    );

    test('dispose before start is a no-op', () {
      final controller = StreamController<AuthState>.broadcast();
      var removeCount = 0;

      final lifecycle = SplashLifecycleController(
        authStateStream: controller.stream,
        initialAuthState: AuthState.checking,
        onRemove: (_) => removeCount++,
      );

      lifecycle.dispose();
      expect(removeCount, 0);
      expect(lifecycle.debugRemoved, isFalse);
      controller.close();
    });

    test(
      'dispose after start cancels stream subscription and timer',
      () {
        fakeAsync((async) {
          final controller = StreamController<AuthState>.broadcast();
          var removeCount = 0;

          final lifecycle = SplashLifecycleController(
            authStateStream: controller.stream,
            initialAuthState: AuthState.checking,
            onRemove: (_) => removeCount++,
          );

          lifecycle.start();
          lifecycle.dispose();

          // Timer should not fire after dispose
          async.elapse(const Duration(seconds: 5));
          expect(removeCount, 0, reason: 'timer should be cancelled');

          // Stream events should not trigger removal after dispose
          controller.add(AuthState.authenticated);
          async.flushMicrotasks();
          expect(removeCount, 0, reason: 'subscription should be cancelled');

          controller.close();
        });
      },
    );

    test('debugRemoved reflects removal state', () {
      fakeAsync((async) {
        final controller = StreamController<AuthState>.broadcast();

        final lifecycle = SplashLifecycleController(
          authStateStream: controller.stream,
          initialAuthState: AuthState.checking,
          onRemove: (_) {},
        );

        expect(lifecycle.debugRemoved, isFalse);

        lifecycle.start();
        expect(lifecycle.debugRemoved, isFalse);

        controller.add(AuthState.authenticated);
        async.flushMicrotasks();
        expect(lifecycle.debugRemoved, isTrue);

        lifecycle.dispose();
        controller.close();
      });
    });

    group('SplashRemovalReason', () {
      test('passes authResolved when auth transitions out of checking', () {
        fakeAsync((async) {
          final controller = StreamController<AuthState>.broadcast();
          SplashRemovalReason? capturedReason;

          final lifecycle = SplashLifecycleController(
            authStateStream: controller.stream,
            initialAuthState: AuthState.checking,
            onRemove: (reason) => capturedReason = reason,
          );

          lifecycle.start();
          controller.add(AuthState.authenticated);
          async.flushMicrotasks();

          expect(capturedReason, SplashRemovalReason.authResolved);
          lifecycle.dispose();
          controller.close();
        });
      });

      test('passes authResolved when initial state is already resolved', () {
        fakeAsync((async) {
          final controller = StreamController<AuthState>.broadcast();
          SplashRemovalReason? capturedReason;

          final lifecycle = SplashLifecycleController(
            authStateStream: controller.stream,
            initialAuthState: AuthState.authenticated,
            onRemove: (reason) => capturedReason = reason,
          );

          lifecycle.start();
          async.flushMicrotasks();

          expect(capturedReason, SplashRemovalReason.authResolved);
          lifecycle.dispose();
          controller.close();
        });
      });

      test('passes timeout when auth never emits', () {
        fakeAsync((async) {
          final controller = StreamController<AuthState>.broadcast();
          SplashRemovalReason? capturedReason;

          final lifecycle = SplashLifecycleController(
            authStateStream: controller.stream,
            initialAuthState: AuthState.checking,
            onRemove: (reason) => capturedReason = reason,
          );

          lifecycle.start();
          async.elapse(const Duration(seconds: 2));

          expect(capturedReason, SplashRemovalReason.timeout);
          lifecycle.dispose();
          controller.close();
        });
      });
    });

    test('assert fires on double start', () {
      fakeAsync((async) {
        final controller = StreamController<AuthState>.broadcast();

        final lifecycle = SplashLifecycleController(
          authStateStream: controller.stream,
          initialAuthState: AuthState.checking,
          onRemove: (_) {},
        );

        lifecycle.start();
        expect(lifecycle.start, throwsA(isA<AssertionError>()));

        lifecycle.dispose();
        controller.close();
      });
    });
  });

  group('splashRemovalTimeout constant', () {
    test("is 2 seconds to match Alex's recommendation on PR #2837", () {
      expect(splashRemovalTimeout, const Duration(seconds: 2));
    });
  });

  group('post-frame callback is frame-dependent (documents the bug)', () {
    // This test proves WHY the timeout path must bypass addPostFrameCallback.
    // addPostFrameCallback registers a callback that runs after the NEXT
    // frame, but it does not schedule a frame. If no frame is ever
    // scheduled (e.g. auth is hung and no UI work is happening), the
    // callback sits pending forever. The timeout fallback must therefore
    // release the splash immediately, not through addPostFrameCallback.
    testWidgets(
      'addPostFrameCallback does not fire without a scheduled frame',
      (tester) async {
        var callbackFired = false;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          callbackFired = true;
        });

        // Advance time without pumping a frame — simulates the hung-auth
        // scenario where no widget rebuild triggers a frame.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          callbackFired,
          isFalse,
          reason:
              'post-frame callback must not fire without a frame — '
              'this is why the timeout path releases the splash immediately',
        );

        // Now pump a frame to prove the callback was registered and does
        // fire once a frame exists.
        await tester.pump();
        expect(callbackFired, isTrue);
      },
    );
  });
}
