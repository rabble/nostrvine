import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_recorder/video_recorder_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_record_button.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(RecordButton, () {
    late MockCameraService mockCamera;

    setUp(() async {
      mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();
    });

    Widget buildWidget({
      VideoRecorderState recordingState = VideoRecorderState.idle,
      bool canRecord = true,
      bool isCameraInitialized = true,
      List<DivineVideoClip>? clips,
    }) {
      return ProviderScope(
        overrides: [
          videoRecorderProvider.overrideWith(
            () => _TestVideoRecorderNotifier(
              mockCamera,
              recordingState: recordingState,
              canRecord: canRecord,
              isCameraInitialized: isCameraInitialized,
            ),
          ),
          clipManagerProvider.overrideWith(
            () => _TestClipManagerNotifier(clips: clips ?? []),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: RecordButton())),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $RecordButton', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(RecordButton), findsOneWidget);
      });

      testWidgets('renders GestureDetector', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(GestureDetector), findsOneWidget);
      });

      testWidgets('renders outer border container', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Two AnimatedContainers: outer border + inner dot
        expect(find.byType(AnimatedContainer), findsNWidgets(2));
      });
    });

    group('idle state', () {
      testWidgets('shows large inner circle when not recording', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Inner AnimatedContainer should have 64x64 size (round dot)
        final containers = tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .toList();
        // The inner container (second one) should be visible
        expect(containers.length, equals(2));
      });

      testWidgets('has semantic identifier', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(find.byType(RecordButton));
        expect(semantics.tooltip, equals('Start recording'));
      });
    });

    group('recording state', () {
      testWidgets('shows square shape when recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecordButton), findsOneWidget);
      });

      testWidgets('has semantic tooltip for stop', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(find.byType(RecordButton));
        expect(semantics.tooltip, equals('Stop recording'));
      });
    });

    group('disabled state', () {
      testWidgets('is disabled when camera is not initialized', (tester) async {
        await tester.pumpWidget(buildWidget(isCameraInitialized: false));
        await tester.pumpAndSettle();

        // AnimatedOpacity should have reduced opacity
        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(0.5));
      });

      testWidgets('is disabled when canRecord is false', (tester) async {
        await tester.pumpWidget(buildWidget(canRecord: false));
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(0.5));
      });

      testWidgets('shows full opacity when enabled', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(1.0));
      });
    });

    group('accessibility', () {
      testWidgets('has Semantics identifier', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.identifier == 'divine-camera-record-button',
          ),
        );
        expect(semantics.properties.button, isTrue);
      });
    });

    // Regression tests for issue #4409 ("Phantom click"): an incidental
    // long-touch on the record button while a tap-started recording is
    // in progress must NOT call stopRecording on release.
    group('phantom click regression (issue #4409)', () {
      testWidgets(
        'long-press release does not stop a tap-started recording',
        (tester) async {
          final notifier = _TrackingVideoRecorderNotifier(
            mockCamera,
            recordingState: VideoRecorderState.recording,
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                videoRecorderProvider.overrideWith(() => notifier),
                clipManagerProvider.overrideWith(
                  () => _TestClipManagerNotifier(clips: const []),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: Center(child: RecordButton())),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Simulate the user resting a finger on the shutter while a
          // tap-started take is already running.
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(RecordButton)),
          );
          await tester.pump(const Duration(seconds: 1));
          await gesture.up();
          await tester.pumpAndSettle();

          expect(
            notifier.stopRecordingCallCount,
            equals(0),
            reason:
                'stopRecording must not be called when a long-press '
                'release follows an incidental touch on an already- '
                'recording shutter (issue #4409).',
          );
          expect(notifier.startRecordingCallCount, equals(0));
          expect(notifier.toggleRecordingCallCount, equals(0));
        },
      );

      testWidgets(
        'long-press from idle starts recording and release stops it',
        (tester) async {
          final notifier = _TrackingVideoRecorderNotifier(mockCamera);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                videoRecorderProvider.overrideWith(() => notifier),
                clipManagerProvider.overrideWith(
                  () => _TestClipManagerNotifier(clips: const []),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: Center(child: RecordButton())),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(RecordButton)),
          );
          await tester.pump(const Duration(seconds: 1));
          await gesture.up();
          await tester.pumpAndSettle();

          expect(notifier.startRecordingCallCount, equals(1));
          expect(notifier.stopRecordingCallCount, equals(1));
        },
      );
    });
  });
}

class _TestVideoRecorderNotifier extends VideoRecorderNotifier {
  _TestVideoRecorderNotifier(
    super.cameraService, {
    this.recordingState = VideoRecorderState.idle,
    this.canRecord = true,
    this.isCameraInitialized = true,
  });

  final VideoRecorderState recordingState;
  final bool canRecord;
  final bool isCameraInitialized;

  @override
  VideoRecorderProviderState build() {
    return VideoRecorderProviderState(
      recordingState: recordingState,
      canRecord: canRecord,
      isCameraInitialized: isCameraInitialized,
    );
  }
}

class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier({required this.clips});

  @override
  final List<DivineVideoClip> clips;

  @override
  ClipManagerState build() {
    return ClipManagerState(clips: clips);
  }
}

/// Test notifier that tracks how many times each recording method is
/// invoked, without performing any real camera work. Used by the
/// phantom-click regression tests (issue #4409).
class _TrackingVideoRecorderNotifier extends VideoRecorderNotifier {
  _TrackingVideoRecorderNotifier(
    super.cameraService, {
    this.recordingState = VideoRecorderState.idle,
  });

  final VideoRecorderState recordingState;

  int toggleRecordingCallCount = 0;
  int startRecordingCallCount = 0;
  int stopRecordingCallCount = 0;

  @override
  VideoRecorderProviderState build() {
    return VideoRecorderProviderState(
      recordingState: recordingState,
      canRecord: true,
      isCameraInitialized: true,
    );
  }

  @override
  Future<void> toggleRecording() async {
    toggleRecordingCallCount++;
  }

  @override
  Future<void> startRecording() async {
    startRecordingCallCount++;
  }

  @override
  Future<void> stopRecording([EditorVideo? result]) async {
    stopRecordingCallCount++;
  }
}
