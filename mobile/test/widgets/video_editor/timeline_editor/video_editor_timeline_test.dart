// ABOUTME: Widget tests for VideoEditorTimeline.
// ABOUTME: Validates timeline rendering, scroll content, playhead, and empty state.

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_header.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_playhead.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_rules_indicator.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockProVideoEditor extends ProVideoEditor {
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();

  @override
  Future<List<Uint8List>> getThumbnails(
    ThumbnailConfigs configs, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    return List.filled(configs.timestamps.length, Uint8List(0));
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    return VideoMetadata(
      duration: const Duration(seconds: 5),
      extension: 'mp4',
      fileSize: 1024000,
      resolution: const Size(1920, 1080),
      rotation: 0,
      bitrate: 3000000,
    );
  }
}

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _MockVideoEditorFilterBloc
    extends MockBloc<VideoEditorFilterEvent, VideoEditorFilterState>
    implements VideoEditorFilterBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorTimelineScaffold, () {
    late _MockVideoEditorMainBloc mockMainBloc;
    late _MockClipEditorBloc mockClipBloc;
    late _MockTimelineOverlayBloc mockOverlayBloc;
    late _MockVideoEditorFilterBloc mockFilterBloc;

    setUp(() {
      ProVideoEditor.instance = _MockProVideoEditor();

      mockMainBloc = _MockVideoEditorMainBloc();
      mockClipBloc = _MockClipEditorBloc();
      mockOverlayBloc = _MockTimelineOverlayBloc();
      mockFilterBloc = _MockVideoEditorFilterBloc();

      when(() => mockMainBloc.state).thenReturn(
        const VideoEditorMainState(),
      );
      when(() => mockMainBloc.stream).thenAnswer(
        (_) => const Stream<VideoEditorMainState>.empty(),
      );
      when(() => mockClipBloc.state).thenReturn(
        const ClipEditorState(),
      );
      when(() => mockClipBloc.stream).thenAnswer(
        (_) => const Stream<ClipEditorState>.empty(),
      );
      when(() => mockOverlayBloc.state).thenReturn(
        const TimelineOverlayState(),
      );
      when(() => mockOverlayBloc.stream).thenAnswer(
        (_) => const Stream<TimelineOverlayState>.empty(),
      );
      when(() => mockFilterBloc.state).thenReturn(
        const VideoEditorFilterState(filters: []),
      );
      when(() => mockFilterBloc.stream).thenAnswer(
        (_) => const Stream<VideoEditorFilterState>.empty(),
      );
    });

    Widget buildWidget({
      VideoEditorMainState? mainState,
      ClipEditorState? clipState,
    }) {
      if (mainState != null) {
        when(() => mockMainBloc.state).thenReturn(mainState);
      }
      if (clipState != null) {
        when(() => mockClipBloc.state).thenReturn(clipState);
      }

      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorScope(
              editorKey: GlobalKey<ProImageEditorState>(),
              removeAreaKey: GlobalKey(),
              originalClipAspectRatio: 9 / 16,
              bodySizeNotifier: ValueNotifier(const Size(400, 600)),
              fromLibrary: false,
              onOpenClipsEditor: () {},
              onAddStickers: () {},
              onAdjustVolume: () {},
              onOpenMusicLibrary: () {},
              onAddEditTextLayer: ([layer]) async => null,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<VideoEditorMainBloc>.value(
                    value: mockMainBloc,
                  ),
                  BlocProvider<ClipEditorBloc>.value(value: mockClipBloc),
                  BlocProvider<TimelineOverlayBloc>.value(
                    value: mockOverlayBloc,
                  ),
                  BlocProvider<VideoEditorFilterBloc>.value(
                    value: mockFilterBloc,
                  ),
                ],

                child: const VideoEditorTimelineScaffold(),
              ),
            ),
          ),
        ),
      );
    }

    group('empty state', () {
      testWidgets('renders $SizedBox when clips are empty', (tester) async {
        await tester.pumpWidget(
          buildWidget(clipState: const ClipEditorState()),
        );

        // Should shrink — no header, no strip, no playhead
        expect(find.byType(VideoEditorTimelineHeader), findsNothing);
        expect(
          find.byType(VideoEditorTimelineClipStrip),
          findsNothing,
        );
      });
    });

    group('renders', () {
      testWidgets('renders timeline with clips', (tester) async {
        final clips = [
          _createTestClip(id: 'clip1', seconds: 3),
          _createTestClip(id: 'clip2', seconds: 5),
        ];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(find.byType(VideoEditorTimelineScaffold), findsOneWidget);
      });

      testWidgets('renders $VideoEditorTimelineHeader', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(find.byType(VideoEditorTimelineHeader), findsOneWidget);
      });

      testWidgets('renders $VideoEditorTimelinePlayhead', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(find.byType(VideoEditorTimelinePlayhead), findsOneWidget);
      });

      testWidgets('renders $VideoEditorTimelineRulesIndicator', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(
          find.byType(VideoEditorTimelineRulesIndicator),
          findsOneWidget,
        );
      });

      testWidgets('renders $VideoEditorTimelineClipStrip', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(
          find.byType(VideoEditorTimelineClipStrip),
          findsOneWidget,
        );
      });

      testWidgets('does not show controls when not editing', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(find.text('Done'), findsNothing);
      });
    });

    group('playhead visibility', () {
      testWidgets('playhead is visible when not reordering', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(),
            clipState: ClipEditorState(clips: clips),
          ),
        );

        final opacity = tester.widget<AnimatedOpacity>(
          find.byWidgetPredicate(
            (widget) =>
                widget is AnimatedOpacity && widget.child is IgnorePointer,
          ),
        );
        expect(opacity.opacity, equals(1.0));
      });

      testWidgets('playhead is hidden when reordering', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(isReordering: true),
            clipState: ClipEditorState(clips: clips),
          ),
        );

        final opacity = tester.widget<AnimatedOpacity>(
          find.byWidgetPredicate(
            (widget) =>
                widget is AnimatedOpacity && widget.child is IgnorePointer,
          ),
        );
        expect(opacity.opacity, equals(0.0));
      });
    });

    group('ruler visibility', () {
      testWidgets('ruler fades out when reordering', (tester) async {
        final clips = [
          _createTestClip(id: 'a'),
          _createTestClip(id: 'b', seconds: 3),
        ];

        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(isReordering: true),
            clipState: ClipEditorState(clips: clips),
          ),
        );

        final opacity = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(VideoEditorTimelineRulesIndicator),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(opacity.opacity, equals(0.0));
      });

      testWidgets('ruler is visible when not reordering', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(),
            clipState: ClipEditorState(clips: clips),
          ),
        );

        final opacity = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(VideoEditorTimelineRulesIndicator),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(opacity.opacity, equals(1.0));
      });
    });

    group('accessibility', () {
      testWidgets('has Video timeline semantics label', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(
          find.bySemanticsLabel('Video timeline'),
          findsOneWidget,
        );
      });
    });

    group('scrollable content', () {
      testWidgets('uses horizontal SingleChildScrollView', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(
          find.byType(SingleChildScrollView),
          findsWidgets,
        );
      });
    });
  });
}

DivineVideoClip _createTestClip({
  required String id,
  int seconds = 2,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/tmp/test_$id.mp4'),
    duration: Duration(seconds: seconds),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: .vertical,
  );
}
