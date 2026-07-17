// ABOUTME: Unit tests for ClipWaveformManager.
// ABOUTME: Validates notifier lifecycle, per-path extraction reuse, and errors.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/clip_waveform_manager.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(ClipWaveformManager, () {
    late List<String> extractedPaths;
    late ClipWaveformManager manager;

    setUp(() {
      extractedPaths = [];
      manager = ClipWaveformManager(
        extractor: (path) async {
          extractedPaths.add(path);
          return _waveform(left: [0.5, 1], right: [0.25, 0.75]);
        },
      );
    });

    tearDown(() => manager.dispose());

    test('publishes the extracted waveform to the clip notifier', () async {
      manager.sync(
        clips: [_clip(id: 'a', path: '/tmp/a.mp4')],
      );
      await pumpEventQueue();

      expect(manager['a'].value?.duration, equals(const Duration(seconds: 2)));
    });

    test('reduces stereo channels to the louder peak per sample', () async {
      manager.sync(
        clips: [_clip(id: 'a', path: '/tmp/a.mp4')],
      );
      await pumpEventQueue();

      // left [0.5, 1] vs right [0.25, 0.75] — the left channel wins both.
      expect(manager['a'].value?.peaks, equals([0.5, 1.0]));
    });

    test('reports the loudest sample as the peak', () async {
      final quiet = ClipWaveformManager(
        extractor: (_) async => _waveform(left: [0.1, 0.3, 0.2]),
      );
      addTearDown(quiet.dispose);

      quiet.sync(
        clips: [_clip(id: 'a', path: '/tmp/quiet.mp4')],
      );
      await pumpEventQueue();

      // The strip normalizes the band against this, so a quiet clip is still
      // drawn at full height.
      expect(quiet['a'].value?.peak, closeTo(0.3, 0.0001));
    });

    test('extracts once for two clips sharing a source file', () async {
      // The two halves of a trim-based split point at the same file.
      manager.sync(
        clips: [
          _clip(id: 'start', path: '/tmp/source.mp4'),
          _clip(id: 'end', path: '/tmp/source.mp4'),
        ],
      );
      await pumpEventQueue();

      expect(extractedPaths, equals(['/tmp/source.mp4']));
      expect(manager['start'].value, isNotNull);
      expect(manager['end'].value, isNotNull);
    });

    test('re-extracts when a clip is re-rendered to a new file', () async {
      manager.sync(
        clips: [_clip(id: 'a', path: '/tmp/a.mp4')],
      );
      await pumpEventQueue();

      manager.sync(
        clips: [_clip(id: 'a', path: '/tmp/a_reversed.mp4')],
      );
      await pumpEventQueue();

      expect(extractedPaths, equals(['/tmp/a.mp4', '/tmp/a_reversed.mp4']));
    });

    test('keeps the old waveform visible until the new one lands', () async {
      manager.sync(
        clips: [_clip(id: 'a', path: '/tmp/a.mp4')],
      );
      await pumpEventQueue();
      final previous = manager['a'].value;

      manager.sync(
        clips: [_clip(id: 'a', path: '/tmp/a_reversed.mp4')],
      );

      expect(manager['a'].value, same(previous));
    });

    test('serves a cached waveform without re-extracting', () async {
      manager.sync(
        clips: [_clip(id: 'a', path: '/tmp/a.mp4')],
      );
      await pumpEventQueue();

      // Undo/redo re-adds the clip under a fresh sync.
      manager.sync(
        clips: [_clip(id: 'b', path: '/tmp/b.mp4')],
      );
      await pumpEventQueue();
      manager.sync(
        clips: [_clip(id: 'a', path: '/tmp/a.mp4')],
      );
      await pumpEventQueue();

      expect(extractedPaths, equals(['/tmp/a.mp4', '/tmp/b.mp4']));
      expect(manager['a'].value, isNotNull);
    });

    test('leaves a clip without a source file alone', () async {
      manager.sync(clips: [_clipWithoutFile(id: 'pending')]);
      await pumpEventQueue();

      expect(extractedPaths, isEmpty);
      expect(manager['pending'].value, isNull);
    });

    test('removes notifiers for clips that are gone', () async {
      manager.sync(
        clips: [
          _clip(id: 'a', path: '/tmp/a.mp4'),
          _clip(id: 'b', path: '/tmp/b.mp4'),
        ],
      );

      manager.sync(
        clips: [_clip(id: 'a', path: '/tmp/a.mp4')],
      );

      expect(() => manager['b'], throwsA(isA<TypeError>()));
    });

    test('publishes an empty waveform when extraction fails', () async {
      final failing = ClipWaveformManager(
        extractor: (path) async => throw Exception('no audio track'),
      );
      addTearDown(failing.dispose);

      failing.sync(
        clips: [_clip(id: 'a', path: '/tmp/silent.mp4')],
      );
      await pumpEventQueue();

      expect(failing['a'].value?.isEmpty, isTrue);
    });

    test('does not retry a file whose extraction failed', () async {
      var calls = 0;
      final failing = ClipWaveformManager(
        extractor: (path) async {
          calls++;
          throw Exception('no audio track');
        },
      );
      addTearDown(failing.dispose);

      failing.sync(
        clips: [_clip(id: 'a', path: '/tmp/silent.mp4')],
      );
      await pumpEventQueue();
      failing.sync(
        clips: [_clip(id: 'b', path: '/tmp/silent.mp4')],
      );
      await pumpEventQueue();

      expect(calls, equals(1));
    });

    test(
      'drops a result whose clip left the timeline mid-extraction',
      () async {
        manager
          ..sync(
            clips: [_clip(id: 'a', path: '/tmp/a.mp4')],
          )
          ..sync(clips: []);
        await pumpEventQueue();

        expect(extractedPaths, isEmpty);
      },
    );
  });
}

WaveformData _waveform({
  required List<double> left,
  List<double>? right,
  Duration duration = const Duration(seconds: 2),
}) {
  return WaveformData(
    leftChannel: Float32List.fromList(left),
    rightChannel: right == null ? null : Float32List.fromList(right),
    sampleRate: 44100,
    duration: duration,
    samplesPerSecond: 200,
  );
}

DivineVideoClip _clip({required String id, required String path}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file(path),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: model.AspectRatio.vertical,
  );
}

DivineVideoClip _clipWithoutFile({required String id}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.network('https://example.com/pending.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: model.AspectRatio.vertical,
  );
}
