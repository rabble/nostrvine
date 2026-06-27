import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/tmp/$id.mp4'),
  duration: const Duration(seconds: 3),
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
}
