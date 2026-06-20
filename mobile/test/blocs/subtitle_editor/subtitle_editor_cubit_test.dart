// ABOUTME: Tests for SubtitleEditorCubit covering load, edit, and save flows.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/repositories/subtitle_repository.dart';
import 'package:openvine/services/subtitle_service.dart';

class _MockRepo extends Mock implements SubtitleRepository {}

final _video = VideoEvent(
  id: 'v',
  pubkey: 'pk',
  createdAt: 1,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  vineId: 'd1',
);

void main() {
  setUpAll(() => registerFallbackValue(_video));

  group(SubtitleEditorCubit, () {
    late _MockRepo repo;
    setUp(() => repo = _MockRepo());

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'load -> ready with cues',
      setUp: () => when(() => repo.loadCues(any())).thenAnswer(
        (_) async => const [SubtitleCue(start: 0, end: 1000, text: 'a')],
      ),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) => c.load(),
      expect: () => [
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.loading,
        ),
        isA<SubtitleEditorState>()
            .having((s) => s.status, 'status', SubtitleEditorStatus.ready)
            .having((s) => s.cues.length, 'cues', 1),
      ],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'load with no cues -> processing',
      setUp: () =>
          when(() => repo.loadCues(any())).thenAnswer((_) async => const []),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) => c.load(),
      expect: () => [
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.loading,
        ),
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.processing,
        ),
      ],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'load failure -> failure + reports error',
      setUp: () =>
          when(() => repo.loadCues(any())).thenThrow(Exception('boom')),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) => c.load(),
      expect: () => [
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.loading,
        ),
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.failure,
        ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'updateCueText marks dirty',
      setUp: () => when(() => repo.loadCues(any())).thenAnswer(
        (_) async => const [SubtitleCue(start: 0, end: 1000, text: 'a')],
      ),
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) async {
        await c.load();
        c.updateCueText(0, 'fixed');
      },
      verify: (c) {
        expect(c.state.isDirty, isTrue);
        expect(c.state.cues.first.text, 'fixed');
      },
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'save success -> saving then success',
      setUp: () {
        when(() => repo.loadCues(any())).thenAnswer(
          (_) async => const [SubtitleCue(start: 0, end: 1000, text: 'a')],
        );
        when(
          () => repo.publishEditedSubtitles(
            video: any(named: 'video'),
            cues: any(named: 'cues'),
          ),
        ).thenAnswer((_) async {});
      },
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) async {
        await c.load();
        await c.save();
      },
      skip: 2,
      expect: () => [
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.saving,
        ),
        isA<SubtitleEditorState>()
            .having((s) => s.status, 'status', SubtitleEditorStatus.success)
            .having((s) => s.isDirty, 'isDirty', false),
      ],
    );

    blocTest<SubtitleEditorCubit, SubtitleEditorState>(
      'save failure -> failure + reports error',
      setUp: () {
        when(() => repo.loadCues(any())).thenAnswer(
          (_) async => const [SubtitleCue(start: 0, end: 1000, text: 'a')],
        );
        when(
          () => repo.publishEditedSubtitles(
            video: any(named: 'video'),
            cues: any(named: 'cues'),
          ),
        ).thenThrow(SubtitleEditException('boom'));
      },
      build: () => SubtitleEditorCubit(repository: repo, video: _video),
      act: (c) async {
        await c.load();
        await c.save();
      },
      skip: 2,
      expect: () => [
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.saving,
        ),
        isA<SubtitleEditorState>().having(
          (s) => s.status,
          'status',
          SubtitleEditorStatus.failure,
        ),
      ],
      errors: () => [isA<SubtitleEditException>()],
    );
  });
}
