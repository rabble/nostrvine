import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(StopMotionClipFrame, () {
    test('JSON round-trips the basename and duration exactly', () {
      // 2 frames @ 30fps — not a whole number of milliseconds; a millisecond
      // round-trip would shift the hold off the output frame grid.
      const frame = StopMotionClipFrame(
        path: '/some/dir/frame_1.jpg',
        duration: Duration(microseconds: 66667),
      );

      final json = frame.toJson();
      expect(json['path'], 'frame_1.jpg');
      expect(json['durationUs'], 66667);

      final restored = StopMotionClipFrame.fromJson(json, '/docs');
      expect(restored.path, '/docs/frame_1.jpg');
      expect(restored.duration, const Duration(microseconds: 66667));
    });

    test('falls back to legacy durationMs when durationUs is absent', () {
      final restored = StopMotionClipFrame.fromJson(
        const {'path': 'frame_1.jpg', 'durationMs': 83},
        '/docs',
      );
      expect(restored.duration, const Duration(milliseconds: 83));
    });

    test('uses value equality', () {
      const a = StopMotionClipFrame(
        path: '/a.jpg',
        duration: Duration(milliseconds: 83),
      );
      const b = StopMotionClipFrame(
        path: '/a.jpg',
        duration: Duration(milliseconds: 83),
      );
      const c = StopMotionClipFrame(
        path: '/b.jpg',
        duration: Duration(milliseconds: 83),
      );

      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('$DivineVideoClip stop-motion', () {
    DivineVideoClip framesClip() => DivineVideoClip(
      id: 'sm1',
      stopMotionFrames: const [
        StopMotionClipFrame(
          path: '/d/a.jpg',
          duration: Duration(milliseconds: 83),
        ),
        StopMotionClipFrame(
          path: '/d/b.jpg',
          duration: Duration(milliseconds: 83),
        ),
      ],
      duration: const Duration(milliseconds: 166),
      recordedAt: DateTime(2024),
      thumbnailPath: '/d/a.jpg',
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
    );

    test('isStopMotion is true and video is null', () {
      final clip = framesClip();
      expect(clip.isStopMotion, isTrue);
      expect(clip.video, isNull);
    });

    test('requireVideo throws for a frames clip', () {
      expect(() => framesClip().requireVideo, throwsStateError);
    });

    test('JSON round-trips frames with a null filePath', () {
      final json = framesClip().toJson();

      expect(json['filePath'], isNull);
      expect(json['stopMotionFrames'], hasLength(2));

      final restored = DivineVideoClip.fromJson(json, '/docs');
      expect(restored.isStopMotion, isTrue);
      expect(restored.video, isNull);
      expect(restored.stopMotionFrames!.map((f) => f.path), [
        '/docs/a.jpg',
        '/docs/b.jpg',
      ]);
      expect(
        restored.stopMotionFrames!.map((f) => f.duration),
        everyElement(const Duration(milliseconds: 83)),
      );
    });

    test('fromJson derives clip duration from the microsecond frame holds', () {
      final clip = DivineVideoClip(
        id: 'sm-us',
        stopMotionFrames: const [
          StopMotionClipFrame(
            path: '/d/a.jpg',
            duration: Duration(microseconds: 66667),
          ),
          StopMotionClipFrame(
            path: '/d/b.jpg',
            duration: Duration(microseconds: 66667),
          ),
        ],
        duration: const Duration(microseconds: 133334),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      final json = clip.toJson();
      // The aggregate is persisted ms-truncated; the frames keep microseconds.
      expect(json['durationMs'], 133);

      final restored = DivineVideoClip.fromJson(json, '/docs');
      // Duration is recomputed from the frames' µs holds, not the truncated ms
      // value, so it stays on the frame grid after a reload.
      expect(restored.duration, const Duration(microseconds: 133334));
      expect(restored.duration, isNot(const Duration(milliseconds: 133)));
    });

    test('a video clip is not stop-motion and exposes requireVideo', () {
      final clip = DivineVideoClip(
        id: 'v1',
        video: EditorVideo.file('/v.mp4'),
        duration: const Duration(seconds: 1),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(clip.isStopMotion, isFalse);
      expect(clip.stopMotionFrames, isNull);
      expect(clip.requireVideo.file?.path, '/v.mp4');
    });
  });
}
