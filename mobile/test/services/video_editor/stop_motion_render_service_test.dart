import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  List<StopMotionClipFrame> framesOf(
    List<String> paths, {
    Duration duration = const Duration(milliseconds: 83),
  }) => [
    for (final path in paths)
      StopMotionClipFrame(path: path, duration: duration),
  ];

  group(StopMotionRenderService, () {
    tearDown(() => StopMotionRenderService.assembleOverride = null);

    test('returns null for an empty frame list', () async {
      final result = await StopMotionRenderService.assemble(
        frames: const [],
        aspectRatio: model.AspectRatio.vertical,
      );

      expect(result, isNull);
    });

    test('delegates to assembleOverride with the given arguments', () async {
      List<StopMotionClipFrame>? capturedFrames;
      model.AspectRatio? capturedRatio;
      double? capturedFrameRate;
      String? capturedTaskId;

      StopMotionRenderService.assembleOverride =
          ({
            required frames,
            required aspectRatio,
            frameRate = StopMotionRenderService.defaultFrameRate,
            String? taskId,
          }) async {
            capturedFrames = frames;
            capturedRatio = aspectRatio;
            capturedFrameRate = frameRate;
            capturedTaskId = taskId;
            return '/tmp/out.mp4';
          };

      final frames = framesOf(const ['/a.jpg', '/b.jpg']);
      final result = await StopMotionRenderService.assemble(
        frames: frames,
        aspectRatio: model.AspectRatio.square,
        taskId: 'assembly-task',
      );

      expect(result, '/tmp/out.mp4');
      expect(capturedFrames, frames);
      expect(capturedRatio, model.AspectRatio.square);
      expect(capturedFrameRate, StopMotionRenderService.defaultFrameRate);
      expect(capturedTaskId, 'assembly-task');
    });

    group('framesForMinOutputDuration', () {
      const min = VideoEditorConstants.stopMotionMinOutputDuration;

      Duration total(List<StopMotionClipFrame> frames) =>
          frames.fold(Duration.zero, (sum, frame) => sum + frame.duration);

      test('returns an empty list unchanged', () {
        expect(
          StopMotionRenderService.framesForMinOutputDuration(const []),
          isEmpty,
        );
      });

      test('repeats a single still until it reaches the minimum', () {
        final frames = framesOf(const ['/a.jpg']);
        final result = StopMotionRenderService.framesForMinOutputDuration(
          frames,
        );

        expect(result.map((f) => f.path).toSet(), {'/a.jpg'});
        expect(total(result), greaterThanOrEqualTo(min));
        // Minimal: one fewer copy would fall short of the floor.
        expect(
          total(result.sublist(0, result.length - 1)),
          lessThan(min),
        );
      });

      test('loops a short sequence a whole number of times', () {
        final frames = framesOf(
          const ['/a.jpg', '/b.jpg', '/c.jpg'],
          duration: const Duration(milliseconds: 100),
        ); // 300ms < 1s
        final result = StopMotionRenderService.framesForMinOutputDuration(
          frames,
        );

        expect(result.length % frames.length, 0);
        expect(total(result), greaterThanOrEqualTo(min));
        expect(
          total(result.sublist(0, result.length - frames.length)),
          lessThan(min),
        );
        // Order preserved across the repeats (seamless loop).
        expect(result.sublist(0, frames.length), frames);
      });

      test('preserves per-frame holds when looping', () {
        final frames = [
          const StopMotionClipFrame(
            path: '/a.jpg',
            duration: Duration(milliseconds: 83),
          ),
          const StopMotionClipFrame(
            path: '/b.jpg',
            duration: Duration(milliseconds: 250),
          ),
        ];
        final result = StopMotionRenderService.framesForMinOutputDuration(
          frames,
        );

        for (var i = 0; i < result.length; i += 2) {
          expect(result[i].duration, const Duration(milliseconds: 83));
          expect(result[i + 1].duration, const Duration(milliseconds: 250));
        }
      });

      test('leaves a sequence already at the minimum unchanged', () {
        final frames = framesOf(
          const ['/a.jpg', '/b.jpg', '/c.jpg', '/d.jpg'],
          duration: const Duration(milliseconds: 250),
        ); // 1s
        final result = StopMotionRenderService.framesForMinOutputDuration(
          frames,
        );

        expect(result, frames);
      });
    });

    group('materialize', () {
      DivineVideoClip stopMotionClip() => DivineVideoClip(
        id: 'sm1',
        stopMotionFrames: const [
          StopMotionClipFrame(
            path: '/a.jpg',
            duration: Duration(milliseconds: 83),
          ),
          StopMotionClipFrame(
            path: '/b.jpg',
            duration: Duration(milliseconds: 250),
          ),
        ],
        duration: const Duration(milliseconds: 333),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      test('returns a non-stop-motion clip unchanged', () async {
        final clip = DivineVideoClip(
          id: 'v1',
          video: EditorVideo.file('/v.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2024),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        );

        final result = await StopMotionRenderService.materialize(clip);

        expect(identical(result, clip), isTrue);
      });

      test('renders the clip frames — per-frame holds included', () async {
        List<StopMotionClipFrame>? capturedFrames;
        String? capturedTaskId;
        StopMotionRenderService.assembleOverride =
            ({
              required frames,
              required aspectRatio,
              frameRate = StopMotionRenderService.defaultFrameRate,
              String? taskId,
            }) async {
              capturedFrames = frames;
              capturedTaskId = taskId;
              return '/rendered.mp4';
            };

        final clip = stopMotionClip();
        final result = await StopMotionRenderService.materialize(
          clip,
          taskId: 'render-task',
        );

        // The clip's own frames (with individual hold times) reach the render.
        expect(capturedFrames, clip.stopMotionFrames);
        // The progress task id is forwarded to the assembly.
        expect(capturedTaskId, 'render-task');
        expect(result?.video?.file?.path, '/rendered.mp4');
        // The materialized clip is now a plain video clip: its transient stills
        // are cleared and it no longer classifies as stop-motion.
        expect(result?.stopMotionFrames, isNull);
        expect(result?.isStopMotion, isFalse);
        // Duration matches the looped mp4: 333ms single pass loops x4 to clear
        // the 1s minimum output duration (ceil(1000/333) = 4 → 1332ms).
        expect(result?.duration, const Duration(milliseconds: 1332));
      });

      test(
        'keeps the single-pass duration when already >= min output',
        () async {
          StopMotionRenderService.assembleOverride =
              ({
                required frames,
                required aspectRatio,
                frameRate = StopMotionRenderService.defaultFrameRate,
                String? taskId,
              }) async => '/rendered.mp4';

          final clip = DivineVideoClip(
            id: 'sm-long',
            stopMotionFrames: const [
              StopMotionClipFrame(
                path: '/a.jpg',
                duration: Duration(milliseconds: 1200),
              ),
            ],
            duration: const Duration(milliseconds: 1200),
            recordedAt: DateTime(2024),
            targetAspectRatio: model.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
          );

          final result = await StopMotionRenderService.materialize(clip);

          expect(result?.duration, const Duration(milliseconds: 1200));
          expect(result?.stopMotionFrames, isNull);
        },
      );

      test('returns null when the render fails', () async {
        StopMotionRenderService.assembleOverride =
            ({
              required frames,
              required aspectRatio,
              frameRate = StopMotionRenderService.defaultFrameRate,
              String? taskId,
            }) async => null;

        final result = await StopMotionRenderService.materialize(
          stopMotionClip(),
        );

        expect(result, isNull);
      });
    });
  });
}
