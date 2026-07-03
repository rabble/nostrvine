// ABOUTME: Tests for VideoEditorTuneOverlayControls widget.
// ABOUTME: Validates the close/done toolbar dispatches the right bloc events.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/tune_editor/video_editor_tune_overlay_controls.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockVideoEditorTuneBloc
    extends MockBloc<VideoEditorTuneEvent, VideoEditorTuneState>
    implements VideoEditorTuneBloc {}

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const VideoEditorTuneCancelled());
    registerFallbackValue(const VideoEditorTuneConfirmed());
  });

  group('VideoEditorTuneOverlayControls', () {
    late _MockVideoEditorTuneBloc mockBloc;
    late _MockVideoEditorMainBloc mockMainBloc;

    setUp(() {
      mockBloc = _MockVideoEditorTuneBloc();
      mockMainBloc = _MockVideoEditorMainBloc();
      when(() => mockBloc.state).thenReturn(
        const VideoEditorTuneState(
          adjustments: [],
        ),
      );
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockMainBloc.state).thenReturn(const VideoEditorMainState());
      when(() => mockMainBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    Widget buildWidget() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoEditorScope(
            editorKey: GlobalKey<ProImageEditorState>(),
            removeAreaKey: GlobalKey(),
            originalClipAspectRatio: 9 / 16,
            bodySizeNotifier: ValueNotifier(const Size(400, 600)),
            zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
            fromLibrary: false,
            onOpenCamera: () {},
            onOpenClipsEditor: () {},
            onAddStickers: () {},
            onOpenMusicLibrary: () {},
            onOpenVoiceOver: () {},
            onAddEditTextLayer: ([layer]) async => null,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<VideoEditorTuneBloc>.value(value: mockBloc),
                BlocProvider<VideoEditorMainBloc>.value(value: mockMainBloc),
              ],
              child: const SizedBox(
                width: 400,
                height: 600,
                child: VideoEditorTuneOverlayControls(),
              ),
            ),
          ),
        ),
      );
    }

    Finder byLabel(String label) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );

    testWidgets('renders Close and Done buttons', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(byLabel('Close'), findsOneWidget);
      expect(byLabel('Done'), findsOneWidget);
    });

    testWidgets('tapping Close dispatches Cancelled', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      await tester.tap(byLabel('Close'));
      await tester.pump();

      verify(() => mockBloc.add(const VideoEditorTuneCancelled())).called(1);
    });

    testWidgets('tapping Done dispatches Confirmed', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      await tester.tap(byLabel('Done'));
      await tester.pump();

      verify(() => mockBloc.add(const VideoEditorTuneConfirmed())).called(1);
    });
  });
}
