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
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_bottom.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_top.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_top_bar.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderClassicStack, () {
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
          home: Scaffold(body: VideoRecorderClassicStack()),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderClassicStack', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicStack), findsOneWidget);
      });

      testWidgets('renders $VideoRecorderClassicTopBar', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicTopBar), findsOneWidget);
      });

      testWidgets('renders $VideoRecorderCameraPreview', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderCameraPreview), findsOneWidget);
      });

      testWidgets('renders $VideoRecorderClassicActionsTop', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicActionsTop), findsOneWidget);
      });

      testWidgets('renders $VideoRecorderClassicActionsBottom', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicActionsBottom), findsOneWidget);
      });
    });

    group('layout', () {
      testWidgets('uses SafeArea', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(SafeArea), findsWidgets);
      });

      testWidgets('uses Column layout', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Column), findsWidgets);
      });

      testWidgets('shows 1:1 aspect ratio preview', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Should find an AspectRatio widget with ratio 1
        final aspectRatioWidgets = tester.widgetList<AspectRatio>(
          find.byType(AspectRatio),
        );
        expect(aspectRatioWidgets.any((w) => w.aspectRatio == 1.0), isTrue);
      });
    });

    group('interactions', () {
      testWidgets('wraps preview in GestureDetector for tap-to-record', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(GestureDetector), findsWidgets);
      });

      testWidgets('has Semantics for recording state', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.videoRecorderTapToStartLabel),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            lookupAppLocalizations(
              const Locale('de'),
            ).videoRecorderTapToStartLabel,
          ),
          findsNothing,
        );
      });

      testWidgets('has Semantics for recording active', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.videoRecorderRecordingTapToStopLabel),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            lookupAppLocalizations(
              const Locale('de'),
            ).videoRecorderRecordingTapToStopLabel,
          ),
          findsNothing,
        );
      });
    });

    group('long press', () {
      testWidgets('long press on preview calls startRecording', (tester) async {
        late _TestVideoRecorderNotifier notifier;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              videoRecorderProvider.overrideWith(() {
                notifier = _TestVideoRecorderNotifier(mockCamera);
                return notifier;
              }),
              clipManagerProvider.overrideWith(
                () => _TestClipManagerNotifier(clips: []),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoRecorderClassicStack()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(
          find.ancestor(
            of: find.byType(VideoRecorderCameraPreview),
            matching: find.byType(GestureDetector),
          ),
        );
        await tester.pumpAndSettle();

        expect(notifier.startRecordingCalled, isTrue);
      });

      testWidgets('long press release on preview calls stopRecording', (
        tester,
      ) async {
        late _TestVideoRecorderNotifier notifier;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              videoRecorderProvider.overrideWith(() {
                notifier = _TestVideoRecorderNotifier(mockCamera);
                return notifier;
              }),
              clipManagerProvider.overrideWith(
                () => _TestClipManagerNotifier(clips: []),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoRecorderClassicStack()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(
          find.ancestor(
            of: find.byType(VideoRecorderCameraPreview),
            matching: find.byType(GestureDetector),
          ),
        );
        await tester.pumpAndSettle();

        expect(notifier.stopRecordingCalled, isTrue);
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

  var startRecordingCalled = false;
  var stopRecordingCalled = false;

  @override
  VideoRecorderProviderState build() {
    return VideoRecorderProviderState(
      recordingState: recordingState,
      isCameraInitialized: true,
      canRecord: true,
    );
  }

  @override
  Future<void> startRecording() async {
    startRecordingCalled = true;
  }

  @override
  Future<void> stopRecording([EditorVideo? result]) async {
    stopRecordingCalled = true;
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
