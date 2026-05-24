import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
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

    test('dispatches VideoEditorPositionChanged(startPosition) and updates '
        'playTime when the trim-end position was not pre-dispatched', () {
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
    });

    test('skips the bloc dispatch but still updates playTime when the '
        'trim-end position was already pushed pre-await', () {
      const startPosition = Duration(milliseconds: 1500);

      VideoEditorCanvas.syncPositionAfterTrimRelease(
        mainBloc: mainBloc,
        proVideoController: controller,
        startPosition: startPosition,
        trimEndAlreadyDispatched: true,
      );

      expect(mainBloc.events.whereType<VideoEditorPositionChanged>(), isEmpty);
      expect(controller.playTimeNotifier.value, equals(startPosition));
    });
  });

  group('VideoEditorCanvas.remapPlaybackPositionForClipUpdate', () {
    test('preserves the same frame when a single clip is sped up', () {
      final previousClips = [
        _createClip(duration: const Duration(seconds: 4), playbackSpeed: 1.0),
      ];
      final currentClips = [
        _createClip(duration: const Duration(seconds: 4), playbackSpeed: 2.0),
      ];

      final remapped = VideoEditorCanvas.remapPlaybackPositionForClipUpdate(
        previousClips: previousClips,
        currentClips: currentClips,
        currentPosition: const Duration(seconds: 3),
      );

      expect(remapped, const Duration(milliseconds: 1500));
    });

    test(
      'preserves the active clip frame when an earlier clip changes speed',
      () {
        final previousClips = [
          _createClip(id: 'a', duration: const Duration(seconds: 4)),
          _createClip(id: 'b', duration: const Duration(seconds: 4)),
        ];
        final currentClips = [
          _createClip(
            id: 'a',
            duration: const Duration(seconds: 4),
            playbackSpeed: 2.0,
          ),
          _createClip(id: 'b', duration: const Duration(seconds: 4)),
        ];

        final remapped = VideoEditorCanvas.remapPlaybackPositionForClipUpdate(
          previousClips: previousClips,
          currentClips: currentClips,
          currentPosition: const Duration(seconds: 5),
        );

        expect(remapped, const Duration(seconds: 3));
      },
    );

    test('clamps to the new composition duration when the clip disappears', () {
      final previousClips = [
        _createClip(id: 'a', duration: const Duration(seconds: 6)),
        _createClip(id: 'b', duration: const Duration(seconds: 4)),
      ];
      final currentClips = [
        _createClip(id: 'b', duration: const Duration(seconds: 4)),
      ];

      final remapped = VideoEditorCanvas.remapPlaybackPositionForClipUpdate(
        previousClips: previousClips,
        currentClips: currentClips,
        currentPosition: const Duration(seconds: 5),
      );

      expect(remapped, const Duration(seconds: 4));
    });
  });
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

DivineVideoClip _createClip({
  required Duration duration,
  String id = 'clip',
  double? playbackSpeed,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/tmp/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2026),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: model.AspectRatio.vertical,
    playbackSpeed: playbackSpeed,
  );
}
