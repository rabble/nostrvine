import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

void main() {
  // At the default 24fps base, one output frame is 1/24s.
  Duration hold(int framesPerImage) => Duration(
    microseconds:
        (framesPerImage *
                Duration.microsecondsPerSecond /
                StopMotionRenderService.defaultFrameRate)
            .round(),
  );

  List<StopMotionClipFrame> framesOf(List<int> holds) => [
    for (var i = 0; i < holds.length; i++)
      StopMotionClipFrame(path: 'f$i.jpg', duration: hold(holds[i])),
  ];

  group('framesPerImageToDuration / durationToFramesPerImage', () {
    test('round-trips every valid frames-per-image value', () {
      for (var n = 1; n <= 10; n++) {
        expect(
          StopMotionFrameOps.durationToFramesPerImage(
            StopMotionFrameOps.framesPerImageToDuration(n),
          ),
          n,
        );
      }
    });

    test('clamps out-of-range frames-per-image to the valid bounds', () {
      expect(
        StopMotionFrameOps.framesPerImageToDuration(0),
        StopMotionFrameOps.framesPerImageToDuration(1),
      );
      expect(
        StopMotionFrameOps.framesPerImageToDuration(
          StopMotionFrameOps.maxFramesPerImage + 1,
        ),
        StopMotionFrameOps.framesPerImageToDuration(
          StopMotionFrameOps.maxFramesPerImage,
        ),
      );
    });
  });

  group('initialFramesPerImage / initialHold', () {
    test('holds a lone still for the whole minimum duration', () {
      expect(
        StopMotionFrameOps.initialHold(1),
        StopMotionFrameOps.minimumInitialDuration,
      );
    });

    test('a session of any size fills at least the minimum duration', () {
      // Asserted on summed *duration*, which is what the editor's Done gate
      // compares — counting output frames instead hides the rounding in
      // framesPerImageToDuration (3 and 12 stills land 1µs and 4µs short).
      for (var frameCount = 1; frameCount <= 40; frameCount++) {
        expect(
          StopMotionFrameOps.initialHold(frameCount) * frameCount,
          greaterThanOrEqualTo(StopMotionFrameOps.minimumInitialDuration),
          reason: '$frameCount still(s) fall short of the minimum',
        );
      }
    });

    test('keeps the default hold once the stills fill it on their own', () {
      expect(
        StopMotionFrameOps.initialFramesPerImage(24),
        StopMotionFrameOps.defaultFramesPerImage,
      );
      expect(
        StopMotionFrameOps.initialFramesPerImage(100),
        StopMotionFrameOps.defaultFramesPerImage,
      );
    });

    test('falls back to the default hold for an empty session', () {
      expect(
        StopMotionFrameOps.initialFramesPerImage(0),
        StopMotionFrameOps.defaultFramesPerImage,
      );
    });
  });

  group('removeFrame', () {
    test('removes the frame at the index', () {
      final result = StopMotionFrameOps.removeFrame(framesOf([1, 1, 1]), 1);
      expect(result.map((f) => f.path), ['f0.jpg', 'f2.jpg']);
    });

    test('keeps at least one frame (a clip cannot be emptied)', () {
      final single = framesOf([1]);
      expect(StopMotionFrameOps.removeFrame(single, 0), same(single));
    });

    test('returns the list unchanged for an out-of-range index', () {
      final frames = framesOf([1, 1]);
      expect(StopMotionFrameOps.removeFrame(frames, 5), same(frames));
    });
  });

  group('reorderFrame', () {
    test('moves a frame forward', () {
      final result = StopMotionFrameOps.reorderFrame(framesOf([1, 1, 1]), 0, 2);
      expect(result.map((f) => f.path), ['f1.jpg', 'f2.jpg', 'f0.jpg']);
    });

    test('returns the list unchanged when from == to', () {
      final frames = framesOf([1, 1, 1]);
      expect(StopMotionFrameOps.reorderFrame(frames, 1, 1), same(frames));
    });
  });

  group('removeFrames', () {
    test('removes every still at the given indexes', () {
      final result = StopMotionFrameOps.removeFrames(framesOf([1, 1, 1, 1]), {
        1,
        3,
      });
      expect(result.map((f) => f.path), ['f0.jpg', 'f2.jpg']);
    });

    test('keeps at least one still (cannot empty the clip)', () {
      final frames = framesOf([1, 1]);
      expect(StopMotionFrameOps.removeFrames(frames, {0, 1}), same(frames));
    });

    test('returns the list unchanged for out-of-range indexes', () {
      final frames = framesOf([1, 1]);
      expect(StopMotionFrameOps.removeFrames(frames, {0, 5}), same(frames));
    });

    test('returns the list unchanged for an empty selection', () {
      final frames = framesOf([1, 1]);
      expect(StopMotionFrameOps.removeFrames(frames, const {}), same(frames));
    });
  });

  group('reverseFrames', () {
    test('reverses the selected stills among their own slots', () {
      // Select 0, 2, 3 of [f0, f1, f2, f3]: the selected slots keep their
      // positions but receive the selected stills in reverse order.
      final result = StopMotionFrameOps.reverseFrames(
        framesOf([
          1,
          1,
          1,
          1,
        ]),
        {0, 2, 3},
      );
      expect(result.map((f) => f.path), [
        'f3.jpg',
        'f1.jpg',
        'f2.jpg',
        'f0.jpg',
      ]);
    });

    test('returns the list unchanged for fewer than two selected', () {
      final frames = framesOf([1, 1]);
      expect(StopMotionFrameOps.reverseFrames(frames, {0}), same(frames));
    });

    test('returns the list unchanged for out-of-range indexes', () {
      final frames = framesOf([1, 1]);
      expect(StopMotionFrameOps.reverseFrames(frames, {0, 5}), same(frames));
    });
  });

  group('moveFrames', () {
    test('moves the selected stills as one block to the slot', () {
      // Select f0 + f1, insert at slot 2 of the remaining [f2, f3].
      final result = StopMotionFrameOps.moveFrames(
        framesOf([
          1,
          1,
          1,
          1,
        ]),
        {0, 1},
        2,
      );
      expect(result.map((f) => f.path), [
        'f2.jpg',
        'f3.jpg',
        'f0.jpg',
        'f1.jpg',
      ]);
    });

    test(
      "keeps the block's relative order for a non-contiguous selection",
      () {
        // Select f0 + f2, insert at slot 1 of the remaining [f1, f3].
        final result = StopMotionFrameOps.moveFrames(
          framesOf([
            1,
            1,
            1,
            1,
          ]),
          {0, 2},
          1,
        );
        expect(result.map((f) => f.path), [
          'f1.jpg',
          'f0.jpg',
          'f2.jpg',
          'f3.jpg',
        ]);
      },
    );

    test('clamps the slot to the remaining list bounds', () {
      final result = StopMotionFrameOps.moveFrames(framesOf([1, 1, 1]), {
        0,
      }, 99);
      expect(result.map((f) => f.path), ['f1.jpg', 'f2.jpg', 'f0.jpg']);
    });

    test('returns the same instance for a no-op move', () {
      final frames = framesOf([1, 1, 1]);
      expect(StopMotionFrameOps.moveFrames(frames, {0}, 0), same(frames));
    });

    test('returns the list unchanged for an empty or invalid selection', () {
      final frames = framesOf([1, 1]);
      expect(StopMotionFrameOps.moveFrames(frames, const {}, 1), same(frames));
      expect(StopMotionFrameOps.moveFrames(frames, {5}, 1), same(frames));
    });
  });

  group('setFramesHold', () {
    test('sets the hold on every selected still and marks it overridden', () {
      final result = StopMotionFrameOps.setFramesHold(
        framesOf([1, 1, 1]),
        {0, 2},
        4,
      );

      expect(
        result.map(
          (f) => StopMotionFrameOps.durationToFramesPerImage(f.duration),
        ),
        [4, 1, 4],
      );
      expect(result.map((f) => f.holdOverridden), [true, false, true]);
    });

    test('returns the list unchanged for an empty selection', () {
      final frames = framesOf([1, 1]);
      expect(
        StopMotionFrameOps.setFramesHold(frames, const {}, 4),
        same(frames),
      );
    });

    test('returns the source list when no selected hold actually changes', () {
      final frames = [
        const StopMotionClipFrame(
          path: 'f0.jpg',
          duration: Duration(microseconds: 166667), // 4 frames @ 24fps
          holdOverridden: true,
        ),
        StopMotionClipFrame(path: 'f1.jpg', duration: hold(1)),
      ];
      // Re-selecting the same hold on the already-overridden still is a no-op,
      // so the source instance is returned and the commit's identical guard
      // skips a redundant history entry.
      expect(StopMotionFrameOps.setFramesHold(frames, {0}, 4), same(frames));
    });
  });

  group('insertIndexAtPosition', () {
    final frames = framesOf([1, 1, 1]); // three 1/24s stills

    test('prepends at (or before) the start', () {
      expect(
        StopMotionFrameOps.insertIndexAtPosition(frames, Duration.zero),
        0,
      );
      expect(
        StopMotionFrameOps.insertIndexAtPosition(
          frames,
          const Duration(seconds: -1),
        ),
        0,
      );
    });

    test('inserts after the still under the playhead', () {
      // Inside frame 0 → after it.
      expect(
        StopMotionFrameOps.insertIndexAtPosition(frames, hold(1) ~/ 2),
        1,
      );
      // Inside frame 1 → after it.
      expect(
        StopMotionFrameOps.insertIndexAtPosition(
          frames,
          hold(1) + hold(1) ~/ 2,
        ),
        2,
      );
    });

    test('appends at or past the end', () {
      expect(
        StopMotionFrameOps.insertIndexAtPosition(frames, hold(3)),
        3,
      );
      expect(
        StopMotionFrameOps.insertIndexAtPosition(frames, hold(10)),
        3,
      );
    });
  });

  group('insertFramesAt', () {
    test('splices frames in at the index', () {
      final result = StopMotionFrameOps.insertFramesAt(
        framesOf([1, 1]),
        1,
        framesOf([2, 2]),
      );
      expect(result.map((f) => f.path), [
        'f0.jpg',
        'f0.jpg',
        'f1.jpg',
        'f1.jpg',
      ]);
    });

    test('clamps an out-of-range index to the end', () {
      final result = StopMotionFrameOps.insertFramesAt(
        framesOf([1, 1]),
        99,
        framesOf([2]),
      );
      expect(result, hasLength(3));
      expect(result.last.duration, hold(2));
    });

    test('returns the list unchanged for an empty insert', () {
      final frames = framesOf([1, 1]);
      expect(
        StopMotionFrameOps.insertFramesAt(frames, 1, const []),
        same(frames),
      );
    });
  });

  group('setFrameHold / setGlobalHold', () {
    test('sets only the targeted frame hold and marks it overridden', () {
      final result = StopMotionFrameOps.setFrameHold(framesOf([1, 1, 1]), 1, 4);
      expect(
        StopMotionFrameOps.durationToFramesPerImage(result[0].duration),
        1,
      );
      expect(
        StopMotionFrameOps.durationToFramesPerImage(result[1].duration),
        4,
      );
      expect(
        StopMotionFrameOps.durationToFramesPerImage(result[2].duration),
        1,
      );
      expect(result[1].holdOverridden, isTrue);
      expect(result[0].holdOverridden, isFalse);
    });

    test('sets every non-overridden frame hold', () {
      final result = StopMotionFrameOps.setGlobalHold(framesOf([1, 2, 3]), 5);
      expect(
        result.every(
          (f) => StopMotionFrameOps.durationToFramesPerImage(f.duration) == 5,
        ),
        isTrue,
      );
    });

    test('global hold leaves individually overridden frames untouched', () {
      // Override the middle frame to 8, then apply a global default of 2.
      final overridden = StopMotionFrameOps.setFrameHold(
        framesOf([1, 1, 1]),
        1,
        8,
      );
      final result = StopMotionFrameOps.setGlobalHold(overridden, 2);

      expect(
        StopMotionFrameOps.durationToFramesPerImage(result[0].duration),
        2,
      );
      expect(
        StopMotionFrameOps.durationToFramesPerImage(result[1].duration),
        8,
      );
      expect(
        StopMotionFrameOps.durationToFramesPerImage(result[2].duration),
        2,
      );
      // The override flag survives a global change.
      expect(result[1].holdOverridden, isTrue);
    });

    test('setFrameHold returns the source list when nothing changes', () {
      // Already overridden to 4; re-applying 4 is a no-op.
      final frames = StopMotionFrameOps.setFrameHold(framesOf([1, 1, 1]), 1, 4);
      expect(StopMotionFrameOps.setFrameHold(frames, 1, 4), same(frames));
    });

    test('setGlobalHold returns the source list when nothing changes', () {
      // Every still already holds 2 and none is overridden.
      final frames = framesOf([2, 2, 2]);
      expect(StopMotionFrameOps.setGlobalHold(frames, 2), same(frames));
    });
  });

  group('globalDefaultFramesPerImage', () {
    test('returns the shared value of non-overridden frames', () {
      expect(
        StopMotionFrameOps.globalDefaultFramesPerImage(framesOf([3, 3, 3])),
        3,
      );
    });

    test('ignores overridden frames', () {
      final frames = StopMotionFrameOps.setFrameHold(framesOf([2, 2, 2]), 1, 9);
      // Frame 1 is overridden to 9; the default of the rest is still 2.
      expect(StopMotionFrameOps.globalDefaultFramesPerImage(frames), 2);
    });

    test(
      'falls back to the most common hold when non-overridden frames '
      'disagree',
      () {
        expect(
          StopMotionFrameOps.globalDefaultFramesPerImage(
            framesOf([2, 2, 1, 2]),
          ),
          2,
        );
      },
    );

    test('breaks a tie by first occurrence', () {
      expect(
        StopMotionFrameOps.globalDefaultFramesPerImage(framesOf([3, 1, 3, 1])),
        3,
      );
    });

    test(
      'falls back to the most common hold when every frame is overridden',
      () {
        var frames = framesOf([2, 2, 2]);
        frames = StopMotionFrameOps.setFrameHold(frames, 0, 4);
        frames = StopMotionFrameOps.setFrameHold(frames, 1, 4);
        frames = StopMotionFrameOps.setFrameHold(frames, 2, 6);
        expect(StopMotionFrameOps.globalDefaultFramesPerImage(frames), 4);
      },
    );

    test('returns the capture default for an empty list', () {
      expect(
        StopMotionFrameOps.globalDefaultFramesPerImage(const []),
        StopMotionFrameOps.defaultFramesPerImage,
      );
    });
  });

  group('existingFrames / sanitizedClip', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('frame_ops_sanitize');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    StopMotionClipFrame frameAt(String name, {List<int>? bytes}) {
      final path = '${tempDir.path}/$name';
      if (bytes != null) File(path).writeAsBytesSync(bytes);
      return StopMotionClipFrame(path: path, duration: hold(1));
    }

    test('drops missing and zero-byte stills, keeps readable ones', () {
      final readable = frameAt('ok.jpg', bytes: const [0]);
      final empty = frameAt('empty.jpg', bytes: const []);
      final missing = frameAt('missing.jpg');

      expect(
        StopMotionFrameOps.existingFrames([readable, empty, missing]),
        [readable],
      );
    });

    test('sanitizedClip returns the same clip when all stills read', () {
      final clip = DivineVideoClip(
        id: 'sm',
        stopMotionFrames: [
          frameAt('a.jpg', bytes: const [0]),
        ],
        duration: hold(1),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(StopMotionFrameOps.sanitizedClip(clip), same(clip));
    });

    test('sanitizedClip filters broken stills and recomputes duration', () {
      final clip = DivineVideoClip(
        id: 'sm',
        stopMotionFrames: [
          frameAt('a.jpg', bytes: const [0]),
          frameAt('gone.jpg'),
        ],
        duration: hold(1) * 2,
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      final sanitized = StopMotionFrameOps.sanitizedClip(clip);
      expect(sanitized!.stopMotionFrames, hasLength(1));
      expect(sanitized.duration, hold(1));
    });

    test('sanitizedClip returns null when no readable still remains', () {
      final clip = DivineVideoClip(
        id: 'sm',
        stopMotionFrames: [frameAt('gone.jpg')],
        duration: hold(1),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(StopMotionFrameOps.sanitizedClip(clip), isNull);
    });

    test('sanitizedClip passes a normal video clip through unchanged', () {
      final clip = DivineVideoClip(
        id: 'v',
        video: EditorVideo.file('/v.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(StopMotionFrameOps.sanitizedClip(clip), same(clip));
    });

    test('sanitizedClip passes a materialized clip through even with a '
        'missing still', () {
      // A materialized clip has a rendered mp4; its stills are transient and
      // may already be cleaned. It must not be dropped for a missing still.
      final clip = DivineVideoClip(
        id: 'sm-materialized',
        video: EditorVideo.file('/rendered.mp4'),
        stopMotionFrames: [frameAt('gone.jpg')],
        duration: const Duration(seconds: 1),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(StopMotionFrameOps.sanitizedClip(clip), same(clip));
    });
  });

  group('mergeClips', () {
    DivineVideoClip stopMotionClip(String id, List<int> holds) =>
        DivineVideoClip(
          id: id,
          stopMotionFrames: [
            for (var i = 0; i < holds.length; i++)
              StopMotionClipFrame(
                path: '$id-f$i.jpg',
                duration: hold(holds[i]),
              ),
          ],
          duration: holds.fold(Duration.zero, (sum, n) => sum + hold(n)),
          recordedAt: DateTime(2024),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        );

    test('concatenates the sets in order onto the first clip', () {
      final merged = StopMotionFrameOps.mergeClips([
        stopMotionClip('a', [2, 2]),
        stopMotionClip('b', [4]),
      ]);

      expect(merged, isNotNull);
      expect(merged!.id, 'a');
      expect(merged.stopMotionFrames!.map((f) => f.path), [
        'a-f0.jpg',
        'a-f1.jpg',
        'b-f0.jpg',
      ]);
      // Per-frame holds survive the merge; duration is recomputed.
      expect(merged.stopMotionFrames![2].duration, hold(4));
      expect(merged.duration, hold(2) + hold(2) + hold(4));
    });

    test('returns null for fewer than two clips', () {
      expect(
        StopMotionFrameOps.mergeClips([
          stopMotionClip('a', [2]),
        ]),
        isNull,
      );
      expect(StopMotionFrameOps.mergeClips(const []), isNull);
    });

    test('returns null when any clip is a normal video clip', () {
      final videoClip = DivineVideoClip(
        id: 'v',
        video: EditorVideo.file('/v.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(
        StopMotionFrameOps.mergeClips([
          stopMotionClip('a', [2]),
          videoClip,
        ]),
        isNull,
      );
    });
  });

  group('clipWithFrames', () {
    DivineVideoClip stopMotionClip(List<int> holds) => DivineVideoClip(
      id: 'clip',
      stopMotionFrames: framesOf(holds),
      duration: StopMotionFrameOps.totalDuration(framesOf(holds)),
      recordedAt: DateTime(2024),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 1,
    );

    test('recomputes the clip duration from the new frame holds', () {
      final clip = stopMotionClip([1, 1, 1]);
      final newFrames = StopMotionFrameOps.removeFrame(
        clip.stopMotionFrames!,
        0,
      );
      final updated = StopMotionFrameOps.clipWithFrames(clip, newFrames);

      expect(updated.stopMotionFrames, hasLength(2));
      expect(updated.duration, StopMotionFrameOps.totalDuration(newFrames));
      expect(updated.duration, hold(1) * 2);
    });
  });

  group('isStopMotionComposition', () {
    DivineVideoClip stopMotion() => DivineVideoClip(
      id: 's',
      stopMotionFrames: framesOf([1]),
      duration: hold(1),
      recordedAt: DateTime(2024),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 1,
    );

    DivineVideoClip video() => DivineVideoClip(
      id: 'v',
      video: EditorVideo.file('/v.mp4'),
      duration: const Duration(seconds: 1),
      recordedAt: DateTime(2024),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 1,
    );

    test('true only when every clip is stop-motion', () {
      expect(isStopMotionComposition([stopMotion(), stopMotion()]), isTrue);
      expect(isStopMotionComposition([stopMotion(), video()]), isFalse);
      expect(isStopMotionComposition([video()]), isFalse);
      expect(isStopMotionComposition(const []), isFalse);
    });
  });
}
