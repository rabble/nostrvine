// ABOUTME: Unit tests for ClipThumbnailManager.
// ABOUTME: Validates notifier lifecycle, sync logic, and disposal.

import 'dart:async';
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
        expect(thumbnails[1].timestamp, equals(const Duration(seconds: 1)));
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
        expect(thumbnails.first.timestamp, equals(const Duration(seconds: 1)));
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

        expect(manager['tgt'], isA<ValueNotifier<List<StripThumbnail>>>());
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
        manager.sync(clips: [sourceClip, targetClip], devicePixelRatio: 1);

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
        'borrows source files without copying and protects them from '
        'source cleanup',
        () async {
          final tempDir = Directory.systemTemp.createTempSync(
            'clip_thumbnail_seed_test_',
          );
          addTearDown(() {
            if (tempDir.existsSync()) {
              tempDir.deleteSync(recursive: true);
            }
          });

          final borrowedThumbnail = File('${tempDir.path}/borrowed.jpg')
            ..writeAsStringSync('borrowed-thumbnail');
          final unborrowedThumbnail = File('${tempDir.path}/unborrowed.jpg')
            ..writeAsStringSync('unborrowed-thumbnail');
          final sourceVideoPath = '${tempDir.path}/source.mp4';

          final sourceClip = _createTestClip(id: 'src', seconds: 4);
          final targetClip = _createFileClip(
            id: 'tgt',
            videoPath: sourceVideoPath,
            seconds: 2,
          );
          manager.sync(clips: [sourceClip], devicePixelRatio: 1);
          manager['src'].value = [
            StripThumbnail(
              path: borrowedThumbnail.path,
              timestamp: const Duration(seconds: 1),
            ),
            StripThumbnail(
              path: unborrowedThumbnail.path,
              timestamp: const Duration(seconds: 3),
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

          // Borrowed, not copied — the image cache entry decoded for the
          // source tile stays valid, so the new tile paints instantly
          // instead of flashing black on a cold decode.
          final seededPath = manager['tgt'].value.single.path;
          expect(seededPath, equals(borrowedThumbnail.path));

          // Simulate the split lifecycle: the source clip is removed, but
          // the seeded target still points at the source video until render
          // completes. Borrowed files must survive stale source cleanup;
          // files nobody borrowed are deleted.
          manager.sync(clips: [targetClip], devicePixelRatio: 1);
          await Future<void>.delayed(Duration.zero);

          expect(borrowedThumbnail.existsSync(), isTrue);
          expect(unborrowedThumbnail.existsSync(), isFalse);
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

    group('rendered path arrival', () {
      late List<StreamController<List<StripThumbnail>>> controllers;
      late ClipThumbnailManager fakeStreamManager;
      late Directory tempDir;

      setUp(() {
        controllers = [];
        fakeStreamManager = ClipThumbnailManager(
          stripThumbnailStreamFactory:
              ({
                required String videoPath,
                required String clipId,
                required Duration duration,
                required Size outputSize,
                required int thumbsPerSecond,
                List<Duration>? priorityTimestamps,
              }) {
                final controller = StreamController<List<StripThumbnail>>();
                controllers.add(controller);
                return controller.stream;
              },
        );
        tempDir = Directory.systemTemp.createTempSync(
          'clip_thumbnail_path_change_test_',
        );
      });

      tearDown(() {
        fakeStreamManager.dispose();
        for (final controller in controllers) {
          unawaited(controller.close());
        }
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test(
        'keeps seeded frames rebased into the rendered timebase until the '
        'first fresh batch replaces them, then deletes the borrowed files',
        () async {
          final borrowed = File('${tempDir.path}/borrowed.jpg')
            ..writeAsStringSync('borrowed');
          final sourceVideoPath = '${tempDir.path}/source.mp4';
          final renderedVideoPath = '${tempDir.path}/rendered_end.mp4';

          final sourceClip = _createFileClip(
            id: 'src',
            videoPath: sourceVideoPath,
            seconds: 10,
          );
          fakeStreamManager.sync(clips: [sourceClip], devicePixelRatio: 1);
          fakeStreamManager['src'].value = [
            StripThumbnail(
              path: borrowed.path,
              timestamp: const Duration(seconds: 4),
            ),
          ];

          // Split at 3 s: the end half previews the source video, so its
          // seeds stay source-timed; the rendered file starts at zero.
          fakeStreamManager.seedFromSource(
            sourceClipId: 'src',
            targetClipId: 'end',
            sourceRange: const DurationRange(
              start: Duration(seconds: 3),
              end: Duration(seconds: 10),
            ),
            timestampOffset: Duration.zero,
            rebaseOnPathChange: const Duration(seconds: 3),
            currentSourcePath: sourceVideoPath,
          );
          expect(
            fakeStreamManager['end'].value.single.timestamp,
            equals(const Duration(seconds: 4)),
          );

          // Source replaced by the preview end half — no new subscription
          // while the clip still points at the source video.
          final previewEndClip = _createFileClip(
            id: 'end',
            videoPath: sourceVideoPath,
            seconds: 10,
          );
          fakeStreamManager.sync(
            clips: [previewEndClip],
            devicePixelRatio: 1,
          );
          expect(controllers, hasLength(1));
          expect(
            fakeStreamManager['end'].value.single.timestamp,
            equals(const Duration(seconds: 4)),
          );

          // Rendered file arrives: the real subscription starts, the
          // seeded frame stays visible and is rebased to the rendered
          // file's zero-based timeline.
          final renderedEndClip = _createFileClip(
            id: 'end',
            videoPath: renderedVideoPath,
            seconds: 7,
          );
          fakeStreamManager.sync(
            clips: [renderedEndClip],
            devicePixelRatio: 1,
          );
          expect(controllers, hasLength(2));
          final held = fakeStreamManager['end'].value.single;
          expect(held.path, equals(borrowed.path));
          expect(held.timestamp, equals(const Duration(seconds: 1)));
          expect(borrowed.existsSync(), isTrue);

          // First fresh batch replaces the seeds and deletes the borrowed
          // file, which no notifier references anymore.
          final fresh = File('${tempDir.path}/fresh.jpg')
            ..writeAsStringSync('fresh');
          controllers[1].add([
            StripThumbnail(
              path: fresh.path,
              timestamp: const Duration(seconds: 1),
            ),
          ]);
          await pumpEventQueue();

          expect(
            fakeStreamManager['end'].value.single.path,
            equals(fresh.path),
          );
          expect(borrowed.existsSync(), isFalse);
          expect(fresh.existsSync(), isTrue);
        },
      );

      test(
        'accumulating batches never delete still-referenced files',
        () async {
          final first = File('${tempDir.path}/first.jpg')
            ..writeAsStringSync('first');
          final second = File('${tempDir.path}/second.jpg')
            ..writeAsStringSync('second');

          fakeStreamManager.sync(
            clips: [
              _createFileClip(id: 'a', videoPath: '${tempDir.path}/a.mp4'),
            ],
            devicePixelRatio: 1,
          );

          controllers.single.add([
            StripThumbnail(path: first.path, timestamp: Duration.zero),
          ]);
          await pumpEventQueue();
          controllers.single.add([
            StripThumbnail(path: first.path, timestamp: Duration.zero),
            StripThumbnail(
              path: second.path,
              timestamp: const Duration(seconds: 1),
            ),
          ]);
          await pumpEventQueue();

          expect(fakeStreamManager['a'].value, hasLength(2));
          expect(first.existsSync(), isTrue);
          expect(second.existsSync(), isTrue);
        },
      );

      test(
        'restart keeps a dropped frame whose file a sibling clip still shows',
        () async {
          final shared = File('${tempDir.path}/shared.jpg')
            ..writeAsStringSync('shared');
          final freshA = File('${tempDir.path}/fresh_a.jpg')
            ..writeAsStringSync('fresh-a');

          fakeStreamManager.sync(
            clips: [
              _createFileClip(id: 'a', videoPath: '${tempDir.path}/a.mp4'),
              _createFileClip(id: 'b', videoPath: '${tempDir.path}/b.mp4'),
            ],
            devicePixelRatio: 1,
          );
          expect(controllers, hasLength(2));

          // Both clips end up showing the same file (an overlapping
          // borrow). A fresh batch on 'a' that drops the shared path must
          // not delete the file while 'b' still references it.
          controllers[0].add([
            StripThumbnail(path: shared.path, timestamp: Duration.zero),
          ]);
          controllers[1].add([
            StripThumbnail(path: shared.path, timestamp: Duration.zero),
          ]);
          await pumpEventQueue();

          controllers[0].add([
            StripThumbnail(path: freshA.path, timestamp: Duration.zero),
          ]);
          await pumpEventQueue();

          expect(
            fakeStreamManager['a'].value.single.path,
            equals(freshA.path),
          );
          expect(shared.existsSync(), isTrue);
          expect(freshA.existsSync(), isTrue);
        },
      );

      test(
        'keeps START-half seeds as-is on rendered path arrival (no rebase), '
        'then the first fresh batch supersedes and deletes them',
        () async {
          final borrowed = File('${tempDir.path}/start_borrowed.jpg')
            ..writeAsStringSync('borrowed');
          final sourceVideoPath = '${tempDir.path}/source.mp4';
          final renderedVideoPath = '${tempDir.path}/rendered_start.mp4';

          final sourceClip = _createFileClip(
            id: 'src',
            videoPath: sourceVideoPath,
            seconds: 10,
          );
          fakeStreamManager.sync(clips: [sourceClip], devicePixelRatio: 1);
          fakeStreamManager['src'].value = [
            StripThumbnail(
              path: borrowed.path,
              timestamp: const Duration(seconds: 1),
            ),
          ];

          // Split at 3 s: the start half already begins at zero, so the
          // rendered file needs no rebase (rebaseOnPathChange stays zero)
          // and the seed keeps its source-timed timestamp verbatim.
          fakeStreamManager.seedFromSource(
            sourceClipId: 'src',
            targetClipId: 'start',
            sourceRange: const DurationRange(
              start: Duration.zero,
              end: Duration(seconds: 3),
            ),
            timestampOffset: Duration.zero,
            currentSourcePath: sourceVideoPath,
          );
          expect(
            fakeStreamManager['start'].value.single.timestamp,
            equals(const Duration(seconds: 1)),
          );

          // Rendered file arrives: a real subscription starts and the seed
          // is held unchanged (no rebase branch runs for the start half).
          final renderedStartClip = _createFileClip(
            id: 'start',
            videoPath: renderedVideoPath,
          );
          fakeStreamManager.sync(
            clips: [renderedStartClip],
            devicePixelRatio: 1,
          );
          expect(controllers, hasLength(2));
          final held = fakeStreamManager['start'].value.single;
          expect(held.path, equals(borrowed.path));
          expect(held.timestamp, equals(const Duration(seconds: 1)));
          expect(borrowed.existsSync(), isTrue);

          final fresh = File('${tempDir.path}/fresh_start.jpg')
            ..writeAsStringSync('fresh');
          controllers[1].add([
            StripThumbnail(
              path: fresh.path,
              timestamp: const Duration(seconds: 1),
            ),
          ]);
          await pumpEventQueue();

          expect(
            fakeStreamManager['start'].value.single.path,
            equals(fresh.path),
          );
          expect(borrowed.existsSync(), isFalse);
          expect(fresh.existsSync(), isTrue);
        },
      );

      test(
        'marks the target seeded and suppresses the source-video load when '
        'the source has no thumbnails yet, then loads on rendered path arrival',
        () async {
          final sourceVideoPath = '${tempDir.path}/empty_source.mp4';
          final renderedVideoPath = '${tempDir.path}/empty_rendered.mp4';

          final sourceClip = _createFileClip(
            id: 'src',
            videoPath: sourceVideoPath,
            seconds: 10,
          );
          fakeStreamManager.sync(clips: [sourceClip], devicePixelRatio: 1);
          expect(controllers, hasLength(1));

          // Source frames haven't been extracted yet — seeding is
          // best-effort: the target is created empty but still marked
          // seeded so [sync] does not spin up a subscription against the
          // un-trimmed source video.
          fakeStreamManager.seedFromSource(
            sourceClipId: 'src',
            targetClipId: 'end',
            sourceRange: const DurationRange(
              start: Duration(seconds: 3),
              end: Duration(seconds: 10),
            ),
            timestampOffset: Duration.zero,
            rebaseOnPathChange: const Duration(seconds: 3),
            currentSourcePath: sourceVideoPath,
          );
          expect(fakeStreamManager['end'].value, isEmpty);

          final previewEndClip = _createFileClip(
            id: 'end',
            videoPath: sourceVideoPath,
            seconds: 10,
          );
          fakeStreamManager.sync(clips: [previewEndClip], devicePixelRatio: 1);
          // No new subscription while the clip still points at the source.
          expect(controllers, hasLength(1));

          // Rendered file arrives — now the real subscription starts.
          final renderedEndClip = _createFileClip(
            id: 'end',
            videoPath: renderedVideoPath,
            seconds: 7,
          );
          fakeStreamManager.sync(clips: [renderedEndClip], devicePixelRatio: 1);
          expect(controllers, hasLength(2));
        },
      );
    });

    group('pauseAll / resumeAll', () {
      late StreamController<List<StripThumbnail>> streamController;
      late int pauses;
      late int resumes;
      late ClipThumbnailManager fakeStreamManager;

      const firstBatch = [
        StripThumbnail(path: '/t/a0.jpg', timestamp: Duration.zero),
      ];
      const secondBatch = [
        StripThumbnail(path: '/t/a0.jpg', timestamp: Duration.zero),
        StripThumbnail(path: '/t/a1.jpg', timestamp: Duration(seconds: 1)),
      ];

      setUp(() {
        pauses = 0;
        resumes = 0;
        streamController = StreamController<List<StripThumbnail>>(
          onPause: () => pauses++,
          onResume: () => resumes++,
        );
        fakeStreamManager = ClipThumbnailManager(
          stripThumbnailStreamFactory:
              ({
                required String videoPath,
                required String clipId,
                required Duration duration,
                required Size outputSize,
                required int thumbsPerSecond,
                List<Duration>? priorityTimestamps,
              }) => streamController.stream,
        );
      });

      tearDown(() {
        fakeStreamManager.dispose();
        // Not awaited: close() only completes once a listener receives the
        // done event, and the idle test never attaches one.
        unawaited(streamController.close());
      });

      void syncFileClip() {
        fakeStreamManager.sync(
          clips: [_createFileClip(id: 'a', videoPath: '/video/a.mp4')],
          devicePixelRatio: 1,
        );
      }

      test('are safe on an idle manager with no active subscriptions', () {
        expect(manager.pauseAll, returnsNormally);
        expect(manager.resumeAll, returnsNormally);
      });

      test(
        'pauseAll holds thumbnail delivery and resumeAll releases it',
        () async {
          syncFileClip();
          streamController.add(firstBatch);
          await pumpEventQueue();
          expect(fakeStreamManager['a'].value, hasLength(1));

          fakeStreamManager.pauseAll();
          await pumpEventQueue();
          expect(pauses, equals(1));

          streamController.add(secondBatch);
          await pumpEventQueue();
          // Buffered while paused — the notifier still shows the first batch.
          expect(fakeStreamManager['a'].value, hasLength(1));

          fakeStreamManager.resumeAll();
          await pumpEventQueue();
          expect(resumes, equals(1));
          // The held batch arrives after resume — pausing is lossless.
          expect(fakeStreamManager['a'].value, hasLength(2));
        },
      );

      test('subscriptions created while paused start paused', () async {
        fakeStreamManager.pauseAll();
        syncFileClip();
        await pumpEventQueue();
        expect(pauses, equals(1));

        streamController.add(firstBatch);
        await pumpEventQueue();
        expect(fakeStreamManager['a'].value, isEmpty);

        fakeStreamManager.resumeAll();
        await pumpEventQueue();
        expect(fakeStreamManager['a'].value, hasLength(1));
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

      test(
        'deletes a borrowed seed file once when two notifiers share it',
        () {
          final tempDir = Directory.systemTemp.createTempSync(
            'clip_thumbnail_dispose_test_',
          );
          addTearDown(() {
            if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
          });
          final borrowed = File('${tempDir.path}/borrowed.jpg')
            ..writeAsStringSync('borrowed');

          final localManager = ClipThumbnailManager();
          localManager.sync(
            clips: [
              _createFileClip(id: 'src', videoPath: '${tempDir.path}/src.mp4'),
            ],
            devicePixelRatio: 1,
          );
          localManager['src'].value = [
            StripThumbnail(path: borrowed.path, timestamp: Duration.zero),
          ];
          // The start half borrows the same source frame file, so both
          // notifiers reference it — dispose must delete it once and
          // swallow the second (already-gone) deleteSync.
          localManager.seedFromSource(
            sourceClipId: 'src',
            targetClipId: 'start',
            sourceRange: const DurationRange(
              start: Duration.zero,
              end: Duration(seconds: 1),
            ),
            currentSourcePath: '${tempDir.path}/src.mp4',
          );
          expect(
            localManager['start'].value.single.path,
            equals(borrowed.path),
          );

          expect(localManager.dispose, returnsNormally);
          expect(borrowed.existsSync(), isFalse);
        },
      );
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
