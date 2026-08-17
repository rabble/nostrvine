// ABOUTME: Tests for ClipRecoveryService — the developer rescue for clips the
// ABOUTME: app can no longer show: hidden owners and unreferenced files.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/clip_recovery.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/clip_recovery_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
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
      test('counts rows with no owner as visible, not as hidden', () async {
        // Every scoped query is `owner = ? OR owner IS NULL`, so an unowned row
        // is already showing in the library. Grouping it as hidden told the
        // operator to recover a clip they could see, and offered a claim that
        // changes nothing about its visibility — the opposite of what a
        // diagnostic that has to separate two failure modes should say.
        await saveClipOwnedBy(null, 'unowned');
        expect(
          (await libraryFor(_ownerA).getAllClips()).map((c) => c.id),
          ['unowned'],
          reason: 'the app already shows it, so the scan must agree',
        );

        final report = await serviceFor(_ownerA).scanRecoverableClips();

        expect(report.ownedClipCount, 1);
        expect(report.foreignGroups, isEmpty);
        expect(report.hasRecoverableContent, isFalse);
      });

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

      test('lists recordings no row references, with a preview', () async {
        // Referenced by a clip row, so not an orphan.
        writeVideo('VID_1755400000001.mp4');
        await saveClipOwnedBy(_ownerA, 'VID_1755400000001');
        final orphan = writeVideo('VID_1755400000000.mp4', bytes: 512);

        final report = await serviceFor(_ownerA).scanRecoverableClips();

        expect(
          report.orphanFiles.map((f) => f.path),
          [orphan.path],
          reason: 'a file a clip row still points at is not orphaned',
        );
        expect(report.orphanBytes, 512);
        // The operator restores one file at a time, so each row has to carry
        // enough to tell the recordings apart.
        expect(report.orphanFiles.single.previewPath, '${orphan.path}.jpg');
        expect(report.orphanFiles.single.duration, const Duration(seconds: 3));
      });

      test('recognises the recording names of every platform', () async {
        // The camera names its output differently per platform, and matching
        // only one shape made the whole feature a no-op on the other: Android
        // formats yyyyMMdd_HHmmss, iOS and macOS use epoch milliseconds.
        final android = writeVideo('VID_20260814_113531.mp4');
        final apple = writeVideo('VID_1786700133469.mp4');

        final report = await serviceFor(_ownerA).scanRecoverableClips();

        expect(
          report.orphanFiles.map((f) => f.path).toSet(),
          {android.path, apple.path},
        );
      });

      test('offers only camera recordings, never derived renders', () async {
        // The documents directory is full of mp4s derived from a clip. They
        // cannot be blacklisted — the chroma-key bake and transform services
        // write a bare timestamp with no prefix — so only the camera's own
        // output shape is offered.
        writeVideo('VID_1755400000000.mp4.work.mp4');
        writeVideo('merged_1755400000000.mp4');
        writeVideo('watermarked_1755400000000.mp4');
        writeVideo('c2pa_signed_1755400000000.mp4');
        writeVideo('clip_1755400000000_0_reversed.mp4');
        writeVideo('trimmed_1755400000000.mp4');
        writeVideo('1755400000000.mp4');

        final report = await serviceFor(_ownerA).scanRecoverableClips();

        expect(report.orphanFiles, isEmpty);
        expect(report.hasRecoverableContent, isFalse);
      });

      test('drops zero-byte recordings', () async {
        // A failed render or an aborted signing pass leaves empty mp4s that
        // restore into nothing; listing them buries the real recordings.
        writeVideo('VID_1755400000000.mp4', bytes: 0);

        final report = await serviceFor(_ownerA).scanRecoverableClips();

        expect(report.orphanFiles, isEmpty);
      });

      test('still lists a recording whose metadata cannot be read', () async {
        // No duration is a warning to the operator, not grounds for hiding a
        // file that may still hold their recording.
        writeVideo('VID_1755400000000.mp4');
        final service = serviceFor(
          _ownerA,
          metadataProvider: (_) async =>
              throw const FileSystemException('unreadable'),
        );

        final report = await service.scanRecoverableClips();

        expect(report.orphanFiles, hasLength(1));
        expect(report.orphanFiles.single.duration, isNull);
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

      test('refuses to claim onto the anonymous marker', () async {
        // The reachable "no account" case: the owner resolver falls back to the
        // marker, never to null. Claiming onto it would move a real account's
        // rows into the bucket every owner-scoped query hides — the failure
        // this feature exists to undo.
        await saveClipOwnedBy(_ownerB, 'hidden');
        // Built directly rather than scanned: an unscoped library sees every
        // row, so a scan run without an account reports nothing as hidden.
        const group = ClipOwnerGroup(
          ownerPubkey: _ownerB,
          clipCount: 1,
          draftCount: 0,
        );

        await expectLater(
          serviceFor(DraftStorageService.anonymousOwnerPubkey).claimOwnerGroup(
            group,
          ),
          throwsA(isA<NoAccountToRecoverToException>()),
        );
        expect(await libraryFor(_ownerB).getAllClips(), hasLength(1));
      });

      test('refuses to claim with no owner at all', () async {
        await saveClipOwnedBy(_ownerB, 'hidden');
        const group = ClipOwnerGroup(
          ownerPubkey: _ownerB,
          clipCount: 1,
          draftCount: 0,
        );

        await expectLater(
          serviceFor(null).claimOwnerGroup(group),
          throwsA(isA<NoAccountToRecoverToException>()),
        );
        expect(await libraryFor(_ownerB).getAllClips(), hasLength(1));
      });
    });

    group('importOrphanFiles', () {
      test('rebuilds a library clip from one selected file', () async {
        final orphan = writeVideo('VID_1755400000000.mp4');
        writeVideo('VID_1755400000001.mp4');
        final service = serviceFor(_ownerA);
        final report = await service.scanRecoverableClips();
        expect(report.orphanFiles, hasLength(2));

        final imported = await service.importOrphanFiles([
          report.orphanFiles.firstWhere((f) => f.path == orphan.path),
        ]);

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
        final service = serviceFor(
          _ownerA,
          // Fail one file only: one unreadable recording must not abandon the
          // rest of the rescue.
          metadataProvider: (path) async {
            if (path.endsWith('VID_1755400000001.mp4')) {
              throw const FileSystemException('unreadable');
            }
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
        expect(report.orphanFiles, hasLength(2));

        final imported = await service.importOrphanFiles(report.orphanFiles);

        expect(imported, hasLength(1));
        expect(await libraryFor(_ownerA).getAllClips(), hasLength(1));
      });
    });
  });
}
