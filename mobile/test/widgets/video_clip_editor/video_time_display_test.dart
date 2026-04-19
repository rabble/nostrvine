// ABOUTME: Tests for VideoTimeDisplay widget
// ABOUTME: Validates time formatting and display structure

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/clip_editor/video_time_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoTimeDisplay Widget Tests', () {
    Widget buildTestWidget({
      bool isPlaying = false,
      Duration currentPosition = Duration.zero,
      Duration totalDuration = const Duration(seconds: 30),
    }) {
      final bloc = _TestClipEditorBloc(
        initialState: ClipEditorState(
          isPlaying: isPlaying,
          currentPosition: currentPosition,
        ),
      );

      return BlocProvider<ClipEditorBloc>.value(
        value: bloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoTimeDisplay(
              isPlayingSelector: (s) => s.isPlaying,
              currentPositionSelector: (s) => s.currentPosition,
              totalDuration: totalDuration,
            ),
          ),
        ),
      );
    }

    testWidgets('displays time with separator and total duration', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Widget should render
      expect(find.byType(VideoTimeDisplay), findsOneWidget);

      // Should contain separator and total duration
      expect(find.textContaining('/'), findsOneWidget);
      expect(find.textContaining('30.00s'), findsOneWidget);
    });

    testWidgets('displays different total duration correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          totalDuration: const Duration(seconds: 75, milliseconds: 500),
        ),
      );
      await tester.pump();

      expect(find.textContaining('75.50s'), findsOneWidget);
    });

    testWidgets('passes maxDuration to SmoothTimeDisplay', (tester) async {
      final bloc = _TestClipEditorBloc(
        initialState: const ClipEditorState(
          currentPosition: Duration(seconds: 10),
        ),
      );

      await tester.pumpWidget(
        BlocProvider<ClipEditorBloc>.value(
          value: bloc,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoTimeDisplay(
                isPlayingSelector: (s) => s.isPlaying,
                currentPositionSelector: (s) => s.currentPosition,
                totalDuration: const Duration(seconds: 30),
                maxDuration: const Duration(seconds: 5),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Current position (10s) should be clamped to maxDuration (5s)
      expect(find.textContaining('5.00'), findsOneWidget);
      // Total duration should still show 30s
      expect(find.textContaining('30.00s'), findsOneWidget);
    });
  });
}

class _TestClipEditorBloc extends ClipEditorBloc {
  _TestClipEditorBloc({
    ClipEditorState initialState = const ClipEditorState(),
  }) {
    emit(initialState);
  }
}
