import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show ProVideoController;
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

void main() {
  testWidgets('VideoEditorCanvas renders safely with no clips', (tester) async {
    final bodySizeNotifier = ValueNotifier(Size.zero);
    addTearDown(bodySizeNotifier.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => VideoEditorMainBloc()),
              BlocProvider(create: (_) => VideoEditorDrawBloc()),
              BlocProvider(create: (_) => VideoEditorFilterBloc()),
            ],
            child: VideoEditorScope(
              editorKey: GlobalKey(),
              removeAreaKey: GlobalKey(),
              onOpenCamera: () {},
              onAddStickers: () {},
              onOpenClipsEditor: () {},
              onOpenMusicLibrary: () {},
              onAddEditTextLayer: ([_]) async => null,
              originalClipAspectRatio: 9 / 16,
              bodySizeNotifier: bodySizeNotifier,
              zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
              fromLibrary: false,
              child: const Scaffold(body: VideoEditorCanvas()),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  group('VideoEditorCanvas.syncPositionAfterTrimRelease', () {
    late _SpyVideoEditorMainBloc mainBloc;
    late ProVideoController controller;

    setUp(() {
      mainBloc = _SpyVideoEditorMainBloc();
      controller = ProVideoController(
        videoPlayer: const SizedBox.shrink(),
        videoDuration: Duration.zero,
        initialResolution: Size.zero,
        fileSize: 0,
      );
    });

    tearDown(() async {
      await mainBloc.close();
    });

    test(
      'dispatches VideoEditorPositionChanged(startPosition) and updates '
      'playTime when the trim-end position was not pre-dispatched',
      () {
        const startPosition = Duration(seconds: 2);

        VideoEditorCanvas.syncPositionAfterTrimRelease(
          mainBloc: mainBloc,
          proVideoController: controller,
          startPosition: startPosition,
          trimEndAlreadyDispatched: false,
        );

        expect(
          mainBloc.events,
          contains(
            isA<VideoEditorPositionChanged>().having(
              (e) => e.position,
              'position',
              startPosition,
            ),
          ),
        );
        expect(controller.playTimeNotifier.value, equals(startPosition));
      },
    );

    test(
      'skips the bloc dispatch but still updates playTime when the '
      'trim-end position was already pushed pre-await',
      () {
        const startPosition = Duration(milliseconds: 1500);

        VideoEditorCanvas.syncPositionAfterTrimRelease(
          mainBloc: mainBloc,
          proVideoController: controller,
          startPosition: startPosition,
          trimEndAlreadyDispatched: true,
        );

        expect(
          mainBloc.events.whereType<VideoEditorPositionChanged>(),
          isEmpty,
        );
        expect(controller.playTimeNotifier.value, equals(startPosition));
      },
    );
  });

  group('VideoEditorCanvas.shouldSeedSelectedSoundAsAudioTrack', () {
    test('requires both a selected sound and recorder handoff flag', () {
      expect(
        VideoEditorCanvas.shouldSeedSelectedSoundAsAudioTrack(
          hasSelectedSound: true,
          seedSelectedSoundAsAudioTrack: true,
        ),
        isTrue,
      );
      expect(
        VideoEditorCanvas.shouldSeedSelectedSoundAsAudioTrack(
          hasSelectedSound: true,
          seedSelectedSoundAsAudioTrack: false,
        ),
        isFalse,
      );
      expect(
        VideoEditorCanvas.shouldSeedSelectedSoundAsAudioTrack(
          hasSelectedSound: false,
          seedSelectedSoundAsAudioTrack: true,
        ),
        isFalse,
      );
    });
  });

  group('VideoEditorCanvas.shouldSyncPlayerForClipStateChange', () {
    test('skips split render intermediate clip updates', () {
      final source = _createClip(id: 'source');
      final start = _createClip(id: 'start');
      final previewEnd = _createClip(id: 'end');

      final previous = ClipEditorState(
        clips: [source],
        isSplitting: true,
      );
      final current = ClipEditorState(
        clips: [start, previewEnd],
        isSplitting: true,
      );

      expect(
        VideoEditorCanvas.shouldSyncPlayerForClipStateChange(
          previous: previous,
          current: current,
        ),
        isFalse,
      );
    });

    test('syncs once when split rendering finishes', () {
      final start = _createClip(id: 'start');
      final end = _createClip(id: 'end');
      final clips = [start, end];

      final previous = ClipEditorState(clips: clips, isSplitting: true);
      final current = ClipEditorState(clips: clips);

      expect(
        VideoEditorCanvas.shouldSyncPlayerForClipStateChange(
          previous: previous,
          current: current,
        ),
        isTrue,
      );
    });

    test('keeps syncing ordinary non-trim clip changes', () {
      final source = _createClip(id: 'source');
      final copy = _createClip(id: 'copy');

      expect(
        VideoEditorCanvas.shouldSyncPlayerForClipStateChange(
          previous: ClipEditorState(clips: [source]),
          current: ClipEditorState(clips: [source, copy]),
        ),
        isTrue,
      );
    });
  });

  group('interpolatePlayheadPosition', () {
    const maxDuration = Duration(seconds: 10);

    test('advances from the anchor by the elapsed wall-clock at 1x', () {
      expect(
        interpolatePlayheadPosition(
          anchor: const Duration(seconds: 2),
          elapsed: const Duration(milliseconds: 100),
          speed: 1,
          maxDuration: maxDuration,
        ),
        const Duration(milliseconds: 2100),
      );
    });

    test('scales the elapsed by the playback speed', () {
      expect(
        interpolatePlayheadPosition(
          anchor: const Duration(seconds: 1),
          elapsed: const Duration(milliseconds: 200),
          speed: 2,
          maxDuration: maxDuration,
        ),
        const Duration(milliseconds: 1400),
      );
    });

    test('clamps to the max duration past the end', () {
      expect(
        interpolatePlayheadPosition(
          anchor: const Duration(seconds: 9, milliseconds: 950),
          elapsed: const Duration(milliseconds: 200),
          speed: 1,
          maxDuration: maxDuration,
        ),
        maxDuration,
      );
    });

    test('never returns a negative position', () {
      expect(
        interpolatePlayheadPosition(
          anchor: Duration.zero,
          elapsed: const Duration(milliseconds: 100),
          speed: -1,
          maxDuration: maxDuration,
        ),
        Duration.zero,
      );
    });
  });
}

DivineVideoClip _createClip({required String id}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/test/$id.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );
}

/// Captures every event added to the bloc so tests can assert
/// dispatches that don't change the resulting state value (and would
/// therefore not appear on `bloc.stream`).
class _SpyVideoEditorMainBloc extends VideoEditorMainBloc {
  final List<VideoEditorMainEvent> events = [];

  @override
  void add(VideoEditorMainEvent event) {
    events.add(event);
    super.add(event);
  }
}
