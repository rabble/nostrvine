// ABOUTME: Tests for the captions editor cubit.
// ABOUTME: Covers generation outcomes, cue editing, preset, and mode ops.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/captions_editor/captions_editor_cubit.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/services/video_editor/caption_generation_service.dart';

class _MockCaptionGenerationService extends Mock
    implements CaptionGenerationService {}

void main() {
  group(CaptionsEditorCubit, () {
    const cue = CaptionCue(
      id: 'cue-0',
      text: 'Hello.',
      start: Duration.zero,
      end: Duration(seconds: 1),
    );

    late _MockCaptionGenerationService service;

    setUp(() {
      service = _MockCaptionGenerationService();
    });

    CaptionsEditorCubit build({List<CaptionCue>? initialCues}) =>
        CaptionsEditorCubit(
          generationService: service,
          clips: const [],
          totalDuration: const Duration(seconds: 6),
          mode: CaptionRenderMode.overlay,
          presetId: 'classic',
          languageTag: 'en-US',
          initialCues: initialCues,
        );

    void stubOutcome(CaptionGenerationOutcome outcome) {
      when(
        () => service.generateForClips(
          clips: any(named: 'clips'),
          localeIdentifier: any(named: 'localeIdentifier'),
        ),
      ).thenAnswer((_) async => outcome);
    }

    test('starts ready when initial cues are provided', () {
      final cubit = build(initialCues: const [cue]);
      addTearDown(cubit.close);

      expect(cubit.state.status, equals(CaptionsEditorStatus.ready));
      expect(cubit.state.cues, equals(const [cue]));
    });

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'emits ready with cues when generation succeeds',
      build: () {
        stubOutcome(const CaptionsGenerated([cue]));
        return build();
      },
      act: (cubit) => cubit.initialize(),
      expect: () => [
        isA<CaptionsEditorState>()
            .having((s) => s.status, 'status', CaptionsEditorStatus.ready)
            .having((s) => s.cues, 'cues', const [cue]),
      ],
    );

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'emits empty when no speech is recognized',
      build: () {
        stubOutcome(const CaptionsEmpty());
        return build();
      },
      act: (cubit) => cubit.initialize(),
      expect: () => [
        isA<CaptionsEditorState>().having(
          (s) => s.status,
          'status',
          CaptionsEditorStatus.empty,
        ),
      ],
    );

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'emits failed with the reason when generation fails',
      build: () {
        stubOutcome(
          const CaptionsFailed(CaptionGenerationFailure.recognizerUnavailable),
        );
        return build();
      },
      act: (cubit) => cubit.initialize(),
      expect: () => [
        isA<CaptionsEditorState>()
            .having((s) => s.status, 'status', CaptionsEditorStatus.failed)
            .having(
              (s) => s.failure,
              'failure',
              CaptionGenerationFailure.recognizerUnavailable,
            ),
      ],
    );

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'initialize is a no-op for a session with existing cues',
      build: () => build(initialCues: const [cue]),
      act: (cubit) => cubit.initialize(),
      expect: () => const <CaptionsEditorState>[],
      verify: (_) {
        verifyNever(
          () => service.generateForClips(
            clips: any(named: 'clips'),
            localeIdentifier: any(named: 'localeIdentifier'),
          ),
        );
      },
    );

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'startEmpty moves a failed session to ready with no cues',
      build: () {
        stubOutcome(const CaptionsFailed(CaptionGenerationFailure.failed));
        return build();
      },
      act: (cubit) async {
        await cubit.initialize();
        cubit.startEmpty();
      },
      skip: 1,
      expect: () => [
        isA<CaptionsEditorState>()
            .having((s) => s.status, 'status', CaptionsEditorStatus.ready)
            .having((s) => s.cues, 'cues', isEmpty),
      ],
    );

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'updateCueText replaces only the addressed cue',
      build: () => build(
        initialCues: const [
          cue,
          CaptionCue(
            id: 'cue-1',
            text: 'World.',
            start: Duration(seconds: 2),
            end: Duration(seconds: 3),
          ),
        ],
      ),
      act: (cubit) => cubit.updateCueText('cue-1', 'Divine.'),
      expect: () => [
        isA<CaptionsEditorState>().having(
          (s) => s.cues.map((c) => c.text).toList(),
          'texts',
          ['Hello.', 'Divine.'],
        ),
      ],
    );

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'removeCue drops the addressed cue',
      build: () => build(initialCues: const [cue]),
      act: (cubit) => cubit.removeCue('cue-0'),
      expect: () => [
        isA<CaptionsEditorState>().having((s) => s.cues, 'cues', isEmpty),
      ],
    );

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'addCue appends after the last cue, clamped to the video end',
      build: () => build(
        initialCues: const [
          CaptionCue(
            id: 'cue-0',
            text: 'Tail.',
            start: Duration(seconds: 4),
            end: Duration(seconds: 5),
          ),
        ],
      ),
      act: (cubit) => cubit.addCue(),
      expect: () => [
        isA<CaptionsEditorState>().having(
          (s) => s.cues.last,
          'new cue',
          isA<CaptionCue>()
              .having((c) => c.start, 'start', const Duration(seconds: 5))
              .having((c) => c.end, 'end', const Duration(seconds: 6))
              .having((c) => c.text, 'text', isEmpty),
        ),
      ],
    );

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'setPreset and setMode update the session',
      build: () => build(initialCues: const [cue]),
      act: (cubit) => cubit
        ..setPreset('pop')
        ..setMode(CaptionRenderMode.burnIn),
      expect: () => [
        isA<CaptionsEditorState>().having((s) => s.presetId, 'presetId', 'pop'),
        isA<CaptionsEditorState>().having(
          (s) => s.mode,
          'mode',
          CaptionRenderMode.burnIn,
        ),
      ],
    );

    test('track keeps cues only in overlay mode', () {
      final cubit = build(initialCues: const [cue])
        ..setMode(CaptionRenderMode.burnIn);
      addTearDown(cubit.close);

      expect(cubit.state.track.cues, isEmpty);

      cubit.setMode(CaptionRenderMode.overlay);
      expect(cubit.state.track.cues, equals(const [cue]));
    });
  });
}
