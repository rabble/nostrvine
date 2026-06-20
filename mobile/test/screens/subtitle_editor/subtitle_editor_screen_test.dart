// ABOUTME: Widget tests for SubtitleEditorView — rendering cues, status
// ABOUTME: states, and editing interactions using a mocked cubit.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';

class _MockCubit extends MockCubit<SubtitleEditorState>
    implements SubtitleEditorCubit {}

void main() {
  late _MockCubit cubit;
  setUp(() => cubit = _MockCubit());

  Widget pump() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<SubtitleEditorCubit>.value(
      value: cubit,
      child: const SubtitleEditorView(),
    ),
  );

  testWidgets('renders a text field per cue when ready', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [
          EditableCue(start: 0, end: 1000, text: 'one'),
          EditableCue(start: 1000, end: 2000, text: 'two'),
        ],
      ),
    );
    await tester.pumpWidget(pump());
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('one'), findsOneWidget);
  });

  testWidgets('shows processing message when status is processing', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(status: SubtitleEditorStatus.processing),
    );
    await tester.pumpWidget(pump());
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorProcessing), findsOneWidget);
  });

  testWidgets('editing a field dispatches updateCueText', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [EditableCue(start: 0, end: 1000, text: 'one')],
      ),
    );
    await tester.pumpWidget(pump());
    await tester.enterText(find.byType(TextField).first, 'edited');
    verify(() => cubit.updateCueText(0, 'edited')).called(1);
  });

  testWidgets('load failure shows the load error copy', (tester) async {
    whenListen(
      cubit,
      Stream<SubtitleEditorState>.fromIterable(
        const [SubtitleEditorState(status: SubtitleEditorStatus.failure)],
      ),
      initialState: const SubtitleEditorState(),
    );

    await tester.pumpWidget(pump());
    await tester.pump();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorLoadError), findsOneWidget);
    expect(find.text(l10n.subtitleEditorSaveError), findsNothing);
  });
}
