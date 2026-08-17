// ABOUTME: Tests for ClipRecoveryService — the developer rescue for clips the
// ABOUTME: app can no longer show: hidden owners and unreferenced files.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/clip_recovery_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../mocks/mock_path_provider_platform.dart';

const _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group(ClipRecoveryService, () {
    late AppDatabase db;
    late Directory docs;
    late PathProviderPlatform originalPathProvider;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      docs = Directory.systemTemp.createTempSync('clip_recovery_docs_');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setApplicationDocumentsPath(docs.path);
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      if (docs.existsSync()) docs.deleteSync(recursive: true);
      await db.close();
    });

    ClipLibraryService libraryFor(String? owner) => ClipLibraryService(
      clipsDao: db.clipsDao,
      draftsDao: db.draftsDao,
      clipCategoriesDao: db.clipCategoriesDao,
      ownerPubkey: owner,
    );

    ClipRecoveryService serviceFor(
      String? owner, {
      Future<VideoMetadata> Function(String videoPath)? metadataProvider,
    }) => ClipRecoveryService(
      clipsDao: db.clipsDao,
      draftsDao: db.draftsDao,
      clipCategoriesDao: db.clipCategoriesDao,
      clipLibrary: libraryFor(owner),
      documentsDirectoryProvider: () async => docs,
      metadataProvider:
          metadataProvider ??
          (_) async => VideoMetadata(
            duration: const Duration(seconds: 3),
            resolution: const Size(1080, 1920),
            fileSize: 1024,
            extension: 'mp4',
            rotation: 0,
            bitrate: 2000000,
          ),
      thumbnailProvider: (path) async => '$path.jpg',
    );

    /// Saves a clip owned by [owner], bypassing the recovery service.
    Future<void> saveClipOwnedBy(String? owner, String id) =>
        libraryFor(owner).saveClip(
          DivineVideoClip(
            id: id,
            video: EditorVideo.file(p.join(docs.path, '$id.mp4')),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime(2026, 8, 17),
            targetAspectRatio: model.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

    File writeVideo(String name, {int bytes = 128}) {
      final file = File(p.join(docs.path, name));
      return file..writeAsBytesSync(List<int>.filled(bytes, 0));
    }

    group('scanRecoverableClips', () {
      test('reports rows held by other owners, not the current one', () async {
        await saveClipOwnedBy(_ownerA, 'mine');
        await saveClipOwnedBy(_ownerB, 'theirs_1');
        await saveClipOwnedBy(_ownerB, 'theirs_2');

        final report = await serviceFor(_ownerA).scanRecoverableClips();

        expect(report.currentOwnerPubkey, _ownerA);
        expect(report.ownedClipCount, 1);
        expect(report.foreignGroups, hasLength(1));
        expect(report.foreignGroups.single.ownerPubkey, _ownerB);
        expect(report.foreignGroups.single.clipCount, 2);
        expect(report.hasRecoverableContent, isTrue);
      });

      test('lists video files no row references', () async {
        // Referenced by a clip row, so not an orphan.
        writeVideo('kept.mp4');
        await saveClipOwnedBy(_ownerA, 'kept');
        final orphan = writeVideo('VID_1755400000000.mp4', bytes: 512);

        final report = await serviceFor(_ownerA).scanRecoverableClips();

        expect(
          report.orphanFiles.map((f) => f.path),
          [orphan.path],
          reason: 'a file a clip row still points at is not orphaned',
        );
        expect(report.orphanBytes, 512);
      });

      test('skips work copies and regenerable temp renders', () async {
        // Both sit in the documents directory next to real recordings and are
        // reproducible artefacts — importing them would duplicate a clip.
        writeVideo('VID_1755400000000.mp4.work.mp4');
        writeVideo('merged_1755400000000.mp4');
        writeVideo('watermarked_1755400000000.mp4');

        final report = await serviceFor(_ownerA).scanRecoverableClips();

        expect(report.orphanFiles, isEmpty);
        expect(report.hasRecoverableContent, isFalse);
      });
    });

    group('claimOwnerGroup', () {
      test("makes another owner's clips visible to this account", () async {
        await saveClipOwnedBy(_ownerB, 'hidden');
        expect(await libraryFor(_ownerA).getAllClips(), isEmpty);

        final service = serviceFor(_ownerA);
        final report = await service.scanRecoverableClips();
        final moved = await service.claimOwnerGroup(
          report.foreignGroups.single,
        );

        expect(moved, 1);
        final visible = await libraryFor(_ownerA).getAllClips();
        expect(visible.map((c) => c.id), ['hidden']);
      });

      test('refuses to claim when no account is signed in', () async {
        await saveClipOwnedBy(_ownerB, 'hidden');
        final service = serviceFor(null);
        final group =
            (await service.scanRecoverableClips()).foreignGroups.single;

        expect(await service.claimOwnerGroup(group), 0);
        expect(await libraryFor(_ownerB).getAllClips(), hasLength(1));
      });
    });

    group('importOrphanFiles', () {
      test('rebuilds a library clip from an unreferenced file', () async {
        final orphan = writeVideo('VID_1755400000000.mp4');
        final service = serviceFor(_ownerA);
        final report = await service.scanRecoverableClips();

        final imported = await service.importOrphanFiles(report.orphanFiles);

        expect(imported, hasLength(1));
        expect(imported.single.duration, const Duration(seconds: 3));
        expect(imported.single.originalAspectRatio, 1080 / 1920);
        expect(imported.single.thumbnailPath, '${orphan.path}.jpg');

        final visible = await libraryFor(_ownerA).getAllClips();
        expect(visible, hasLength(1));
        expect(
          await visible.single.requireVideo.safeFilePath(),
          endsWith('VID_1755400000000.mp4'),
        );
      });

      test('skips a file whose metadata cannot be read', () async {
        writeVideo('VID_1755400000001.mp4');
        writeVideo('VID_1755400000002.mp4');
        var calls = 0;
        final service = serviceFor(
          _ownerA,
          metadataProvider: (_) async {
            // Fail the first file only: one unreadable recording must not
            // abandon the rest of the rescue.
            if (calls++ == 0) throw const FileSystemException('unreadable');
            return VideoMetadata(
              duration: const Duration(seconds: 1),
              resolution: const Size(720, 1280),
              fileSize: 128,
              extension: 'mp4',
              rotation: 0,
              bitrate: 1000000,
            );
          },
        );
        final report = await service.scanRecoverableClips();

        final imported = await service.importOrphanFiles(report.orphanFiles);

        expect(imported, hasLength(1));
        expect(await libraryFor(_ownerA).getAllClips(), hasLength(1));
      });
    });
  });
}
