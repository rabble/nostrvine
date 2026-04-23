// ABOUTME: Widget tests for TimelineOverlayControls.
// ABOUTME: Verifies rendering for each overlay type with proper
// ABOUTME: VideoEditorScope in the tree.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_overlay_controls.dart';

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

void main() {
  group(TimelineOverlayControls, () {
    late _MockTimelineOverlayBloc overlayBloc;

    setUp(() {
      overlayBloc = _MockTimelineOverlayBloc();
      when(() => overlayBloc.stream).thenAnswer(
        (_) => const Stream<TimelineOverlayState>.empty(),
      );
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(),
      );
    });

    Widget build(TimelineOverlayItem item) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorScope(
              editorKey: GlobalKey(),
              removeAreaKey: GlobalKey(),
              originalClipAspectRatio: 9 / 16,
              bodySizeNotifier: ValueNotifier(
                const Size(400, 600),
              ),
              fromLibrary: false,
              onOpenClipsEditor: () {},
              onAddStickers: () {},
              onAdjustVolume: () {},
              onAddEditTextLayer: ([layer]) async => null,
              onOpenMusicLibrary: () {},
              child: BlocProvider<TimelineOverlayBloc>.value(
                value: overlayBloc,
                child: TimelineOverlayControls(item: item),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders $VideoEditorTimelineControls for layer', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'layer-1',
        type: TimelineOverlayType.layer,
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
      );

      await tester.pumpWidget(build(item));

      expect(
        find.byType(VideoEditorTimelineControls),
        findsOneWidget,
      );
    });

    testWidgets('renders $VideoEditorTimelineControls for filter', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'filter-1',
        type: TimelineOverlayType.filter,
        startTime: Duration.zero,
        endTime: Duration(seconds: 5),
      );

      await tester.pumpWidget(build(item));

      expect(
        find.byType(VideoEditorTimelineControls),
        findsOneWidget,
      );
    });

    testWidgets('renders $VideoEditorTimelineControls for sound', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'sound-1',
        type: TimelineOverlayType.sound,
        startTime: Duration.zero,
        endTime: Duration(seconds: 10),
      );

      await tester.pumpWidget(build(item));

      expect(
        find.byType(VideoEditorTimelineControls),
        findsOneWidget,
      );
    });
  });
}
