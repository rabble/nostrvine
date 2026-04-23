// ABOUTME: Tests for VideoClipEditorTopBar widget
// ABOUTME: Validates close button, clip counter, and done button

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/clip_editor/video_clip_editor_top_bar.dart';
import 'package:pro_video_editor/core/models/video/editor_video_model.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoClipEditorTopBar Widget Tests', () {
    Widget buildTestWidget({
      int currentClipIndex = 0,
      int totalClips = 3,
      bool isEditing = false,
    }) {
      final clips = List.generate(
        totalClips,
        (i) => DivineVideoClip(
          id: 'clip$i',
          video: EditorVideo.file('/test/clip$i.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        ),
      );
      final bloc = _TestClipEditorBloc(
        initialState: ClipEditorState(
          clips: clips,
          currentClipIndex: currentClipIndex,
          isEditing: isEditing,
        ),
      );

      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(_TestVideoEditorNotifier.new),
        ],
        child: BlocProvider<ClipEditorBloc>.value(
          value: bloc,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) =>
                      const Scaffold(body: VideoClipEditorTopBar()),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('displays clip counter with correct format', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('updates clip counter when clip index changes', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(currentClipIndex: 1, totalClips: 5),
      );

      expect(find.text('2/5'), findsOneWidget);
    });

    testWidgets('displays close icon when not editing', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(DivineIconButton), findsWidgets);
    });

    testWidgets('displays close icon when editing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isEditing: true));

      expect(find.byType(DivineIconButton), findsOneWidget);
    });

    testWidgets('displays done button when not editing', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.bySemanticsLabel('Done'), findsOneWidget);
    });

    testWidgets('close button stops editing when tapped', (tester) async {
      await tester.pumpWidget(buildTestWidget(isEditing: true));

      final closeButton = find.byType(DivineIconButton);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // After tapping, editing stops and the Done button appears
      expect(find.bySemanticsLabel('Done'), findsOneWidget);
    });

    testWidgets('displays correct clip counter for single clip', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(totalClips: 1));

      expect(find.text('1/1'), findsOneWidget);
    });
  });
}

class _TestVideoEditorNotifier extends VideoEditorNotifier {
  @override
  VideoEditorProviderState build() => VideoEditorProviderState();
}

class _TestClipEditorBloc extends ClipEditorBloc {
  _TestClipEditorBloc({
    ClipEditorState initialState = const ClipEditorState(),
  }) : super(onFinalClipInvalidated: () {}) {
    emit(initialState);
  }
}
