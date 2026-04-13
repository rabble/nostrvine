// ABOUTME: Widget tests for VideoEditorMainOverlayActions toolbar.
// ABOUTME: Tests button rendering, play state indicator, and music sub-editor hiding.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
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
      when(() => mockBloc.stream).thenAnswer(
        (_) => const Stream<VideoEditorMainState>.empty(),
      );
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoEditorScope(
                editorKey: GlobalKey(),
                removeAreaKey: GlobalKey(),
                originalClipAspectRatio: 9 / 16,
                bodySizeNotifier: ValueNotifier(const Size(400, 600)),
                fromLibrary: false,
                onOpenClipsEditor: () {},
                onAddStickers: () {},
                onAdjustVolume: () {},
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

      testWidgets('renders Reorder button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Reorder'), findsOneWidget);
      });

      testWidgets('renders play icon when not playing and player ready', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorMainState(isPlayerReady: true),
          ),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.playFill,
          ),
          findsOneWidget,
        );
      });

      testWidgets('renders pause icon when playing', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorMainState(
              isPlaying: true,
              isPlayerReady: true,
            ),
          ),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.pauseFill,
          ),
          findsOneWidget,
        );
      });

      testWidgets(
        'does not render play/pause icon when player is not ready',
        (tester) async {
          await tester.pumpWidget(buildWidget());

          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is DivineIcon &&
                  (w.icon == DivineIconName.playFill ||
                      w.icon == DivineIconName.pauseFill),
            ),
            findsNothing,
          );
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
