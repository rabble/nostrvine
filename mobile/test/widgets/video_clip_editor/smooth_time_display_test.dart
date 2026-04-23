// ABOUTME: Tests for SmoothTimeDisplay widget
// ABOUTME: Validates time display formatting and styling

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/clip_editor/smooth_time_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmoothTimeDisplay Widget Tests', () {
    Widget buildTestWidget({
      bool isPlaying = false,
      Duration currentPosition = Duration.zero,
      TextStyle? style,
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
            body: SmoothTimeDisplay(
              isPlayingSelector: (s) => s.isPlaying,
              currentPositionSelector: (s) => s.currentPosition,
              style: style,
            ),
          ),
        ),
      );
    }

    testWidgets('displays formatted time at zero position', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('0.00'), findsOneWidget);
    });

    testWidgets('displays formatted time at specific position', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(currentPosition: const Duration(seconds: 5)),
      );
      await tester.pump();

      expect(find.text('5.00'), findsOneWidget);
    });

    testWidgets('displays different time at different position', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          currentPosition: const Duration(seconds: 12, milliseconds: 500),
        ),
      );
      await tester.pump();

      expect(find.text('12.50'), findsOneWidget);
    });

    testWidgets('clamps position to maxDuration when not playing', (
      tester,
    ) async {
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
              body: SmoothTimeDisplay(
                isPlayingSelector: (s) => s.isPlaying,
                currentPositionSelector: (s) => s.currentPosition,
                maxDuration: const Duration(seconds: 5),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('5.00'), findsOneWidget);
    });
  });
}

class _TestClipEditorBloc extends ClipEditorBloc {
  _TestClipEditorBloc({
    ClipEditorState initialState = const ClipEditorState(),
  }) : super(onFinalClipInvalidated: () {}) {
    emit(initialState);
  }
}
