// ABOUTME: Verifies AppLifecycleHandler releases the PlayerPool on background.
// ABOUTME: Prevents the iOS RUNNINGBOARD 0xdead10cc watchdog SIGKILL where
// ABOUTME: media_kit (mpv) keeps native dispatch loops alive past suspension.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/video_visibility_manager.dart';
import 'package:openvine/widgets/app_lifecycle_handler.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

class _MockPlayerPool extends Mock implements PlayerPool {}

class _FakeAuthService extends Fake implements AuthService {
  // Broadcast stream that never emits — keeps the lifecycle handler's
  // postFrameCallback awaiting an authenticated state for the lifetime
  // of the test, so it never proceeds to read other providers we have
  // not overridden. We deliberately do NOT close the controller in
  // tearDown: a closed stream completes `firstWhere` with a StateError
  // that surfaces as a post-test failure.
  final _controller = StreamController<AuthState>.broadcast();

  @override
  bool get isAuthenticated => false;

  @override
  Stream<AuthState> get authStateStream => _controller.stream;
}

void main() {
  late _MockPlayerPool mockPool;
  late _FakeAuthService fakeAuthService;
  late VideoVisibilityManager visibilityManager;

  setUp(() {
    mockPool = _MockPlayerPool();
    fakeAuthService = _FakeAuthService();
    visibilityManager = VideoVisibilityManager();

    when(() => mockPool.releaseAll()).thenAnswer((_) async {});

    PlayerPool.instanceForTesting = mockPool;
    // BackgroundActivityManager is a process-wide singleton. Tests in this
    // file share the same instance — reset it to foreground before each
    // test so the next backgrounding triggers a fresh _onAppBackgrounded.
    BackgroundActivityManager().onAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  tearDown(() {
    PlayerPool.instanceForTesting = null;
    // Cancel the 30s _backgroundSuspensionTimer that _onAppBackgrounded
    // schedules; otherwise flutter_test's _verifyInvariants asserts on
    // pending timers and the test fails after passing assertions.
    BackgroundActivityManager().onAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  Future<void> pumpHandler(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(fakeAuthService),
          videoVisibilityManagerProvider.overrideWithValue(visibilityManager),
        ],
        child: const MaterialApp(
          home: AppLifecycleHandler(
            child: SizedBox(),
          ),
        ),
      ),
    );
  }

  // Each test that transitions to paused/hidden must transition back to
  // resumed before returning. _onAppBackgrounded schedules a 30s timer,
  // and flutter_test's _verifyInvariants asserts no pending timers when
  // the test body ends. _onAppResumed cancels the timer.
  Future<void> drainBackgroundTimer(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  testWidgets(
    'releases PlayerPool when app transitions to paused',
    (tester) async {
      await pumpHandler(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      verify(() => mockPool.releaseAll()).called(1);

      await drainBackgroundTimer(tester);
    },
  );

  testWidgets(
    'releases PlayerPool when app transitions to hidden',
    (tester) async {
      await pumpHandler(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();

      verify(() => mockPool.releaseAll()).called(1);

      await drainBackgroundTimer(tester);
    },
  );

  testWidgets(
    'does not release PlayerPool on inactive (desktop transient state)',
    (tester) async {
      await pumpHandler(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      verifyNever(() => mockPool.releaseAll());
    },
  );

  testWidgets(
    'does not crash when PlayerPool is not initialized',
    (tester) async {
      // Simulate uninitialized pool (e.g. on web where PlayerPool.init is
      // skipped). The lifecycle handler must guard on isInitialized.
      PlayerPool.instanceForTesting = null;

      await pumpHandler(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // No assertion on the mock — it was never registered. Reaching this
      // line means the guarded call did not throw.
      verifyZeroInteractions(mockPool);

      await drainBackgroundTimer(tester);
    },
  );
}
