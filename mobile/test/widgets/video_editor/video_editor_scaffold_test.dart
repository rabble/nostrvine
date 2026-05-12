// ABOUTME: Widget tests for VideoEditorScaffold.
// ABOUTME: Verifies loading UI and FAB visibility rules.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_scaffold.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

void main() {
  group(VideoEditorScaffold, () {
    late VideoEditorMainBloc mainBloc;
    late TimelineOverlayBloc overlayBloc;
    late ClipEditorBloc clipBloc;
    late VideoEditorFilterBloc filterBloc;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mainBloc = VideoEditorMainBloc();
      overlayBloc = TimelineOverlayBloc();
      clipBloc = ClipEditorBloc(onFinalClipInvalidated: () {});
      filterBloc = VideoEditorFilterBloc();
    });

    tearDown(() async {
      await mainBloc.close();
      await overlayBloc.close();
      await clipBloc.close();
      await filterBloc.close();
    });

    Widget buildWidget({
      required bool isLoading,
      ClipEditorBloc? clipBlocOverride,
      ProImageEditorState? editorOverride,
    }) {
      final editorKey = GlobalKey<ProImageEditorState>();
      final removeAreaKey = GlobalKey();

      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: VideoEditorScope(
          editorKey: editorKey,
          editorOverride: editorOverride,
          removeAreaKey: removeAreaKey,
          onOpenCamera: () {},
          onAddStickers: () {},
          onAdjustVolume: () {},
          onOpenClipsEditor: () {},
          onAddEditTextLayer: ([layer]) async => null,
          onOpenMusicLibrary: () {},
          originalClipAspectRatio: 9 / 16,
          bodySizeNotifier: ValueNotifier(const Size(400, 800)),
          fromLibrary: false,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
              BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
              BlocProvider<ClipEditorBloc>.value(
                value: clipBlocOverride ?? clipBloc,
              ),
              BlocProvider<VideoEditorFilterBloc>.value(value: filterBloc),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: VideoEditorScaffold(isLoading: isLoading),
            ),
          ),
        ),
      );
    }

    testWidgets('shows loading scaffold when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(isLoading: true));

      expect(find.byType(BrandedLoadingScaffold), findsOneWidget);
      expect(find.bySemanticsLabel('Add element'), findsOneWidget);
    });

    testWidgets('hides FAB while a sub-editor is open', (tester) async {
      mainBloc.add(const VideoEditorMainOpenSubEditor(SubEditorType.text));

      await tester.pumpWidget(buildWidget(isLoading: true));
      await tester.pump();

      expect(find.bySemanticsLabel('Add element'), findsNothing);
    });

    testWidgets('hides FAB when an overlay item is selected', (tester) async {
      overlayBloc.add(const TimelineOverlayItemSelected('overlay-1'));

      await tester.pumpWidget(buildWidget(isLoading: true));
      await tester.pump();

      expect(find.bySemanticsLabel('Add element'), findsNothing);
    });

    testWidgets(
      'writes history on extraction success even when handled above clip controls',
      (tester) async {
        final clipBloc = _MockClipEditorBloc();
        final mockEditor = _MockProImageEditorState();
        final mockStateManager = _MockStateManager();
        const audioEvent = AudioEvent(
          id: 'audio-1',
          pubkey: '',
          createdAt: 1,
          url: '/tmp/audio.wav',
          mimeType: 'audio/wav',
          sha256: 'abc123',
          fileSize: 123,
          duration: 1,
          title: 'Test',
        );
        final successState = ClipEditorState(
          lastAudioExtraction: ClipAudioExtractionSuccess(
            audioEvent: audioEvent,
          ),
        );

        when(() => clipBloc.state).thenReturn(const ClipEditorState());
        whenListen(
          clipBloc,
          Stream<ClipEditorState>.fromIterable([successState]),
          initialState: const ClipEditorState(),
        );
        when(() => mockEditor.stateManager).thenReturn(mockStateManager);
        when(() => mockStateManager.activeMeta).thenReturn(const {});
        when(
          () => mockEditor.addHistory(
            layers: any(named: 'layers'),
            filters: any(named: 'filters'),
            meta: any(named: 'meta'),
            newLayer: any(named: 'newLayer'),
            transformConfigs: any(named: 'transformConfigs'),
            tuneAdjustments: any(named: 'tuneAdjustments'),
            blur: any(named: 'blur'),
            heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
            blockCaptureScreenshot: any(named: 'blockCaptureScreenshot'),
          ),
        ).thenAnswer((_) {});

        await tester.pumpWidget(
          buildWidget(
            isLoading: true,
            clipBlocOverride: clipBloc,
            editorOverride: mockEditor,
          ),
        );
        await tester.pump();

        final captured =
            verify(
                  () => mockEditor.addHistory(meta: captureAny(named: 'meta')),
                ).captured.single
                as Map<String, dynamic>;
        expect(
          captured[VideoEditorConstants.clipsStateHistoryKey],
          equals(<Map<String, dynamic>>[]),
        );
        expect(
          captured[VideoEditorConstants.audioStateHistoryKey],
          equals([audioEvent.toJson()]),
        );
      },
    );

    testWidgets(
      'ignores discarded extraction results without snackbar or history write',
      (tester) async {
        final clipBloc = _MockClipEditorBloc();
        final mockEditor = _MockProImageEditorState();
        final mockStateManager = _MockStateManager();
        final discardedState = ClipEditorState(
          lastAudioExtraction: ClipAudioExtractionDiscarded(),
        );

        when(() => clipBloc.state).thenReturn(const ClipEditorState());
        whenListen(
          clipBloc,
          Stream<ClipEditorState>.fromIterable([discardedState]),
          initialState: const ClipEditorState(),
        );
        when(() => mockEditor.stateManager).thenReturn(mockStateManager);
        when(() => mockStateManager.activeMeta).thenReturn(const {});
        when(
          () => mockEditor.addHistory(
            layers: any(named: 'layers'),
            filters: any(named: 'filters'),
            meta: any(named: 'meta'),
            newLayer: any(named: 'newLayer'),
            transformConfigs: any(named: 'transformConfigs'),
            tuneAdjustments: any(named: 'tuneAdjustments'),
            blur: any(named: 'blur'),
            heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
            blockCaptureScreenshot: any(named: 'blockCaptureScreenshot'),
          ),
        ).thenAnswer((_) {});

        await tester.pumpWidget(
          buildWidget(
            isLoading: true,
            clipBlocOverride: clipBloc,
            editorOverride: mockEditor,
          ),
        );
        await tester.pump();

        verifyNever(
          () => mockEditor.addHistory(
            layers: any(named: 'layers'),
            filters: any(named: 'filters'),
            meta: any(named: 'meta'),
            newLayer: any(named: 'newLayer'),
            transformConfigs: any(named: 'transformConfigs'),
            tuneAdjustments: any(named: 'tuneAdjustments'),
            blur: any(named: 'blur'),
            heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
            blockCaptureScreenshot: any(named: 'blockCaptureScreenshot'),
          ),
        );
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });
}
