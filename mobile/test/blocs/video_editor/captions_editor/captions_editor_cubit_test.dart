// ABOUTME: Tests for the captions editor cubit.
// ABOUTME: Covers generation outcomes, cue editing, preset, and mode ops.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/captions_editor/captions_editor_cubit.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/services/video_editor/caption_generation_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode;

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

    group('updateCueTiming', () {
      const neighborCues = [
        cue,
        CaptionCue(
          id: 'cue-1',
          text: 'World.',
          start: Duration(seconds: 2),
          end: Duration(seconds: 3),
        ),
      ];

      blocTest<CaptionsEditorCubit, CaptionsEditorState>(
        'applies an in-range edit verbatim',
        build: () => build(initialCues: neighborCues),
        act: (cubit) => cubit.updateCueTiming(
          'cue-0',
          end: const Duration(milliseconds: 1500),
        ),
        expect: () => [
          isA<CaptionsEditorState>().having(
            (s) => s.cues.first.end,
            'end',
            const Duration(milliseconds: 1500),
          ),
        ],
      );

      blocTest<CaptionsEditorCubit, CaptionsEditorState>(
        'clamps the end only at the video duration (overlaps allowed)',
        build: () => build(initialCues: neighborCues),
        act: (cubit) => cubit
          // Extends past the next cue's start — allowed, cues may overlap.
          ..updateCueTiming('cue-0', end: const Duration(seconds: 5))
          // Extends past the video end — clamped to the total duration.
          ..updateCueTiming('cue-1', end: const Duration(seconds: 30)),
        expect: () => [
          isA<CaptionsEditorState>().having(
            (s) => s.cues.first.end,
            'end',
            const Duration(seconds: 5),
          ),
          isA<CaptionsEditorState>().having(
            (s) => s.cues.last.end,
            'end',
            const Duration(seconds: 6),
          ),
        ],
      );

      blocTest<CaptionsEditorCubit, CaptionsEditorState>(
        'clamps the start only at zero and the minimum duration',
        build: () => build(initialCues: neighborCues),
        act: (cubit) => cubit
          // Runs before the previous cue's end — allowed, cues may overlap.
          ..updateCueTiming('cue-1', start: Duration.zero)
          // Past its own end — clamped to end minus the minimum duration.
          ..updateCueTiming('cue-1', start: const Duration(seconds: 10)),
        expect: () => [
          isA<CaptionsEditorState>().having(
            (s) => s.cues.last.start,
            'start',
            Duration.zero,
          ),
          isA<CaptionsEditorState>().having(
            (s) => s.cues.last.start,
            'start',
            const Duration(milliseconds: 2800),
          ),
        ],
      );

      blocTest<CaptionsEditorCubit, CaptionsEditorState>(
        'ignores unknown cues and no-op edits',
        build: () => build(initialCues: const [cue]),
        act: (cubit) => cubit
          ..updateCueTiming('missing', start: Duration.zero)
          ..updateCueTiming('cue-0', start: Duration.zero),
        expect: () => const <CaptionsEditorState>[],
      );
    });

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'addCue appends after the last cue, back-shifting at the video end',
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
      // Only 1 s of tail is left, so the 2 s cue back-shifts to end at the
      // video end and overlaps the previous cue — overlaps are allowed.
      act: (cubit) => cubit.addCue(),
      expect: () => [
        isA<CaptionsEditorState>().having(
          (s) => s.cues.last,
          'new cue',
          isA<CaptionCue>()
              .having((c) => c.start, 'start', const Duration(seconds: 4))
              .having((c) => c.end, 'end', const Duration(seconds: 6))
              .having((c) => c.text, 'text', isEmpty),
        ),
      ],
    );

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'setPreset and setBurnIn update the session',
      build: () => build(initialCues: const [cue]),
      act: (cubit) => cubit
        ..setPreset('pop')
        ..setBurnIn(burnIn: true),
      expect: () => [
        isA<CaptionsEditorState>().having((s) => s.presetId, 'presetId', 'pop'),
        isA<CaptionsEditorState>().having((s) => s.burnIn, 'burnIn', true),
      ],
    );

    test('track keeps cues whether or not burned in', () {
      final cubit = build(initialCues: const [cue])..setBurnIn(burnIn: true);
      addTearDown(cubit.close);

      expect(cubit.state.track.burnIn, isTrue);
      expect(cubit.state.track.cues, equals(const [cue]));

      cubit.setBurnIn(burnIn: false);
      expect(cubit.state.track.burnIn, isFalse);
      expect(cubit.state.track.cues, equals(const [cue]));
    });

    const customStyle = CaptionCustomStyle(
      fontIndex: 2,
      color: Color(0xFFFF0000),
      background: Color(0x80000000),
      colorMode: LayerBackgroundMode.onlyColor,
      animation: CaptionAnimationStyle.spring,
    );

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'setCustomStyle applies the custom style',
      build: () => build(initialCues: const [cue]),
      act: (cubit) => cubit.setCustomStyle(customStyle),
      expect: () => [
        isA<CaptionsEditorState>()
            .having((s) => s.customStyle, 'customStyle', customStyle)
            .having((s) => s.hasCustomStyle, 'hasCustomStyle', true),
      ],
    );

    blocTest<CaptionsEditorCubit, CaptionsEditorState>(
      'setPreset clears an active custom style',
      build: () => build(initialCues: const [cue]),
      act: (cubit) => cubit
        ..setCustomStyle(customStyle)
        ..setPreset('mono'),
      expect: () => [
        isA<CaptionsEditorState>().having(
          (s) => s.customStyle,
          'customStyle',
          customStyle,
        ),
        isA<CaptionsEditorState>()
            .having((s) => s.customStyle, 'customStyle', isNull)
            .having((s) => s.presetId, 'presetId', 'mono'),
      ],
    );
  });
}
