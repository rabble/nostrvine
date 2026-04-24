import 'package:divine_ui/divine_ui.dart';
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
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_top_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderCaptureTopBar, () {
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
      List<DivineVideoClip>? clips,
      Duration activeRecordingDuration = Duration.zero,
    }) {
      return ProviderScope(
        overrides: [
          videoRecorderProvider.overrideWith(
            () => _TestVideoRecorderNotifier(
              mockCamera,
              recordingState: recordingState,
            ),
          ),
          clipManagerProvider.overrideWith(
            () => _TestClipManagerNotifier(
              clips: clips ?? [],
              activeRecordingDuration: activeRecordingDuration,
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoRecorderCaptureTopBar(fromEditor: false),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderCaptureTopBar', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderCaptureTopBar), findsOneWidget);
      });

      testWidgets('uses AnimatedSwitcher', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSwitcher), findsOneWidget);
      });
    });

    group('idle state', () {
      testWidgets('shows close and next buttons when not recording', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(DivineIconButton), findsNWidgets(2));
      });

      testWidgets('close button has Semantics label', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Close'), findsOneWidget);
      });

      testWidgets('next button is hidden when no clips exist', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Next button wrapped in AnimatedOpacity with opacity 0
        final opacities = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .toList();
        // Find the one with opacity 0 (no clips -> next is hidden)
        expect(
          opacities.any((o) => o.opacity == 0),
          isTrue,
        );
      });

      testWidgets('next button is visible when clips exist', (tester) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        // AnimatedOpacity around next button should have opacity 1
        final opacities = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .toList();
        expect(
          opacities.any((o) => o.opacity == 1),
          isTrue,
        );
      });
    });

    group('recording state', () {
      testWidgets('shows progress bar when recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        // Pump a few frames for AnimatedSwitcher
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The progress bar uses Flexible widgets for segments
        expect(find.byType(Flexible), findsWidgets);
      });

      testWidgets('shows time display when recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            activeRecordingDuration: const Duration(seconds: 2),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Time text should be shown (e.g. "00:02")
        expect(find.textContaining('00:02'), findsOneWidget);
      });

      testWidgets('shows progress with existing clips', (tester) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ];

        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            clips: clips,
            activeRecordingDuration: const Duration(seconds: 1),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Should show combined duration 3s + 1s = "00:04"
        expect(find.textContaining('00:04'), findsOneWidget);
      });
    });
  });
}

class _TestVideoRecorderNotifier extends VideoRecorderNotifier {
  _TestVideoRecorderNotifier(
    super.cameraService, {
    this.recordingState = VideoRecorderState.idle,
  });

  final VideoRecorderState recordingState;

  @override
  VideoRecorderProviderState build() {
    return VideoRecorderProviderState(
      recordingState: recordingState,
      isCameraInitialized: true,
      canRecord: true,
    );
  }
}

class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier({
    required this.clips,
    required this.activeRecordingDuration,
  });

  @override
  final List<DivineVideoClip> clips;
  final Duration activeRecordingDuration;

  @override
  ClipManagerState build() {
    return ClipManagerState(
      clips: clips,
      activeRecordingDuration: activeRecordingDuration,
    );
  }
}
