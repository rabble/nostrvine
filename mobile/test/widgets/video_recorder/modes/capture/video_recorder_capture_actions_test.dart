import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_actions.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderCaptureActions, () {
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
      DivineFlashMode flashMode = DivineFlashMode.auto,
      bool canSwitchCamera = true,
      bool hasFlash = true,
      List<DivineVideoClip>? clips,
    }) {
      return ProviderScope(
        overrides: [
          videoRecorderProvider.overrideWith(
            () => _TestVideoRecorderNotifier(
              mockCamera,
              recordingState: recordingState,
              flashMode: flashMode,
              canSwitchCamera: canSwitchCamera,
              hasFlash: hasFlash,
            ),
          ),
          clipManagerProvider.overrideWith(
            () => _TestClipManagerNotifier(clips: clips ?? []),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VideoRecorderCaptureActions()),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderCaptureActions', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderCaptureActions), findsOneWidget);
      });

      testWidgets('renders four action buttons', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Flash, timer, aspect ratio, switch camera
        expect(find.byType(InkWell), findsNWidgets(4));
      });

      testWidgets('renders Tooltip for each button', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Tooltip), findsNWidgets(4));
      });

      testWidgets('renders DivineIcon for each button', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(DivineIcon), findsNWidgets(4));
      });
    });

    group('visibility', () {
      testWidgets('is fully opaque when not recording', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(1));
      });

      testWidgets('fades out when recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(0));
      });
    });

    group('flash button', () {
      testWidgets('renders flash tooltip', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byTooltip('Toggle flash'), findsOneWidget);
      });

      testWidgets('flash button is disabled when hasFlash is false', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(hasFlash: false));
        await tester.pumpAndSettle();

        // Find the flash tooltip's InkWell — its onTap should be null
        final flashTooltip = find.byTooltip('Toggle flash');
        final inkWell = find.descendant(
          of: flashTooltip,
          matching: find.byType(InkWell),
        );
        final widget = tester.widget<InkWell>(inkWell);
        expect(widget.onTap, isNull);
      });
    });

    group('switch camera button', () {
      testWidgets('is disabled when canSwitchCamera is false', (tester) async {
        await tester.pumpWidget(buildWidget(canSwitchCamera: false));
        await tester.pumpAndSettle();

        final switchTooltip = find.byTooltip('Switch camera');
        final inkWell = find.descendant(
          of: switchTooltip,
          matching: find.byType(InkWell),
        );
        final widget = tester.widget<InkWell>(inkWell);
        expect(widget.onTap, isNull);
      });
    });

    group('aspect ratio button', () {
      testWidgets('is disabled when clips exist', (tester) async {
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

        final arTooltip = find.byTooltip('Toggle aspect ratio');
        final inkWell = find.descendant(
          of: arTooltip,
          matching: find.byType(InkWell),
        );
        final widget = tester.widget<InkWell>(inkWell);
        expect(widget.onTap, isNull);
      });

      testWidgets('is enabled when no clips exist', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final arTooltip = find.byTooltip('Toggle aspect ratio');
        final inkWell = find.descendant(
          of: arTooltip,
          matching: find.byType(InkWell),
        );
        final widget = tester.widget<InkWell>(inkWell);
        expect(widget.onTap, isNotNull);
      });
    });
  });
}

class _TestVideoRecorderNotifier extends VideoRecorderNotifier {
  _TestVideoRecorderNotifier(
    super.cameraService, {
    this.recordingState = VideoRecorderState.idle,
    this.flashMode = DivineFlashMode.auto,
    this.canSwitchCamera = true,
    this.hasFlash = true,
  });

  final VideoRecorderState recordingState;
  final DivineFlashMode flashMode;
  final bool canSwitchCamera;
  final bool hasFlash;

  @override
  VideoRecorderProviderState build() {
    return VideoRecorderProviderState(
      recordingState: recordingState,
      flashMode: flashMode,
      canSwitchCamera: canSwitchCamera,
      hasFlash: hasFlash,
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
