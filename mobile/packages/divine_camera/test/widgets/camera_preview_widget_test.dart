import 'package:divine_camera/divine_camera.dart';
import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDivineCameraPlatform
    with MockPlatformInterfaceMixin
    implements DivineCameraPlatform {
  CameraState _state = const CameraState();
  void Function(VideoRecordingResult result)? _onRecordingAutoStopped;

  @override
  void Function(VideoRecordingResult result)? get onRecordingAutoStopped =>
      _onRecordingAutoStopped;

  @override
  set onRecordingAutoStopped(
    void Function(VideoRecordingResult result)? callback,
  ) {
    _onRecordingAutoStopped = callback;
  }

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
  }) async {
    return _state = CameraState(
      isInitialized: true,
      lens: lens,
      hasFlash: true,
      hasFrontCamera: true,
      hasBackCamera: true,
      maxZoomLevel: 10,
      textureId: 1,
      isFocusPointSupported: true,
      isExposurePointSupported: true,
    );
  }

  @override
  Future<void> disposeCamera() async {
    _state = const CameraState();
  }

  @override
  Future<bool> setFlashMode(DivineCameraFlashMode mode) async => true;

  @override
  Future<bool> setFocusPoint(Offset offset) async => true;

  @override
  Future<bool> setExposurePoint(Offset offset) async => true;

  @override
  Future<bool> setZoomLevel(double level) async => true;

  @override
  Future<CameraState> switchCamera(DivineCameraLens lens) async {
    return _state = _state.copyWith(lens: lens);
  }

  @override
  Future<void> startRecording({Duration? maxDuration}) async {}

  @override
  Future<VideoRecordingResult?> stopRecording() async => null;

  @override
  Future<void> pausePreview() async {}

  @override
  Future<void> resumePreview() async {}

  @override
  Future<CameraState> getCameraState() async => _state;

  @override
  Widget buildPreview(int textureId) => Container(
    key: Key('texture_$textureId'),
    color: Colors.blue,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDivineCameraPlatform mockPlatform;

  setUp(() async {
    mockPlatform = MockDivineCameraPlatform();
    DivineCameraPlatform.instance = mockPlatform;
    // Reset singleton state
    await DivineCamera.instance.dispose();
  });

  final camera = DivineCamera.instance;

  Widget buildTestWidget({
    BoxFit fit = BoxFit.contain,
    void Function(Offset, Offset)? onTap,
    Widget? loadingWidget,
    Widget Function(Offset)? focusIndicatorBuilder,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 800,
          child: CameraPreviewWidget(
            fit: fit,
            onTap: onTap,
            loadingWidget: loadingWidget,
            focusIndicatorBuilder: focusIndicatorBuilder,
          ),
        ),
      ),
    );
  }

  group('CameraPreviewWidget', () {
    testWidgets('shows loading widget when camera is not initialized', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Should show default loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows custom loading widget when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          loadingWidget: const Text('Loading...'),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows Texture when camera is initialized', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(Texture), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('displays preview with correct aspect ratio', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget());

      // Find AspectRatio widget (used in contain mode)
      expect(find.byType(AspectRatio), findsOneWidget);
    });

    testWidgets('uses FittedBox for BoxFit.cover mode', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget(fit: BoxFit.cover));

      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('calls onTap callback with correct positions', (tester) async {
      await camera.initialize();

      Offset? receivedLocalPosition;
      Offset? receivedNormalizedPosition;

      await tester.pumpWidget(
        buildTestWidget(
          onTap: (local, normalized) {
            receivedLocalPosition = local;
            receivedNormalizedPosition = normalized;
          },
        ),
      );

      // Tap on the preview
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(receivedLocalPosition, isNotNull);
      expect(receivedNormalizedPosition, isNotNull);

      // Normalized position should be between 0 and 1
      expect(receivedNormalizedPosition!.dx, inInclusiveRange(0.0, 1.0));
      expect(receivedNormalizedPosition!.dy, inInclusiveRange(0.0, 1.0));
    });

    testWidgets(
      'shows focus indicator when focusIndicatorBuilder is provided',
      (tester) async {
        await camera.initialize();

        await tester.pumpWidget(
          buildTestWidget(
            onTap: (_, _) {},
            focusIndicatorBuilder: (position) => Positioned(
              left: position.dx - 25,
              top: position.dy - 25,
              child: Container(
                key: const Key('focus_indicator'),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.yellow, width: 2),
                ),
              ),
            ),
          ),
        );

        // Initially no focus indicator
        expect(find.byKey(const Key('focus_indicator')), findsNothing);

        // Tap to trigger focus indicator
        await tester.tap(find.byType(GestureDetector));
        await tester.pump();

        // Focus indicator should now be visible
        expect(find.byKey(const Key('focus_indicator')), findsOneWidget);
      },
    );

    testWidgets('does not show focus indicator without builder', (
      tester,
    ) async {
      await camera.initialize();

      await tester.pumpWidget(
        buildTestWidget(
          onTap: (_, _) {},
          // No focusIndicatorBuilder
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      // Should not find any positioned widgets for focus
      expect(find.byType(Positioned), findsNothing);
    });

    testWidgets('handles tap at center of preview', (tester) async {
      await camera.initialize();

      Offset? normalizedPosition;

      await tester.pumpWidget(
        buildTestWidget(
          onTap: (_, normalized) {
            normalizedPosition = normalized;
          },
        ),
      );

      // Get the center of the GestureDetector
      final gesture = find.byType(GestureDetector);
      final center = tester.getCenter(gesture);

      await tester.tapAt(center);
      await tester.pump();

      expect(normalizedPosition, isNotNull);
      // Center tap should be around 0.5, 0.5 (with some tolerance for
      //aspect ratio)
      expect(normalizedPosition!.dx, closeTo(0.5, 0.2));
      expect(normalizedPosition!.dy, closeTo(0.5, 0.2));
    });

    testWidgets('handles tap at corner of preview', (tester) async {
      await camera.initialize();

      Offset? normalizedPosition;

      await tester.pumpWidget(
        buildTestWidget(
          onTap: (_, normalized) {
            normalizedPosition = normalized;
          },
        ),
      );

      // Get the top-left corner of the GestureDetector
      final gesture = find.byType(GestureDetector);
      final topLeft = tester.getTopLeft(gesture);

      await tester.tapAt(topLeft);
      await tester.pump();

      expect(normalizedPosition, isNotNull);
      // Top-left should be close to 0, 0
      expect(normalizedPosition!.dx, closeTo(0.0, 0.1));
      expect(normalizedPosition!.dy, closeTo(0.0, 0.1));
    });

    testWidgets('rebuilds when camera state changes', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Initially loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Initialize camera
      await camera.initialize();
      // Rebuild widget with initialized camera
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Now shows texture
      expect(find.byType(Texture), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('wraps preview in GestureDetector', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('uses LayoutBuilder for responsive sizing', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets('uses Stack for layering focus indicator', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(
        buildTestWidget(
          focusIndicatorBuilder: (_) => const SizedBox(),
        ),
      );

      // Find Stack inside CameraPreviewWidget (there may be other Stacks in
      // Scaffold)
      expect(find.byType(Stack), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(CameraPreviewWidget),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );
    });
  });
}
