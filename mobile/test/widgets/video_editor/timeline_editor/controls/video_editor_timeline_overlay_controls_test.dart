// ABOUTME: Widget tests for TimelineOverlayControls.
// ABOUTME: Verifies rendering for each overlay type with proper
// ABOUTME: VideoEditorScope in the tree.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_overlay_controls.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

void main() {
  group(TimelineOverlayControls, () {
    late _MockTimelineOverlayBloc overlayBloc;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUpAll(() {
      registerFallbackValue(const TimelineOverlayItemSelected(null));
    });

    setUp(() {
      overlayBloc = _MockTimelineOverlayBloc();
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
    });

    Widget buildWithEditor(
      TimelineOverlayItem item,
      _MockProImageEditorState mockEditor,
      _MockVideoEditorMainBloc mainBloc,
    ) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
                BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
              ],
              child: VideoEditorScope(
                editorKey: GlobalKey(),
                removeAreaKey: GlobalKey(),
                originalClipAspectRatio: 9 / 16,
                bodySizeNotifier: ValueNotifier(const Size(400, 600)),
                fromLibrary: false,
                onOpenCamera: () {},
                onOpenClipsEditor: () {},
                onAddStickers: () {},
                onAdjustVolume: () {},
                onAddEditTextLayer: ([layer]) async => null,
                onOpenMusicLibrary: () {},
                editorOverride: mockEditor,
                child: TimelineOverlayControls(item: item),
              ),
            ),
          ),
        ),
      );
    }

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
              bodySizeNotifier: ValueNotifier(const Size(400, 600)),
              fromLibrary: false,
              onOpenCamera: () {},
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

      expect(find.byType(VideoEditorTimelineControls), findsOneWidget);
      expect(find.text(l10n.videoEditorDeleteLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDuplicateLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorSplitLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDoneLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorEditLabel), findsNothing);
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

      expect(find.byType(VideoEditorTimelineControls), findsOneWidget);
      expect(find.text(l10n.videoEditorDeleteLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDuplicateLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorSplitLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDoneLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorEditLabel), findsNothing);
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

      expect(find.byType(VideoEditorTimelineControls), findsOneWidget);
      expect(find.text(l10n.videoEditorDeleteLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorEditLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDuplicateLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorSplitLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDoneLabel), findsOneWidget);
    });

    group('behavior', () {
      late _MockProImageEditorState mockEditor;
      late _MockStateManager mockStateManager;
      late _MockVideoEditorMainBloc mainBloc;

      setUp(() {
        mockEditor = _MockProImageEditorState();
        mockStateManager = _MockStateManager();
        mainBloc = _MockVideoEditorMainBloc();
        when(() => mainBloc.stream).thenAnswer(
          (_) => const Stream<VideoEditorMainState>.empty(),
        );
        when(() => mockEditor.stateManager).thenReturn(mockStateManager);
        when(
          () => mockEditor.addHistory(
            layers: any(named: 'layers'),
            filters: any(named: 'filters'),
            meta: any(named: 'meta'),
          ),
        ).thenAnswer((_) {});
      });

      testWidgets(
        'duplicate inserts a copy after the selected filter item and selects it',
        (tester) async {
          final filterA = FilterState(
            id: 'filter-a',
            name: 'test-filter',
            matrices: const [
              [1.0],
            ],
            startTime: const Duration(seconds: 1),
            endTime: const Duration(seconds: 5),
          );
          when(() => mockStateManager.activeFilters).thenReturn([filterA]);
          when(() => mainBloc.state).thenReturn(
            const VideoEditorMainState(),
          );

          const item = TimelineOverlayItem(
            id: 'filter-a',
            type: TimelineOverlayType.filter,
            startTime: Duration(seconds: 1),
            endTime: Duration(seconds: 5),
          );
          await tester.pumpWidget(
            buildWithEditor(item, mockEditor, mainBloc),
          );

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorDuplicateSelectedItemSemanticLabel,
            ),
          );
          await tester.pump();

          final result = verify(
            () => mockEditor.addHistory(
              filters: captureAny(named: 'filters'),
            ),
          )..called(1);
          final filters = result.captured.single as List<FilterState>;
          expect(filters, hasLength(2));
          expect(filters[1].id, startsWith('filter-a_copy_'));

          final addEvent = verify(
            () => overlayBloc.add(captureAny()),
          ).captured.whereType<TimelineOverlayItemSelected>().last;
          expect(addEvent.itemId, startsWith('filter-a_copy_'));
        },
      );

      testWidgets(
        'split at valid position creates two segments and selects the second',
        (tester) async {
          final filterA = FilterState(
            id: 'filter-a',
            name: 'test-filter',
            matrices: const [
              [1.0],
            ],
            startTime: const Duration(seconds: 1),
            endTime: const Duration(seconds: 5),
          );
          when(() => mockStateManager.activeFilters).thenReturn([filterA]);
          when(() => mainBloc.state).thenReturn(
            const VideoEditorMainState(
              currentPosition: Duration(seconds: 3),
            ),
          );

          const item = TimelineOverlayItem(
            id: 'filter-a',
            type: TimelineOverlayType.filter,
            startTime: Duration(seconds: 1),
            endTime: Duration(seconds: 5),
          );
          await tester.pumpWidget(
            buildWithEditor(item, mockEditor, mainBloc),
          );

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorSplitSelectedClipSemanticLabel,
            ),
          );
          await tester.pump();

          final result = verify(
            () => mockEditor.addHistory(
              filters: captureAny(named: 'filters'),
            ),
          )..called(1);
          final filters = result.captured.single as List<FilterState>;
          expect(filters, hasLength(2));
          expect(filters[0].endTime, equals(const Duration(seconds: 3)));
          expect(filters[1].startTime, equals(const Duration(seconds: 3)));
          expect(filters[1].endTime, equals(const Duration(seconds: 5)));

          final addEvent = verify(
            () => overlayBloc.add(captureAny()),
          ).captured.whereType<TimelineOverlayItemSelected>().last;
          expect(addEvent.itemId, isNotNull);
        },
      );

      testWidgets(
        'split at invalid position shows snackbar and does not commit history',
        (tester) async {
          final filterA = FilterState(
            id: 'filter-a',
            name: 'test-filter',
            matrices: const [
              [1.0],
            ],
            startTime: const Duration(seconds: 1),
            endTime: const Duration(seconds: 5),
          );
          when(() => mockStateManager.activeFilters).thenReturn([filterA]);
          // currentPosition = 0, which is <= startTime(1s) → invalid
          when(() => mainBloc.state).thenReturn(
            const VideoEditorMainState(),
          );

          const item = TimelineOverlayItem(
            id: 'filter-a',
            type: TimelineOverlayType.filter,
            startTime: Duration(seconds: 1),
            endTime: Duration(seconds: 5),
          );
          await tester.pumpWidget(
            buildWithEditor(item, mockEditor, mainBloc),
          );

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorSplitSelectedClipSemanticLabel,
            ),
          );
          await tester.pump();

          expect(
            find.text(l10n.videoEditorSplitPlayheadOutsideClip),
            findsOneWidget,
          );
          verifyNever(
            () => mockEditor.addHistory(
              layers: any(named: 'layers'),
              filters: any(named: 'filters'),
              meta: any(named: 'meta'),
            ),
          );
        },
      );

      testWidgets(
        'sound split sets startOffset of second segment to '
        'originalOffset + (splitAt - startTime)',
        (tester) async {
          const track = AudioEvent(
            id: 'sound-1',
            pubkey: 'pub',
            createdAt: 0,
            startOffset: Duration(seconds: 2),
            startTime: Duration(seconds: 3),
            endTime: Duration(seconds: 8),
          );
          when(() => mockStateManager.activeMeta).thenReturn({
            VideoEditorConstants.audioStateHistoryKey: [track.toJson()],
          });
          // splitAt = 5s, which is within [3s, 8s)
          when(() => mainBloc.state).thenReturn(
            const VideoEditorMainState(
              currentPosition: Duration(seconds: 5),
            ),
          );

          const item = TimelineOverlayItem(
            id: 'sound-1',
            type: TimelineOverlayType.sound,
            startTime: Duration(seconds: 3),
            endTime: Duration(seconds: 8),
          );
          await tester.pumpWidget(
            buildWithEditor(item, mockEditor, mainBloc),
          );

          await tester.tap(
            find.bySemanticsLabel(
              l10n.videoEditorSplitSelectedClipSemanticLabel,
            ),
          );
          await tester.pump();

          final result = verify(
            () => mockEditor.addHistory(meta: captureAny(named: 'meta')),
          )..called(1);
          final meta = result.captured.single as Map<String, dynamic>;
          final tracksJson =
              meta[VideoEditorConstants.audioStateHistoryKey] as List<dynamic>;
          final second = AudioEvent.fromJson(
            tracksJson[1] as Map<String, dynamic>,
          );

          // second.startOffset = originalStartOffset + (splitAt - item.startTime)
          //                     = 2s + (5s - 3s) = 4s
          expect(second.startOffset, equals(const Duration(seconds: 4)));
        },
      );
    });
  });
}
