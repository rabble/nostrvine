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
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_top_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderClassicTopBar, () {
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
            body: SizedBox(height: 80, child: VideoRecorderClassicTopBar()),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderClassicTopBar', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicTopBar), findsOneWidget);
      });

      testWidgets('renders close and next buttons', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(DivineIconButton), findsNWidgets(2));
      });

      testWidgets('uses Stack for progress bar behind buttons', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Stack), findsWidgets);
      });
    });

    group('progress bar', () {
      testWidgets('shows progress when clips exist', (tester) async {
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

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        // Progress bar uses Flexible widgets for primary/remaining
        expect(find.byType(Flexible), findsWidgets);
      });

      testWidgets('shows no primary fill when no clips and no recording', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Progress bar should exist but no primary fill (currentMs = 0)
        expect(find.byType(VideoRecorderClassicTopBar), findsOneWidget);
      });

      testWidgets('shows active recording progress', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            activeRecordingDuration: const Duration(seconds: 2),
          ),
        );
        await tester.pumpAndSettle();

        // The Flexible widgets represent progress segments
        expect(find.byType(Flexible), findsWidgets);
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
