// ABOUTME: Widget tests for VideoEditorMainOverlayActions toolbar.
// ABOUTME: Tests button rendering, enabled/disabled states, and music sub-editor hiding.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_overlay_actions.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

import '../../../helpers/go_router.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorMainOverlayActions, () {
    late _MockVideoEditorMainBloc mockBloc;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockBloc = _MockVideoEditorMainBloc();
      mockGoRouter = MockGoRouter();

      when(() => mockBloc.state).thenReturn(const VideoEditorMainState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockGoRouter.pop<Object?>(any())).thenAnswer((_) async {});
    });

    Widget buildWidget({VideoEditorMainState? state}) {
      if (state != null) {
        when(() => mockBloc.state).thenReturn(state);
      }

      return ProviderScope(
        child: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MaterialApp(
            home: Scaffold(
              body: VideoEditorScope(
                editorKey: GlobalKey(),
                removeAreaKey: GlobalKey(),
                originalClipAspectRatio: 9 / 16,
                bodySizeNotifier: ValueNotifier(const Size(400, 600)),
                onAddStickers: () {},
                onAddEditTextLayer: ([layer]) async => null,
                child: BlocProvider<VideoEditorMainBloc>.value(
                  value: mockBloc,
                  child: const VideoEditorMainOverlayActions(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoEditorMainOverlayActions', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(
          find.byType(VideoEditorMainOverlayActions),
          findsOneWidget,
        );
      });

      testWidgets('renders Close button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Close'), findsOneWidget);
      });

      testWidgets('renders Done button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Done'), findsOneWidget);
      });

      testWidgets('renders $VideoEditorAudioChip', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(VideoEditorAudioChip), findsOneWidget);
      });

      testWidgets('renders Undo button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Undo'), findsOneWidget);
      });

      testWidgets('renders Redo button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Redo'), findsOneWidget);
      });

      testWidgets('renders Reorder button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Reorder'), findsOneWidget);
      });

      testWidgets('renders Play button when not playing', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorMainState(isPlayerReady: true),
          ),
        );

        expect(find.bySemanticsLabel('Play'), findsOneWidget);
      });

      testWidgets('renders Pause button when playing', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorMainState(
              isPlaying: true,
              isPlayerReady: true,
            ),
          ),
        );

        expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      });

      testWidgets(
        'renders $CircularProgressIndicator when player is not ready',
        (tester) async {
          await tester.pumpWidget(buildWidget());

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
      );
    });

    group('music sub-editor hiding', () {
      Finder findOverlayOpacity() => find
          .descendant(
            of: find.byType(VideoEditorMainOverlayActions),
            matching: find.byType(AnimatedOpacity),
          )
          .first;

      testWidgets('is hidden when music sub-editor is open', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorMainState(
              openSubEditor: SubEditorType.music,
            ),
          ),
        );
        // Use pump instead of pumpAndSettle — CircularProgressIndicator
        // never settles.
        await tester.pump(const Duration(milliseconds: 300));

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          findOverlayOpacity(),
        );
        expect(animatedOpacity.opacity, equals(0));
      });

      testWidgets('is visible when no sub-editor is open', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump(const Duration(milliseconds: 300));

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          findOverlayOpacity(),
        );
        expect(animatedOpacity.opacity, equals(1));
      });

      testWidgets('is visible when non-music sub-editor is open', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorMainState(
              openSubEditor: SubEditorType.text,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          findOverlayOpacity(),
        );
        expect(animatedOpacity.opacity, equals(1));
      });
    });

    group('enabled/disabled states', () {
      testWidgets('Undo button is disabled when canUndo is false', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        final undoButton = tester.widget<DivineIconButton>(
          find.byWidgetPredicate(
            (w) => w is DivineIconButton && w.semanticLabel == 'Undo',
          ),
        );
        expect(undoButton.onPressed, isNull);
      });

      testWidgets('Undo button is enabled when canUndo is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(state: const VideoEditorMainState(canUndo: true)),
        );

        final undoButton = tester.widget<DivineIconButton>(
          find.byWidgetPredicate(
            (w) => w is DivineIconButton && w.semanticLabel == 'Undo',
          ),
        );
        expect(undoButton.onPressed, isNotNull);
      });

      testWidgets('Redo button is disabled when canRedo is false', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        final redoButton = tester.widget<DivineIconButton>(
          find.byWidgetPredicate(
            (w) => w is DivineIconButton && w.semanticLabel == 'Redo',
          ),
        );
        expect(redoButton.onPressed, isNull);
      });

      testWidgets('Redo button is enabled when canRedo is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(state: const VideoEditorMainState(canRedo: true)),
        );

        final redoButton = tester.widget<DivineIconButton>(
          find.byWidgetPredicate(
            (w) => w is DivineIconButton && w.semanticLabel == 'Redo',
          ),
        );
        expect(redoButton.onPressed, isNotNull);
      });

      testWidgets('Reorder button is disabled with 0 or 1 layers', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        final reorderButton = tester.widget<DivineIconButton>(
          find.byWidgetPredicate(
            (w) => w is DivineIconButton && w.semanticLabel == 'Reorder',
          ),
        );
        expect(reorderButton.onPressed, isNull);
      });
    });

    group('interactions', () {
      testWidgets(
        'tapping Play dispatches $VideoEditorPlaybackToggleRequested',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(
              state: const VideoEditorMainState(isPlayerReady: true),
            ),
          );

          await tester.tap(find.bySemanticsLabel('Play'));

          verify(
            () => mockBloc.add(const VideoEditorPlaybackToggleRequested()),
          ).called(1);
        },
      );

      testWidgets(
        'tapping Close when no sub-editor is open calls context.pop',
        (tester) async {
          await tester.pumpWidget(buildWidget());

          await tester.tap(find.bySemanticsLabel('Close'));

          verify(() => mockGoRouter.pop<Object?>(any())).called(1);
        },
      );
    });
  });
}
