// ABOUTME: Unit tests for ClipThumbnailManager.
// ABOUTME: Validates notifier lifecycle, sync logic, and disposal.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/clip_thumbnail_manager.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(ClipThumbnailManager, () {
    late ClipThumbnailManager manager;

    setUp(() {
      manager = ClipThumbnailManager();
    });

    tearDown(() {
      manager.dispose();
    });

    group('sync', () {
      test('creates notifier for each clip', () {
        final clips = [_createTestClip(id: 'a'), _createTestClip(id: 'b')];

        manager.sync(clips: clips, devicePixelRatio: 1);

        expect(manager['a'], isA<ValueNotifier<List<StripThumbnail>>>());
        expect(manager['b'], isA<ValueNotifier<List<StripThumbnail>>>());
      });

      test('notifiers start with empty list', () {
        final clips = [_createTestClip(id: 'a')];

        manager.sync(clips: clips, devicePixelRatio: 1);

        expect(manager['a'].value, isEmpty);
      });

      test('removes stale notifiers when clips change', () {
        manager.sync(
          clips: [
            _createTestClip(id: 'a'),
            _createTestClip(id: 'b'),
          ],
          devicePixelRatio: 1,
        );

        // Second sync without clip 'b'.
        manager.sync(clips: [_createTestClip(id: 'a')], devicePixelRatio: 1);

        expect(manager['a'], isA<ValueNotifier<List<StripThumbnail>>>());
        expect(() => manager['b'], throwsA(isA<TypeError>()));
      });

      test('does not recreate existing notifiers on re-sync', () {
        final clips = [_createTestClip(id: 'a')];

        manager.sync(clips: clips, devicePixelRatio: 1);
        final notifier1 = manager['a'];

        manager.sync(clips: clips, devicePixelRatio: 1);
        final notifier2 = manager['a'];

        expect(identical(notifier1, notifier2), isTrue);
      });

      test('handles empty clip list', () {
        expect(
          () => manager.sync(clips: [], devicePixelRatio: 1),
          returnsNormally,
        );
      });

      test('handles transition from clips to empty', () {
        manager.sync(clips: [_createTestClip(id: 'a')], devicePixelRatio: 1);

        manager.sync(clips: [], devicePixelRatio: 1);

        expect(() => manager['a'], throwsA(isA<TypeError>()));
      });
    });

    // ---------------------------------------------------------
    // seedFromSource
    // ---------------------------------------------------------

    group('seedFromSource', () {
      test('populates target notifier with time-shifted thumbnails', () {
        final sourceClip = _createTestClip(id: 'src', seconds: 4);
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);

        manager['src'].value = [
          const StripThumbnail(path: '/t/0.jpg', timestamp: Duration.zero),
          const StripThumbnail(
            path: '/t/1.jpg',
            timestamp: Duration(seconds: 1),
          ),
          const StripThumbnail(
            path: '/t/2.jpg',
            timestamp: Duration(seconds: 2),
          ),
          const StripThumbnail(
            path: '/t/3.jpg',
            timestamp: Duration(seconds: 3),
          ),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration(seconds: 1),
            end: Duration(seconds: 3),
          ),
          currentSourcePath: '/video/src.mp4',
        );

        final thumbnails = manager['tgt'].value;
        expect(thumbnails, hasLength(2));
        // 1 s thumbnail shifted by −1 s → 0 s
        expect(thumbnails[0].path, equals('/t/1.jpg'));
        expect(thumbnails[0].timestamp, equals(Duration.zero));
        // 2 s thumbnail shifted by −1 s → 1 s
        expect(thumbnails[1].path, equals('/t/2.jpg'));
        expect(
          thumbnails[1].timestamp,
          equals(const Duration(seconds: 1)),
        );
      });

      test('excludes thumbnails outside the requested range', () {
        final sourceClip = _createTestClip(id: 'src', seconds: 10);
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);

        manager['src'].value = [
          const StripThumbnail(path: '/t/0.jpg', timestamp: Duration.zero),
          const StripThumbnail(
            path: '/t/5.jpg',
            timestamp: Duration(seconds: 5),
          ),
          const StripThumbnail(
            path: '/t/9.jpg',
            timestamp: Duration(seconds: 9),
          ),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration(seconds: 4),
            end: Duration(seconds: 6),
          ),
          currentSourcePath: '/video/src.mp4',
        );

        final thumbnails = manager['tgt'].value;
        expect(thumbnails, hasLength(1));
        expect(thumbnails.first.path, equals('/t/5.jpg'));
        expect(
          thumbnails.first.timestamp,
          equals(const Duration(seconds: 1)),
        );
      });

      test('is a no-op when source notifier does not exist', () {
        expect(
          () => manager.seedFromSource(
            sourceClipId: 'nonexistent',
            targetClipId: 'tgt',
            sourceRange: const DurationRange(
              start: Duration.zero,
              end: Duration(seconds: 1),
            ),
            currentSourcePath: '/video/src.mp4',
          ),
          returnsNormally,
        );
      });

      test('creates target notifier even when target is not yet in sync', () {
        final sourceClip = _createTestClip(id: 'src', seconds: 2);
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);

        manager['src'].value = [
          const StripThumbnail(path: '/t/0.jpg', timestamp: Duration.zero),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration.zero,
            end: Duration(seconds: 2),
          ),
          currentSourcePath: '/video/src.mp4',
        );

        expect(
          manager['tgt'],
          isA<ValueNotifier<List<StripThumbnail>>>(),
        );
        expect(manager['tgt'].value, hasLength(1));
      });

      test('seeded notifier value is preserved after re-sync', () {
        // Simulates the window between split (seed) and render complete
        // (path swap). While the target clip still points at the source
        // video (no file path / null), re-syncing must not reset the
        // already-correct seeded thumbnails.
        final sourceClip = _createTestClip(id: 'src', seconds: 4);
        final targetClip = _createTestClip(id: 'tgt', seconds: 2);
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);

        manager['src'].value = [
          const StripThumbnail(path: '/t/0.jpg', timestamp: Duration.zero),
          const StripThumbnail(
            path: '/t/1.jpg',
            timestamp: Duration(seconds: 1),
          ),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration.zero,
            end: Duration(seconds: 2),
          ),
          currentSourcePath: '/video/src.mp4',
        );

        final seededValue = manager['tgt'].value;
        expect(seededValue, hasLength(2));

        // Re-sync with target added. targetClip uses a network URL so
        // _loadThumbnails exits early and never overwrites the notifier.
        manager.sync(
          clips: [sourceClip, targetClip],
          devicePixelRatio: 1,
        );

        expect(manager['tgt'].value, equals(seededValue));
      });

      test('seeded target is removed from sync when absent from clip list', () {
        final sourceClip = _createTestClip(id: 'src', seconds: 2);
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);
        manager['src'].value = [
          const StripThumbnail(path: '/t/0.jpg', timestamp: Duration.zero),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration.zero,
            end: Duration(seconds: 2),
          ),
          currentSourcePath: '/video/src.mp4',
        );

        // Sync without the target clip — it should be cleaned up.
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);

        expect(() => manager['tgt'], throwsA(isA<TypeError>()));
      });

      test(
        'copies seeded files before source cleanup deletes originals',
        () async {
          final tempDir = Directory.systemTemp.createTempSync(
            'clip_thumbnail_seed_test_',
          );
          addTearDown(() {
            if (tempDir.existsSync()) {
              tempDir.deleteSync(recursive: true);
            }
          });

          final sourceThumbnail = File('${tempDir.path}/source.jpg')
            ..writeAsStringSync('source-thumbnail');
          final sourceVideoPath = '${tempDir.path}/source.mp4';

          final sourceClip = _createTestClip(id: 'src', seconds: 2);
          final targetClip = _createFileClip(
            id: 'tgt',
            videoPath: sourceVideoPath,
            seconds: 2,
          );
          manager.sync(clips: [sourceClip], devicePixelRatio: 1);
          manager['src'].value = [
            StripThumbnail(
              path: sourceThumbnail.path,
              timestamp: const Duration(seconds: 1),
            ),
          ];

          manager.seedFromSource(
            sourceClipId: 'src',
            targetClipId: 'tgt',
            sourceRange: const DurationRange(
              start: Duration.zero,
              end: Duration(seconds: 2),
            ),
            currentSourcePath: sourceVideoPath,
          );

          final seededPath = manager['tgt'].value.single.path;
          expect(seededPath, isNot(equals(sourceThumbnail.path)));

          // Simulate the split lifecycle: the source clip is removed, but
          // the seeded target still points at the source video until render
          // completes. Target thumbnails must survive stale source cleanup.
          manager.sync(clips: [targetClip], devicePixelRatio: 1);
          await Future<void>.delayed(Duration.zero);

          expect(sourceThumbnail.existsSync(), isFalse);
          expect(File(seededPath).existsSync(), isTrue);
        },
      );

      test('can preserve source timestamps while filtering a range', () {
        final sourceClip = _createTestClip(id: 'src', seconds: 6);
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);
        manager['src'].value = [
          const StripThumbnail(
            path: '/t/2.jpg',
            timestamp: Duration(seconds: 2),
          ),
          const StripThumbnail(
            path: '/t/3.jpg',
            timestamp: Duration(seconds: 3),
          ),
          const StripThumbnail(
            path: '/t/4.jpg',
            timestamp: Duration(seconds: 4),
          ),
          const StripThumbnail(
            path: '/t/5.jpg',
            timestamp: Duration(seconds: 5),
          ),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration(seconds: 3),
            end: Duration(seconds: 5),
          ),
          timestampOffset: Duration.zero,
          currentSourcePath: '/video/src.mp4',
        );

        final thumbnails = manager['tgt'].value;
        expect(thumbnails, hasLength(2));
        expect(thumbnails[0].path, equals('/t/3.jpg'));
        expect(thumbnails[0].timestamp, equals(const Duration(seconds: 3)));
        expect(thumbnails[1].path, equals('/t/4.jpg'));
        expect(thumbnails[1].timestamp, equals(const Duration(seconds: 4)));
      });
    });

    group('dispose', () {
      test('can be called on empty manager', () {
        final localManager = ClipThumbnailManager();

        // Should not throw.
        localManager.dispose();
      });

      test('can be called after sync', () {
        final localManager = ClipThumbnailManager();
        localManager.sync(
          clips: [_createTestClip(id: 'a')],
          devicePixelRatio: 1,
        );

        // Should not throw.
        localManager.dispose();
      });
    });
  });

  // =========================================================
  // DurationRange
  // =========================================================

  group(DurationRange, () {
    test('stores start and end', () {
      const range = DurationRange(
        start: Duration(seconds: 1),
        end: Duration(seconds: 5),
      );

      expect(range.start, equals(const Duration(seconds: 1)));
      expect(range.end, equals(const Duration(seconds: 5)));
    });

    test('allows zero-length range', () {
      const range = DurationRange(
        start: Duration(seconds: 2),
        end: Duration(seconds: 2),
      );

      expect(range.start, equals(range.end));
    });
  });
}

/// Creates a test clip whose [EditorVideo] has no local file so
/// [ClipThumbnailManager._loadThumbnails] exits early without
/// triggering a platform channel call.
DivineVideoClip _createTestClip({required String id, int seconds = 3}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.network('https://example.com/$id.mp4'),
    duration: Duration(seconds: seconds),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: .vertical,
  );
}

DivineVideoClip _createFileClip({
  required String id,
  required String videoPath,
  int seconds = 3,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file(videoPath),
    duration: Duration(seconds: seconds),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: .vertical,
  );
}
