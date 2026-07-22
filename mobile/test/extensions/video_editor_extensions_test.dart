import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

DivineVideoClip _clip(
  String id, {
  Duration duration = const Duration(seconds: 3),
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/tmp/$id.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

void main() {
  late _MockProImageEditorState editor;
  late _MockStateManager stateManager;

  setUp(() {
    editor = _MockProImageEditorState();
    stateManager = _MockStateManager();

    when(() => editor.stateManager).thenReturn(stateManager);
    when(
      () => editor.addHistory(
        layers: any(named: 'layers'),
        filters: any(named: 'filters'),
        meta: any(named: 'meta'),
        newLayer: any(named: 'newLayer'),
        transformConfigs: any(named: 'transformConfigs'),
        tuneAdjustments: any(named: 'tuneAdjustments'),
        blur: any(named: 'blur'),
        heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
        blockCaptureScreenshot: any(named: 'blockCaptureScreenshot'),
      ),
    ).thenAnswer((_) {});
    when(() => editor.setState(any())).thenAnswer((invocation) {
      final callback = invocation.positionalArguments.single as VoidCallback;
      callback();
    });
  });

  group('VideoEditorExtensions', () {
    test('setClipState carries current timeline markers by default', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.timelineMarkersStateHistoryKey: [1200, 2400],
      });

      editor.setClipState([_clip('clip-1')]);

      final meta =
          verify(
                () => editor.addHistory(meta: captureAny(named: 'meta')),
              ).captured.single
              as Map<String, dynamic>;

      expect(
        meta[VideoEditorConstants.timelineMarkersStateHistoryKey],
        equals([1200, 2400]),
      );
      expect(
        meta[VideoEditorConstants.clipsStateHistoryKey],
        isA<List<dynamic>>().having((clips) => clips.length, 'length', 1),
      );
    });

    test('setClipAndAudioState carries current markers atomically', () {
      const audio = AudioEvent(id: 'audio-1', pubkey: 'pub', createdAt: 1);
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.timelineMarkersStateHistoryKey: [1500],
      });

      editor.setClipAndAudioState(
        clips: [_clip('clip-1')],
        audioTracks: const [audio],
      );

      final meta =
          verify(
                () => editor.addHistory(meta: captureAny(named: 'meta')),
              ).captured.single
              as Map<String, dynamic>;

      expect(
        meta[VideoEditorConstants.timelineMarkersStateHistoryKey],
        equals([1500]),
      );
      expect(
        meta[VideoEditorConstants.audioStateHistoryKey],
        equals([audio.toJson()]),
      );
      expect(
        meta[VideoEditorConstants.clipsStateHistoryKey],
        isA<List<dynamic>>().having((clips) => clips.length, 'length', 1),
      );
    });

    group('setLengthenedClipState', () {
      // #6401 on the content-added path: a sound clamped to a 3s composition
      // when it was added, then the user shoots more stills from the editor's
      // camera (or merges a set in from the clips picker) and the composition
      // becomes 6s. Without the grow, publish muxes a 6s video with 3s audio.
      const covering = AudioEvent(
        id: 'sound-1',
        pubkey: 'bundled',
        createdAt: 0,
        url: 'asset://sounds/loop.mp3',
        duration: 30,
        endTime: Duration(seconds: 3),
      );

      List<AudioEvent> capturedAudio() {
        final meta =
            verify(
                  () => editor.addHistory(meta: captureAny(named: 'meta')),
                ).captured.single
                as Map<String, dynamic>;
        final raw =
            meta[VideoEditorConstants.audioStateHistoryKey] as List<dynamic>;
        return raw
            .cast<Map<String, dynamic>>()
            .map(AudioEvent.fromJson)
            .toList();
      }

      test('grows a sound that covered the old end onto the added clip', () {
        when(() => stateManager.activeMeta).thenReturn({
          VideoEditorConstants.audioStateHistoryKey: [covering.toJson()],
        });

        editor.setLengthenedClipState(
          previousClips: [_clip('clip-1')],
          clips: [_clip('clip-1'), _clip('clip-2')],
        );

        expect(capturedAudio().single.endTime, const Duration(seconds: 6));
      });

      test('leaves a sound the user trimmed short of the old end', () {
        const trimmed = AudioEvent(
          id: 'sound-1',
          pubkey: 'bundled',
          createdAt: 0,
          url: 'asset://sounds/loop.mp3',
          duration: 30,
          endTime: Duration(seconds: 1),
        );
        when(() => stateManager.activeMeta).thenReturn({
          VideoEditorConstants.audioStateHistoryKey: [trimmed.toJson()],
        });

        editor.setLengthenedClipState(
          previousClips: [_clip('clip-1')],
          clips: [_clip('clip-1'), _clip('clip-2')],
        );

        expect(capturedAudio().single.endTime, const Duration(seconds: 1));
      });

      test('writes no audio key when the composition has no sound', () {
        when(() => stateManager.activeMeta).thenReturn({});

        editor.setLengthenedClipState(
          previousClips: [_clip('clip-1')],
          clips: [_clip('clip-1'), _clip('clip-2')],
        );

        final meta =
            verify(
                  () => editor.addHistory(meta: captureAny(named: 'meta')),
                ).captured.single
                as Map<String, dynamic>;
        expect(
          meta.containsKey(VideoEditorConstants.audioStateHistoryKey),
          isFalse,
        );
      });
    });

    test('setClipState updates current markers when skipping history', () {
      final activeMeta = <String, dynamic>{
        VideoEditorConstants.timelineMarkersStateHistoryKey: [900],
      };
      when(() => stateManager.activeMeta).thenReturn(activeMeta);

      editor.setClipState([_clip('clip-1')], skipUpdateHistory: true);

      expect(
        activeMeta[VideoEditorConstants.timelineMarkersStateHistoryKey],
        equals([900]),
      );
      expect(
        activeMeta[VideoEditorConstants.clipsStateHistoryKey],
        isA<List<dynamic>>().having((clips) => clips.length, 'length', 1),
      );
      verifyNever(() => editor.addHistory(meta: any(named: 'meta')));
    });
  });

  group('buildAppendedAudioMeta', () {
    const existing = AudioEvent(id: 'existing', pubkey: 'p', createdAt: 1);
    const incoming = AudioEvent(id: 'incoming', pubkey: 'p', createdAt: 2);

    test('appends new tracks after existing ones and carries other meta', () {
      final meta = buildAppendedAudioMeta(
        activeMeta: {
          VideoEditorConstants.timelineMarkersStateHistoryKey: [1200],
        },
        existingTracks: const [existing],
        newTracks: const [incoming],
      );

      expect(
        meta[VideoEditorConstants.timelineMarkersStateHistoryKey],
        equals([1200]),
      );
      expect(
        meta[VideoEditorConstants.audioStateHistoryKey],
        equals([existing.toJson(), incoming.toJson()]),
      );
    });

    test('overwrites any prior audio key in activeMeta', () {
      final meta = buildAppendedAudioMeta(
        activeMeta: {
          VideoEditorConstants.audioStateHistoryKey: ['stale'],
        },
        existingTracks: const [existing],
        newTracks: const [incoming],
      );

      expect(
        meta[VideoEditorConstants.audioStateHistoryKey],
        equals([existing.toJson(), incoming.toJson()]),
      );
    });

    test('keeps the existing tracks when no new tracks are appended', () {
      final meta = buildAppendedAudioMeta(
        activeMeta: const {},
        existingTracks: const [existing],
        newTracks: const [],
      );

      expect(
        meta[VideoEditorConstants.audioStateHistoryKey],
        equals([existing.toJson()]),
      );
    });
  });

  group('captions', () {
    const cue = CaptionCue(
      id: 'cue-1',
      text: 'Hello.',
      start: Duration(milliseconds: 500),
      end: Duration(milliseconds: 2000),
    );
    const track = CaptionTrack(
      mode: CaptionRenderMode.overlay,
      presetId: 'classic',
      languageTag: 'en-US',
      cues: [cue],
    );

    Map<String, dynamic> capturedHistoryMeta() =>
        verify(
              () => editor.addHistory(meta: captureAny(named: 'meta')),
            ).captured.single
            as Map<String, dynamic>;

    test('setCaptionState writes the track as one history entry', () {
      when(() => stateManager.activeMeta).thenReturn({'other': 1});

      editor.setCaptionState(track);

      final meta = capturedHistoryMeta();
      expect(
        meta[VideoEditorConstants.captionsStateHistoryKey],
        equals(track.toJson()),
      );
      expect(meta['other'], equals(1));
    });

    test('setCaptionState with null removes the track', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });

      editor.setCaptionState(null);

      final meta = capturedHistoryMeta();
      expect(
        meta.containsKey(VideoEditorConstants.captionsStateHistoryKey),
        isFalse,
      );
    });

    test('captionTrack getter restores the track and null on malformed', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });
      expect(stateManager.captionTrack, equals(track));

      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: {'presetId': 42},
      });
      expect(stateManager.captionTrack, isNull);

      when(() => stateManager.activeMeta).thenReturn({});
      expect(stateManager.captionTrack, isNull);
    });

    test('setCaptionCueTimeline retimes the cue as a history entry', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });

      editor.setCaptionCueTimeline(
        cueId: 'cue-1',
        startTime: const Duration(milliseconds: 800),
      );

      final meta = capturedHistoryMeta();
      final updated = CaptionTrack.fromJson(
        meta[VideoEditorConstants.captionsStateHistoryKey]
            as Map<Object?, Object?>,
      );
      expect(
        updated.cues.single.start,
        equals(const Duration(milliseconds: 800)),
      );
      expect(
        updated.cues.single.end,
        equals(const Duration(milliseconds: 2000)),
      );
    });

    test('setCaptionCueTimeline mutates meta in-place during drags', () {
      final activeMeta = <String, dynamic>{
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      };
      when(() => stateManager.activeMeta).thenReturn(activeMeta);

      editor.setCaptionCueTimeline(
        cueId: 'cue-1',
        endTime: const Duration(milliseconds: 1500),
        skipUpdateHistory: true,
      );

      verifyNever(() => editor.addHistory(meta: any(named: 'meta')));
      final updated = CaptionTrack.fromJson(
        activeMeta[VideoEditorConstants.captionsStateHistoryKey]
            as Map<Object?, Object?>,
      );
      expect(
        updated.cues.single.end,
        equals(const Duration(milliseconds: 1500)),
      );
    });

    test('setCaptionCueTimeline clamps below the minimum cue duration', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });

      // Right-trim towards the start: end is clamped to start + minimum.
      editor.setCaptionCueTimeline(
        cueId: 'cue-1',
        endTime: const Duration(milliseconds: 510),
      );

      final meta = capturedHistoryMeta();
      final updated = CaptionTrack.fromJson(
        meta[VideoEditorConstants.captionsStateHistoryKey]
            as Map<Object?, Object?>,
      );
      expect(
        updated.cues.single.end - updated.cues.single.start,
        equals(VideoEditorConstants.minCaptionCueDuration),
      );
    });

    test('setCaptionCueTimeline ignores unknown cues and missing tracks', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });
      editor.setCaptionCueTimeline(cueId: 'nope', startTime: Duration.zero);

      when(() => stateManager.activeMeta).thenReturn({});
      editor.setCaptionCueTimeline(cueId: 'cue-1', startTime: Duration.zero);

      verifyNever(() => editor.addHistory(meta: any(named: 'meta')));
    });
  });
}
