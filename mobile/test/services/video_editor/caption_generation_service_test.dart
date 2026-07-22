// ABOUTME: Tests for the caption generation service.
// ABOUTME: Covers timeline mapping, clip skipping, failures, and cleanup.

import 'package:caption_generator/caption_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/video_editor/caption_generation_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockAudioExtractionService extends Mock
    implements AudioExtractionService {}

class _MockCaptionGenerator extends Mock implements CaptionGenerator {}

DivineVideoClip _clip(
  String id, {
  Duration duration = const Duration(seconds: 3),
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
  double volume = 1,
  double? playbackSpeed,
  bool withVideo = true,
}) => DivineVideoClip(
  id: id,
  // A network-only video has no local file, so it cannot be transcribed.
  video: withVideo
      ? EditorVideo.file('/tmp/$id.mp4')
      : EditorVideo.network('https://example.com/$id.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  trimStart: trimStart,
  trimEnd: trimEnd,
  volume: volume,
  playbackSpeed: playbackSpeed,
);

AudioExtractionResult _extraction(String path) => AudioExtractionResult(
  audioFilePath: path,
  duration: 3,
  fileSize: 1,
  sha256Hash: 'hash',
  mimeType: 'audio/wav',
);

CaptionSegment _word(String text, int startMs, int endMs) => CaptionSegment(
  text: text,
  start: Duration(milliseconds: startMs),
  end: Duration(milliseconds: endMs),
);

void main() {
  group(CaptionGenerationService, () {
    late _MockAudioExtractionService extraction;
    late _MockCaptionGenerator generator;
    late CaptionGenerationService service;

    setUp(() {
      extraction = _MockAudioExtractionService();
      generator = _MockCaptionGenerator();
      service = CaptionGenerationService(
        audioExtractionService: extraction,
        captionGenerator: generator,
      );
      when(() => extraction.cleanupAudioFile(any())).thenAnswer((_) async {});
    });

    void stubExtraction() {
      when(
        () => extraction.extractAudio(
          videoPath: any(named: 'videoPath'),
          speed: any(named: 'speed'),
        ),
      ).thenAnswer(
        (invocation) async => _extraction(
          '${invocation.namedArguments[#videoPath]}.wav',
        ),
      );
    }

    test('maps words from consecutive clips onto the timeline', () async {
      stubExtraction();
      when(
        () => generator.generateCaptions(
          audioPath: '/tmp/a.mp4.wav',
          localeIdentifier: any(named: 'localeIdentifier'),
        ),
      ).thenAnswer((_) async => [_word('First.', 0, 500)]);
      when(
        () => generator.generateCaptions(
          audioPath: '/tmp/b.mp4.wav',
          localeIdentifier: any(named: 'localeIdentifier'),
        ),
      ).thenAnswer((_) async => [_word('Second.', 100, 700)]);

      final outcome = await service.generateForClips(
        clips: [_clip('a'), _clip('b')],
        localeIdentifier: 'en-US',
      );

      final cues = (outcome as CaptionsGenerated).cues;
      expect(cues, hasLength(2));
      expect(cues.first.text, equals('First.'));
      expect(cues.first.start, equals(Duration.zero));
      // Clip b starts after clip a's 3s playback duration.
      expect(cues.last.text, equals('Second.'));
      expect(cues.last.start, equals(const Duration(milliseconds: 3100)));
      expect(cues.last.end, equals(const Duration(milliseconds: 3700)));
    });

    test('windows words to the clip trim range and shifts them', () async {
      stubExtraction();
      when(
        () => generator.generateCaptions(
          audioPath: any(named: 'audioPath'),
          localeIdentifier: any(named: 'localeIdentifier'),
        ),
      ).thenAnswer(
        (_) async => [
          // Entirely before the 1s trim window: dropped.
          _word('Cut', 0, 800),
          // Inside the window: shifted to timeline zero base.
          _word('Kept.', 1200, 1800),
        ],
      );

      final outcome = await service.generateForClips(
        clips: [
          _clip('a', trimStart: const Duration(seconds: 1)),
        ],
        localeIdentifier: 'en-US',
      );

      final cues = (outcome as CaptionsGenerated).cues;
      expect(cues.single.text, equals('Kept.'));
      expect(cues.single.start, equals(const Duration(milliseconds: 200)));
      expect(cues.single.end, equals(const Duration(milliseconds: 800)));
    });

    test('extracts at the clip playback speed', () async {
      stubExtraction();
      when(
        () => generator.generateCaptions(
          audioPath: any(named: 'audioPath'),
          localeIdentifier: any(named: 'localeIdentifier'),
        ),
      ).thenAnswer((_) async => [_word('Fast.', 0, 400)]);

      await service.generateForClips(
        clips: [_clip('a', playbackSpeed: 2)],
        localeIdentifier: 'en-US',
      );

      verify(
        () => extraction.extractAudio(
          videoPath: '/tmp/a.mp4',
          speed: 2,
        ),
      ).called(1);
    });

    test('skips muted clips and clips without a local file', () async {
      final outcome = await service.generateForClips(
        clips: [_clip('muted', volume: 0), _clip('remote', withVideo: false)],
        localeIdentifier: 'en-US',
      );

      expect(outcome, isA<CaptionsEmpty>());
      verifyNever(
        () => extraction.extractAudio(
          videoPath: any(named: 'videoPath'),
          speed: any(named: 'speed'),
        ),
      );
    });

    test('skips clips without an audio track and keeps going', () async {
      when(
        () => extraction.extractAudio(
          videoPath: '/tmp/silent.mp4',
          speed: any(named: 'speed'),
        ),
      ).thenThrow(const AudioExtractionException('Video has no audio track'));
      when(
        () => extraction.extractAudio(
          videoPath: '/tmp/voiced.mp4',
          speed: any(named: 'speed'),
        ),
      ).thenAnswer((_) async => _extraction('/tmp/voiced.mp4.wav'));
      when(
        () => generator.generateCaptions(
          audioPath: '/tmp/voiced.mp4.wav',
          localeIdentifier: any(named: 'localeIdentifier'),
        ),
      ).thenAnswer((_) async => [_word('Hello.', 0, 500)]);

      final outcome = await service.generateForClips(
        clips: [_clip('silent'), _clip('voiced')],
        localeIdentifier: 'en-US',
      );

      final cues = (outcome as CaptionsGenerated).cues;
      // The silent clip still occupies its 3s on the timeline.
      expect(cues.single.start, equals(const Duration(seconds: 3)));
    });

    test('fails on other extraction errors', () async {
      when(
        () => extraction.extractAudio(
          videoPath: any(named: 'videoPath'),
          speed: any(named: 'speed'),
        ),
      ).thenThrow(const AudioExtractionException('Extraction failed'));

      final outcome = await service.generateForClips(
        clips: [_clip('a')],
        localeIdentifier: 'en-US',
      );

      expect(
        (outcome as CaptionsFailed).reason,
        equals(CaptionGenerationFailure.failed),
      );
    });

    group('maps transcription exceptions to failure reasons', () {
      final cases = <CaptionGenerationException, CaptionGenerationFailure>{
        const SpeechRecognizerUnavailableException('no recognizer'):
            CaptionGenerationFailure.recognizerUnavailable,
        const SpeechNotAuthorizedException():
            CaptionGenerationFailure.notAuthorized,
        const UnsupportedAudioFormatException('bad wav'):
            CaptionGenerationFailure.unsupportedAudio,
        const TranscriptionFailedException('boom'):
            CaptionGenerationFailure.failed,
      };

      for (final MapEntry(key: exception, value: reason) in cases.entries) {
        test(reason.name, () async {
          stubExtraction();
          when(
            () => generator.generateCaptions(
              audioPath: any(named: 'audioPath'),
              localeIdentifier: any(named: 'localeIdentifier'),
            ),
          ).thenThrow(exception);

          final outcome = await service.generateForClips(
            clips: [_clip('a')],
            localeIdentifier: 'en-US',
          );

          expect((outcome as CaptionsFailed).reason, equals(reason));
          // The extracted WAV is cleaned up even on failure.
          verify(() => extraction.cleanupAudioFile('/tmp/a.mp4.wav')).called(1);
        });
      }
    });

    test('cleans up the extracted WAV after a successful run', () async {
      stubExtraction();
      when(
        () => generator.generateCaptions(
          audioPath: any(named: 'audioPath'),
          localeIdentifier: any(named: 'localeIdentifier'),
        ),
      ).thenAnswer((_) async => [_word('Hello.', 0, 500)]);

      await service.generateForClips(
        clips: [_clip('a')],
        localeIdentifier: 'en-US',
      );

      verify(() => extraction.cleanupAudioFile('/tmp/a.mp4.wav')).called(1);
    });

    test('returns empty when no speech is recognized', () async {
      stubExtraction();
      when(
        () => generator.generateCaptions(
          audioPath: any(named: 'audioPath'),
          localeIdentifier: any(named: 'localeIdentifier'),
        ),
      ).thenAnswer((_) async => const []);

      final outcome = await service.generateForClips(
        clips: [_clip('a')],
        localeIdentifier: 'en-US',
      );

      expect(outcome, isA<CaptionsEmpty>());
    });

    test(
      'groups words into sentence cues and clamps to total duration',
      () async {
        stubExtraction();
        when(
          () => generator.generateCaptions(
            audioPath: any(named: 'audioPath'),
            localeIdentifier: any(named: 'localeIdentifier'),
          ),
        ).thenAnswer(
          (_) async => [
            _word('Hello', 0, 400),
            _word('there.', 450, 900),
            _word('Bye.', 1000, 1400),
          ],
        );

        final outcome = await service.generateForClips(
          clips: [_clip('a')],
          localeIdentifier: 'en-US',
        );

        final cues = (outcome as CaptionsGenerated).cues;
        expect(cues, hasLength(2));
        expect(cues.first.text, equals('Hello there.'));
        expect(cues.first.id, equals('cue-0'));
        expect(cues.last.text, equals('Bye.'));
        expect(cues.last.id, equals('cue-1'));
      },
    );
  });
}
