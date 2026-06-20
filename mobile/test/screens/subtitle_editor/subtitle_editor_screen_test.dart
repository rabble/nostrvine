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
      Stream<SubtitleEditorState>.fromIterable(const [
        SubtitleEditorState(status: SubtitleEditorStatus.failure),
      ]),
      initialState: const SubtitleEditorState(),
    );

    await tester.pumpWidget(pump());
    await tester.pump();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorLoadError), findsOneWidget);
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
        (_) async => const [SubtitleCue(start: 0, end: 1000, text: 'hello')],
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
