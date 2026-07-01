import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/clip_speed_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  DivineVideoClip clip(
    String id, {
    double? playbackSpeed,
    Duration trimStart = Duration.zero,
    Duration trimEnd = Duration.zero,
    String? path,
  }) => DivineVideoClip(
    id: id,
    video: editor.EditorVideo.file(File(path ?? '/tmp/$id.mp4')),
    duration: const Duration(seconds: 3),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.square,
    originalAspectRatio: 1,
    playbackSpeed: playbackSpeed,
    trimStart: trimStart,
    trimEnd: trimEnd,
  );

  const rendered = RenderedSpeedClip(
    path: '/tmp/a_speed.mp4',
    duration: Duration(milliseconds: 1500),
  );

  group(ClipSpeedRenderService, () {
    group('cached', () {
      test('returns the seeded render for a non-1× clip', () {
        final c = clip('a', playbackSpeed: 2);
        final service = ClipSpeedRenderService()..cacheForTest(c, rendered);

        expect(service.cached(c), same(rendered));
      });

      test('returns null for a clip at the default (1×) speed', () {
        final c = clip('a'); // playbackSpeed null == 1×
        final service = ClipSpeedRenderService()..cacheForTest(c, rendered);

        expect(service.cached(c), isNull);
      });

      test('returns null for an explicit 1.0× clip', () {
        final c = clip('a', playbackSpeed: 1);
        final service = ClipSpeedRenderService()..cacheForTest(c, rendered);

        expect(service.cached(c), isNull);
      });

      test('misses the cache when the speed changes', () {
        final slow = clip('a', playbackSpeed: 2);
        final faster = clip('a', playbackSpeed: 3);
        final service = ClipSpeedRenderService()..cacheForTest(slow, rendered);

        expect(service.cached(slow), same(rendered));
        expect(service.cached(faster), isNull);
      });

      test('misses the cache when the trim changes', () {
        final untrimmed = clip('a', playbackSpeed: 2);
        final trimmed = clip(
          'a',
          playbackSpeed: 2,
          trimStart: const Duration(milliseconds: 500),
        );
        final service = ClipSpeedRenderService()
          ..cacheForTest(untrimmed, rendered);

        expect(service.cached(untrimmed), same(rendered));
        expect(service.cached(trimmed), isNull);
      });

      test('misses the cache when the source file changes (e.g. reverse)', () {
        final forward = clip('a', playbackSpeed: 2);
        final reversed = clip(
          'a',
          playbackSpeed: 2,
          path: '/tmp/a_reversed.mp4',
        );
        final service = ClipSpeedRenderService()
          ..cacheForTest(forward, rendered);

        expect(service.cached(forward), same(rendered));
        expect(service.cached(reversed), isNull);
      });
    });

    group('render', () {
      test('short-circuits to null for a 1× clip without touching native', () {
        final service = ClipSpeedRenderService();

        expect(service.render(clip('a')), completion(isNull));
        expect(service.isRendering(clip('a')), isFalse);
      });
    });

    group('version', () {
      test('bumps on cache seed and clear, and clear drops the entry', () {
        final c = clip('a', playbackSpeed: 2);
        final service = ClipSpeedRenderService();
        final initial = service.version;

        service.cacheForTest(c, rendered);
        expect(service.version, greaterThan(initial));

        final afterSeed = service.version;
        service.clear();
        expect(service.version, greaterThan(afterSeed));
        expect(service.cached(c), isNull);
      });
    });
  });
}
