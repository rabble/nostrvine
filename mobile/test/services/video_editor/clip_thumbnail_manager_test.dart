// ABOUTME: Unit tests for ClipThumbnailManager.
// ABOUTME: Validates notifier lifecycle, sync logic, and disposal.

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
        final clips = [
          _createTestClip(id: 'a'),
          _createTestClip(id: 'b'),
        ];

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
        manager.sync(
          clips: [_createTestClip(id: 'a')],
          devicePixelRatio: 1,
        );

        expect(manager['a'], isA<ValueNotifier<List<StripThumbnail>>>());
        expect(
          () => manager['b'],
          throwsA(isA<TypeError>()),
        );
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
        manager.sync(
          clips: [_createTestClip(id: 'a')],
          devicePixelRatio: 1,
        );

        manager.sync(clips: [], devicePixelRatio: 1);

        expect(
          () => manager['a'],
          throwsA(isA<TypeError>()),
        );
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
}

/// Creates a test clip whose [EditorVideo] has no local file so
/// [ClipThumbnailManager._loadThumbnails] exits early without
/// triggering a platform channel call.
DivineVideoClip _createTestClip({
  required String id,
  int seconds = 3,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.network('https://example.com/$id.mp4'),
    duration: Duration(seconds: seconds),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: .vertical,
  );
}
