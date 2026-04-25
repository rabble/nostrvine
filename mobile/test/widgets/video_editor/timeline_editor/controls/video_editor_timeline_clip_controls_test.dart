// ABOUTME: Widget tests for TimelineClipControls.
// ABOUTME: Verifies visible actions and done-event dispatch.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

void main() {
  group(TimelineClipControls, () {
    late _MockClipEditorBloc bloc;

    setUp(() {
      bloc = _MockClipEditorBloc();
      when(() => bloc.state).thenReturn(const ClipEditorState());
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());
    });

    Widget build() {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<ClipEditorBloc>.value(
              value: bloc,
              child: TimelineClipControls(
                playheadPosition: ValueNotifier(Duration.zero),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders expected labels for single-clip state', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Split'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('dispatches ClipEditorEditingStopped when done pressed', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      await tester.tap(find.byType(DivineIconButton).last);
      await tester.pump();

      verify(() => bloc.add(const ClipEditorEditingStopped())).called(1);
    });
  });
}
