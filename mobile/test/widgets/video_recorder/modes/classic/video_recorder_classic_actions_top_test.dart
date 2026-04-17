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
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_top.dart';
import 'package:pro_video_editor/core/models/video/editor_video_model.dart';

import '../../../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderClassicActionsTop, () {
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
            () => _TestClipManagerNotifier(clips: clips ?? []),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoRecorderClassicActionsTop(),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderClassicActionsTop', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicActionsTop), findsOneWidget);
      });

      testWidgets('renders undo button', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(DivineIconButton), findsOneWidget);
      });
    });

    group('visibility', () {
      testWidgets('is hidden when no clips exist', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byType(Row),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        );
        // isRecording || !hasClips => true when no clips
        expect(opacity.opacity, equals(0));
      });

      testWidgets('is visible when clips exist and not recording', (
        tester,
      ) async {
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

        final opacity = tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byType(Row),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        );
        expect(opacity.opacity, equals(1));
      });

      testWidgets('is hidden during recording even with clips', (
        tester,
      ) async {
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

        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            clips: clips,
          ),
        );
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byType(Row),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        );
        expect(opacity.opacity, equals(0));
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
  _TestClipManagerNotifier({required this.clips});

  @override
  final List<DivineVideoClip> clips;

  @override
  ClipManagerState build() {
    return ClipManagerState(clips: clips);
  }
}
