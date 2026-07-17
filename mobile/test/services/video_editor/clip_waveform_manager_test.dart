// ABOUTME: Unit tests for ClipWaveformManager.
// ABOUTME: Validates notifier lifecycle, per-path extraction reuse, and errors.

import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
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

    test(
      'publishes an empty waveform for a file with no audio track',
      () async {
        final silent = ClipWaveformManager(
          extractor: (path) async => throw const AudioNoTrackException(),
        );
        addTearDown(silent.dispose);

        silent.sync(
          clips: [_clip(id: 'a', path: '/tmp/silent.mp4')],
        );
        await pumpEventQueue();

        expect(silent['a'].value?.isEmpty, isTrue);
      },
    );

    test('does not retry a file that has no audio track', () async {
      var calls = 0;
      final silent = ClipWaveformManager(
        extractor: (path) async {
          calls++;
          throw const AudioNoTrackException();
        },
      );
      addTearDown(silent.dispose);

      silent.sync(
        clips: [_clip(id: 'a', path: '/tmp/silent.mp4')],
      );
      await pumpEventQueue();
      // Another clip resolving to the same file must serve the cached miss.
      silent.sync(
        clips: [_clip(id: 'b', path: '/tmp/silent.mp4')],
      );
      await pumpEventQueue();

      expect(calls, equals(1));
    });

    test('retries a transient extraction failure without a further sync', () {
      fakeAsync((async) {
        var calls = 0;
        final failing = ClipWaveformManager(
          extractor: (path) async {
            calls++;
            throw Exception('decoder busy');
          },
        );

        failing.sync(
          clips: [_clip(id: 'a', path: '/tmp/a.mp4')],
        );
        async.flushMicrotasks();
        expect(calls, equals(1));

        // A decoder busy under render contention says nothing about the file —
        // caching it as bandless would blank the clip for the whole session.
        // Contention peaks as the editor opens, and the strip only re-syncs
        // when its widget updates: an idle timeline owes us no second sync.
        async.elapse(const Duration(seconds: 2));
        expect(calls, equals(2));

        failing.dispose();
      });
    });

    test('gives up on a file that keeps failing', () {
      fakeAsync((async) {
        var calls = 0;
        final failing = ClipWaveformManager(
          extractor: (path) async {
            calls++;
            throw Exception('decoder busy');
          },
        );

        failing.sync(
          clips: [_clip(id: 'a', path: '/tmp/a.mp4')],
        );
        async.elapse(const Duration(minutes: 1));

        expect(calls, equals(3));
        expect(failing['a'].value?.isEmpty, isTrue);

        failing.dispose();
      });
    });

    test('stops retrying once its clip leaves the timeline', () {
      fakeAsync((async) {
        var calls = 0;
        final failing = ClipWaveformManager(
          extractor: (path) async {
            calls++;
            throw Exception('decoder busy');
          },
        );

        failing.sync(
          clips: [_clip(id: 'a', path: '/tmp/a.mp4')],
        );
        async.flushMicrotasks();
        expect(calls, equals(1));

        failing.sync(clips: []);
        async.elapse(const Duration(minutes: 1));

        // Nothing left to draw the bars on.
        expect(calls, equals(1));

        failing.dispose();
      });
    });

    test('extracts one file at a time', () {
      fakeAsync((async) {
        final gates = <String, Completer<WaveformData>>{
          '/tmp/a.mp4': Completer<WaveformData>(),
          '/tmp/b.mp4': Completer<WaveformData>(),
        };
        final started = <String>[];
        final serial = ClipWaveformManager(
          extractor: (path) {
            started.add(path);
            return gates[path]!.future;
          },
        );

        serial.sync(
          clips: [
            _clip(id: 'a', path: '/tmp/a.mp4'),
            _clip(id: 'b', path: '/tmp/b.mp4'),
          ],
        );
        async.flushMicrotasks();

        // The strip's thumbnail generator and the editor preview already
        // compete for the same hardware decoders — the second file waits.
        expect(started, equals(['/tmp/a.mp4']));

        gates['/tmp/a.mp4']!.complete(_waveform(left: [1]));
        async.flushMicrotasks();

        expect(started, equals(['/tmp/a.mp4', '/tmp/b.mp4']));

        gates['/tmp/b.mp4']!.complete(_waveform(left: [1]));
        async.flushMicrotasks();
        serial.dispose();
      });
    });

    test('skips extraction for a path no clip references anymore', () async {
      manager
        ..sync(
          clips: [_clip(id: 'a', path: '/tmp/a.mp4')],
        )
        ..sync(clips: []);
      await pumpEventQueue();

      expect(extractedPaths, isEmpty);
    });
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
