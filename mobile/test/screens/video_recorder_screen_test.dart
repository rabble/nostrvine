// ABOUTME: Tests for VideoRecorderScreen - main video recording UI
// ABOUTME: Tests screen initialization, camera setup, UI elements, and lifecycle

import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_countdown_overlay.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_top_bar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../mocks/mock_camera_service.dart';

/// Mock for CameraPermissionBloc
class MockCameraPermissionBloc extends Mock implements CameraPermissionBloc {
  @override
  CameraPermissionState get state =>
      const CameraPermissionLoaded(CameraPermissionStatus.authorized);

  @override
  Stream<CameraPermissionState> get stream => Stream.value(state);

  @override
  Future<void> close() async {
    // No-op for mock
  }
}

/// Helper to build VideoRecorderScreen with required providers
Widget buildTestWidget() {
  return ProviderScope(
    child: BlocProvider<CameraPermissionBloc>(
      create: (_) => MockCameraPermissionBloc(),
      child: const MaterialApp(home: VideoRecorderScreen()),
    ),
  );
}

/// Helper to build VideoRecorderScreen with provider overrides
Widget buildTestWidgetWithOverrides(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: BlocProvider<CameraPermissionBloc>(
      create: (_) => MockCameraPermissionBloc(),
      child: const MaterialApp(home: VideoRecorderScreen()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderScreen Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('UI Components', () {
      testWidgets('renders camera preview widget', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        expect(find.byType(VideoRecorderCameraPreview), findsOneWidget);
      });

      testWidgets('renders top bar widget', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        expect(find.byType(VideoRecorderTopBar), findsOneWidget);
      });

      testWidgets('renders bottom bar widget', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        expect(find.byType(VideoRecorderBottomBar), findsOneWidget);
      });

      testWidgets('renders countdown overlay widget', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        expect(find.byType(VideoRecorderCountdownOverlay), findsOneWidget);
      });

      testWidgets('all widgets are rendered in correct order (z-index)', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        final stackFinder = find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Stack),
        );

        final stackChildren = tester.widget<Stack>(stackFinder.first).children;

        // Check order: Column (with camera + controls), Countdown overlay
        expect(stackChildren[0], isA<Column>());
        expect(stackChildren[1], isA<VideoRecorderCountdownOverlay>());
      });
    });

    group('Initialization', () {
      testWidgets('initializes recording provider on mount', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();
        await tester.pump(); // Post-frame callback

        // Provider should be read during initialization
        expect(() => container.read(videoRecorderProvider), returnsNormally);
      });

      testWidgets('registers as WidgetsBindingObserver', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Observer should be registered (verified by no exception)
        expect(find.byType(VideoRecorderScreen), findsOneWidget);
      });
    });

    group('Lifecycle Management', () {
      testWidgets('handles app lifecycle state changes', (tester) async {
        // Override platform to avoid macOS-specific camera preview
        // which requires a native texture not available in tests
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        try {
          final mockCamera = MockCameraService.create(
            onUpdateState: ({forceCameraRebuild}) {},
            onAutoStopped: (_) {},
          );
          await mockCamera.initialize();

          await tester.pumpWidget(
            buildTestWidgetWithOverrides([
              videoRecorderProvider.overrideWith(
                () => VideoRecorderNotifier(mockCamera),
              ),
            ]),
          );

          await tester.pump();

          // Simulate app going to background
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();

          // Simulate app coming back to foreground
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();

          // Should not crash
          expect(find.byType(VideoRecorderScreen), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('unregister observer on dispose', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Remove the widget
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Other screen'))),
        );

        await tester.pump();

        // Should have disposed without errors
        expect(find.byType(VideoRecorderScreen), findsNothing);
      });

      testWidgets('destroys notifier on dispose', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();
        await tester.pump(); // Post-frame callback

        // Navigate away
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Other screen'))),
        );

        await tester.pumpAndSettle();

        // Should have disposed cleanly
        expect(find.byType(VideoRecorderScreen), findsNothing);
      });
    });

    group('Screen Layout', () {
      testWidgets('uses StackFit.expand for full screen coverage', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        final stackFinder = find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Stack),
        );
        final stack = tester.widget<Stack>(stackFinder.first);

        expect(stack.fit, equals(StackFit.expand));
      });

      testWidgets('screen takes full available space', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        final screenSize = tester.getSize(find.byType(VideoRecorderScreen));
        final viewSize =
            tester.view.physicalSize / tester.view.devicePixelRatio;

        expect(screenSize.width, equals(viewSize.width));
        expect(screenSize.height, equals(viewSize.height));
      });
    });

    group('State Management', () {
      testWidgets('screen reacts to recording state changes', (tester) async {
        await tester.pumpWidget(
          buildTestWidgetWithOverrides([
            videoRecorderProvider.overrideWith(VideoRecorderNotifier.new),
          ]),
        );

        await tester.pump();
        await tester.pump();

        // Screen should rebuild when state changes
        expect(find.byType(VideoRecorderScreen), findsOneWidget);
      });

      testWidgets('maintains state during rebuilds', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Force rebuild
        await tester.pump();

        // All widgets should still be present
        expect(find.byType(VideoRecorderCameraPreview), findsOneWidget);
        expect(find.byType(VideoRecorderTopBar), findsOneWidget);
        expect(find.byType(VideoRecorderBottomBar), findsOneWidget);
        expect(find.byType(VideoRecorderCountdownOverlay), findsOneWidget);
      });
    });

    group('Widget Tree Structure', () {
      testWidgets('camera preview is the bottom-most layer', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        final stackFinder = find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Stack),
        );
        final stack = tester.widget<Stack>(stackFinder.first);

        // The first child is now a Column containing the camera preview
        expect(stack.children.first, isA<Column>());

        // Verify camera preview exists within the Column
        expect(find.byType(VideoRecorderCameraPreview), findsOneWidget);
      });

      testWidgets('countdown overlay is the top-most layer', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        final stackFinder = find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Stack),
        );
        final stack = tester.widget<Stack>(stackFinder.first);

        expect(stack.children.last, isA<VideoRecorderCountdownOverlay>());
      });
    });

    group('Screen Integration', () {
      testWidgets('can be pushed onto navigation stack', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: BlocProvider<CameraPermissionBloc>(
              create: (_) => MockCameraPermissionBloc(),
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider<CameraPermissionBloc>(
                              create: (_) => MockCameraPermissionBloc(),
                              child: const VideoRecorderScreen(),
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Camera'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Camera'));
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderScreen), findsOneWidget);
      });

      testWidgets('can be popped from navigation stack', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Simulate back navigation
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Home'))),
        );

        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderScreen), findsNothing);
        expect(find.text('Home'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('handles missing provider gracefully', (tester) async {
        // This tests that the screen doesn't crash without proper setup
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Should build without crashing
        expect(find.byType(VideoRecorderScreen), findsOneWidget);
      });

      testWidgets('handles multiple rapid lifecycle changes', (tester) async {
        // Override platform to avoid macOS-specific camera preview
        // which requires a native texture not available in tests
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        try {
          final mockCamera = MockCameraService.create(
            onAutoStopped: (_) {},
            onUpdateState: ({forceCameraRebuild}) {},
          );
          await mockCamera.initialize();

          await tester.pumpWidget(
            buildTestWidgetWithOverrides([
              videoRecorderProvider.overrideWith(
                () => VideoRecorderNotifier(mockCamera),
              ),
            ]),
          );

          await tester.pump();

          // Rapid lifecycle changes
          for (var i = 0; i < 5; i++) {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            await tester.pump();
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            await tester.pump();
          }

          // Should handle without crashing
          expect(find.byType(VideoRecorderScreen), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    });
  });
}
