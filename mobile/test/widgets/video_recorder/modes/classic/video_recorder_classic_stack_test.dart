import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_bottom.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_top.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_top_bar.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const VideoRecorderRecordingStopRequested());
  });

  group(VideoRecorderClassicStack, () {
    late _MockVideoRecorderBloc recorderBloc;

    setUp(() {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    });

    Widget buildWidget({
      VideoRecorderState recordingState = VideoRecorderState.idle,
      List<DivineVideoClip>? clips,
    }) {
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recordingState: recordingState,
          isCameraInitialized: true,
          canRecord: true,
        ),
      );

      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => _TestClipManagerNotifier(clips: clips ?? []),
          ),
        ],
        child: BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoRecorderClassicStack()),
          ),
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
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.longPress(
          find.ancestor(
            of: find.byType(VideoRecorderCameraPreview),
            matching: find.byType(GestureDetector),
          ),
        );
        await tester.pumpAndSettle();

        verify(
          () => recorderBloc.add(
            const VideoRecorderRecordingStartRequested(),
          ),
        ).called(1);
      });

      testWidgets('long press release on preview calls stopRecording', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.longPress(
          find.ancestor(
            of: find.byType(VideoRecorderCameraPreview),
            matching: find.byType(GestureDetector),
          ),
        );
        await tester.pumpAndSettle();

        verify(
          () => recorderBloc.add(
            const VideoRecorderRecordingStopRequested(),
          ),
        ).called(1);
      });
    });

    // Regression tests for issue #4409 ("Phantom click"): an incidental
    // long-touch on the preview shutter while a tap-started recording is
    // in progress must NOT call stopRecording on release.
    group('phantom click regression (issue #4409)', () {
      testWidgets(
        'long-press release does not stop a tap-started recording',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(recordingState: VideoRecorderState.recording),
          );
          await tester.pumpAndSettle();

          final gesture = await tester.startGesture(
            tester.getCenter(
              find.ancestor(
                of: find.byType(VideoRecorderCameraPreview),
                matching: find.byType(GestureDetector),
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          await gesture.up();
          await tester.pumpAndSettle();

          verifyNever(
            () => recorderBloc.add(
              const VideoRecorderRecordingStopRequested(),
            ),
          );
          verifyNever(
            () => recorderBloc.add(
              const VideoRecorderRecordingStartRequested(),
            ),
          );
        },
      );
    });
  });
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
