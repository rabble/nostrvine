// ABOUTME: Widget tests for SubtitleEditorView — rendering cues, status
// ABOUTME: states, and editing interactions using a mocked cubit.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/subtitle_repository_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/repositories/subtitle_repository.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:openvine/services/video_event_resolver.dart';

import '../../helpers/test_helpers.dart';

class _MockCubit extends MockCubit<SubtitleEditorState>
    implements SubtitleEditorCubit {}

class _MockSubtitleRepository extends Mock implements SubtitleRepository {}

class _FakeVideoEventResolver implements VideoEventResolver {
  _FakeVideoEventResolver(this.video);

  final VideoEvent? video;
  final resolvedIds = <String>[];
  final allowOwnContentBypassValues = <bool>[];

  @override
  Future<VideoEvent?> resolveById(
    String eventId, {
    bool allowOwnContentBypass = false,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    resolvedIds.add(eventId);
    allowOwnContentBypassValues.add(allowOwnContentBypass);
    return video;
  }
}

/// The caption-text field of a cue row, as opposed to its timing fields.
Finder cueTextFields(AppLocalizations l10n) => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.hintText == l10n.subtitleEditorCueHint,
);

void main() {
  late _MockCubit cubit;

  setUpAll(() {
    registerFallbackValue(TestHelpers.createVideoEvent(id: 'fallback'));
  });

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
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(cueTextFields(l10n), findsNWidgets(2));
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

  testWidgets('shows the no-speech message when status is empty', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const SubtitleEditorState(status: SubtitleEditorStatus.empty));
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorNoSpeech), findsOneWidget);
    expect(find.text(l10n.subtitleEditorProcessing), findsNothing);
  });

  testWidgets('shows the load error when status is unavailable', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(status: SubtitleEditorStatus.unavailable),
    );
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorLoadError), findsOneWidget);
    expect(find.text(l10n.subtitleEditorProcessing), findsNothing);
  });

  testWidgets('a failed load keeps its reason on screen', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(status: SubtitleEditorStatus.failure),
    );
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorLoadError), findsOneWidget);
    expect(find.text(l10n.subtitleEditorWriteOwn), findsOneWidget);
  });

  testWidgets('a failed save keeps the cues the creator wrote', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.failure,
        isDirty: true,
        cues: [EditableCue(start: 0, end: 1000, text: 'written')],
      ),
    );
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text('written'), findsOneWidget);
    expect(find.text(l10n.subtitleEditorLoadError), findsNothing);
  });

  testWidgets('retry from a no-cue state reloads', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(const SubtitleEditorState(status: SubtitleEditorStatus.empty));
    when(cubit.load).thenAnswer((_) async {});
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text(l10n.subtitleEditorRetry));
    verify(cubit.load).called(1);
  });

  testWidgets('offers writing your own captions when the track is empty', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const SubtitleEditorState(status: SubtitleEditorStatus.empty));
    when(cubit.addCue).thenReturn(null);
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text(l10n.subtitleEditorWriteOwn));
    verify(cubit.addCue).called(1);
  });

  testWidgets('does not offer authoring while transcription runs', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(status: SubtitleEditorStatus.processing),
    );
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorWriteOwn), findsNothing);
  });

  testWidgets('add-a-line is reachable from the cue list', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [EditableCue(start: 0, end: 1000, text: 'one')],
      ),
    );
    when(cubit.addCue).thenReturn(null);
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text(l10n.subtitleEditorAddCue));
    verify(cubit.addCue).called(1);
  });

  testWidgets('add-a-line is disabled once the cues fill the video', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        videoDurationMs: 2000,
        cues: [EditableCue(start: 0, end: 2000, text: 'one')],
      ),
    );
    when(cubit.addCue).thenReturn(null);
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(
      find.text(l10n.subtitleEditorAddCue),
      warnIfMissed: false,
    );
    verifyNever(cubit.addCue);
  });

  testWidgets('the trash action removes that row', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [
          EditableCue(start: 0, end: 1000, text: 'one'),
          EditableCue(start: 1000, end: 2000, text: 'two'),
        ],
      ),
    );
    when(() => cubit.removeCue(any())).thenReturn(null);
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.bySemanticsLabel(l10n.subtitleEditorRemoveCue).last);
    verify(() => cubit.removeCue(1)).called(1);
  });

  testWidgets('editing a start time dispatches updateCueTiming', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [EditableCue(start: 0, end: 2000, text: 'one')],
      ),
    );
    when(
      () => cubit.updateCueTiming(any(), start: any(named: 'start')),
    ).thenReturn(null);
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.enterText(
      find.descendant(
        of: find.bySemanticsLabel(l10n.subtitleEditorStartLabel),
        matching: find.byType(TextField),
      ),
      '1.5',
    );
    verify(() => cubit.updateCueTiming(0, start: 1500)).called(1);
  });

  testWidgets("clearing a timing field restores the cue's value on blur", (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [EditableCue(start: 1500, end: 2000, text: 'one')],
      ),
    );
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    final startField = find.descendant(
      of: find.bySemanticsLabel(l10n.subtitleEditorStartLabel),
      matching: find.byType(TextField),
    );

    // Empty is unparseable, so the cubit never hears about it and the cue
    // still holds 1.5s — the field must not keep claiming otherwise.
    await tester.enterText(startField, '');
    verifyNever(() => cubit.updateCueTiming(any(), start: any(named: 'start')));

    await tester.tap(cueTextFields(l10n).first);
    await tester.pump();

    expect(tester.widget<TextField>(startField).controller?.text, '1.5');
  });

  testWidgets('rows follow the cue that moved into their position', (
    tester,
  ) async {
    whenListen(
      cubit,
      Stream<SubtitleEditorState>.fromIterable(const [
        SubtitleEditorState(
          status: SubtitleEditorStatus.ready,
          cues: [EditableCue(start: 1000, end: 2000, text: 'two')],
        ),
      ]),
      initialState: const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [
          EditableCue(start: 0, end: 1000, text: 'one'),
          EditableCue(start: 1000, end: 2000, text: 'two'),
        ],
      ),
    );

    await tester.pumpWidget(pump());
    expect(find.text('one'), findsOneWidget);

    // 'one' was deleted; the surviving cue slides into row 0 and its text
    // field has to follow rather than keep showing the removed line.
    await tester.pump();

    expect(find.text('one'), findsNothing);
    expect(find.text('two'), findsOneWidget);
  });

  testWidgets('save stays disabled while a cue is incomplete', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        isDirty: true,
        cues: [EditableCue(start: 0, end: 2000, text: '  ')],
      ),
    );
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorInvalidHint), findsOneWidget);

    await tester.tap(find.text(l10n.subtitleEditorSave));
    verifyNever(cubit.save);
  });

  testWidgets('editing a field dispatches updateCueText', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [EditableCue(start: 0, end: 1000, text: 'one')],
      ),
    );
    await tester.pumpWidget(pump());
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.enterText(cueTextFields(l10n).first, 'edited');
    verify(() => cubit.updateCueText(0, 'edited')).called(1);
  });

  testWidgets('load failure shows the load error copy', (tester) async {
    whenListen(
      cubit,
      Stream<SubtitleEditorState>.fromIterable(const [
        SubtitleEditorState(status: SubtitleEditorStatus.failure),
      ]),
      initialState: const SubtitleEditorState(),
    );

    await tester.pumpWidget(pump());
    await tester.pump();

    // Scoped to the snackbar: the body now carries the same copy, since a
    // snackbar fades and the reason has to outlive it.
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(l10n.subtitleEditorLoadError),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.subtitleEditorSaveError), findsNothing);
  });

  group(SubtitleEditorScreen, () {
    testWidgets('resolves video by id when no prefetched route extra exists', (
      tester,
    ) async {
      final video = TestHelpers.createVideoEvent(
        id: '0000000000000000000000000000000000000000000000000000000000000000',
      );
      final resolver = _FakeVideoEventResolver(video);
      final repository = _MockSubtitleRepository();
      when(() => repository.loadCues(any())).thenAnswer(
        (_) async => const SubtitleFetchResult(
          SubtitleFetchStatus.available,
          cues: [SubtitleCue(start: 0, end: 1000, text: 'hello')],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEventResolverProvider.overrideWithValue(resolver),
            subtitleRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SubtitleEditorScreen(videoId: video.id),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(resolver.resolvedIds, [video.id]);
      expect(resolver.allowOwnContentBypassValues, [isTrue]);
      expect(find.text('hello'), findsOneWidget);
      verify(() => repository.loadCues(video)).called(1);
    });

    testWidgets('shows route error when the video id cannot be resolved', (
      tester,
    ) async {
      const videoId =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
      final resolver = _FakeVideoEventResolver(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEventResolverProvider.overrideWithValue(resolver)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SubtitleEditorScreen(videoId: videoId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(resolver.resolvedIds, [videoId]);
      expect(find.text(l10n.routeInvalidVideoId), findsOneWidget);
    });
  });
}
