// ABOUTME: Tests for CacheRecoveryService's directory clearing
// ABOUTME: Pins #4968 — the durable database dir is preserved while caches are cleared

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/cache_recovery_service.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_helpers.dart';

void main() {
  group(CacheRecoveryService, () {
    group('Hive box clearing', () {
      late Directory tmp;

      setUpAll(() async {
        await initializeServiceTestEnvironment();
        if (!Hive.isAdapterRegistered(1)) {
          Hive.registerAdapter(UploadStatusAdapter());
        }
        if (!Hive.isAdapterRegistered(2)) {
          Hive.registerAdapter(PendingUploadAdapter());
        }
      });

      setUp(() async {
        tmp = Directory.systemTemp.createTempSync('cache_recovery_hive_test');
        Hive.init(tmp.path);
        await TestHelpers.cleanupHiveBox('pending_uploads');
        await TestHelpers.cleanupHiveBox('video_cache');
      });

      tearDown(() async {
        await TestHelpers.cleanupHiveBox('pending_uploads');
        await TestHelpers.cleanupHiveBox('video_cache');
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      test(
        'preserves pending uploads while clearing disposable Hive caches',
        () async {
          final pendingUploads = Hive.isBoxOpen('pending_uploads')
              ? Hive.box<PendingUpload>('pending_uploads')
              : await Hive.openBox<PendingUpload>('pending_uploads');
          final videoCache = Hive.isBoxOpen('video_cache')
              ? Hive.box('video_cache')
              : await Hive.openBox('video_cache');
          final upload = PendingUpload.create(
            localVideoPath: '/tmp/durable-upload.mp4',
            nostrPubkey:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          );
          await pendingUploads.put(upload.id, upload);
          await videoCache.put('cache-id', 'cached video');

          await CacheRecoveryService.clearHiveBoxesForTesting();

          expect(
            Hive.box<PendingUpload>(
              'pending_uploads',
            ).get(upload.id)?.localVideoPath,
            upload.localVideoPath,
          );
          if (Hive.isBoxOpen('video_cache')) {
            expect(Hive.box('video_cache').get('cache-id'), isNull);
          }
        },
      );
    });

    group('deleteDirectoryContentsExcept', () {
      late Directory tmp;

      setUp(() {
        tmp = Directory.systemTemp.createTempSync('cache_recovery_test');
      });

      tearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      File write(String relative, String contents) {
        final file = File(p.join(tmp.path, relative))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(contents);
        return file;
      }

      test(
        'preserves the protected database dir and clears everything else',
        () async {
          // Mirror the real Application Support layout.
          final db = write('openvine/database/divine_db.db', 'data');
          final dbWal = write('openvine/database/divine_db.db-wal', 'wal');
          final dbVersion = write('openvine/database/divine_db.version', '2');
          final cacheSync = write('openvine/cache/cache_sync.db', 'cache');
          final other = write('other/scratch.txt', 'scratch');
          final top = write('top_level.txt', 'top');

          final protectedPath = p.join(tmp.path, 'openvine', 'database');
          final cleared =
              await CacheRecoveryService.deleteDirectoryContentsExcept(
                tmp,
                protectedPath: protectedPath,
              );

          // Durable DB subtree survives entirely.
          expect(
            db.existsSync(),
            isTrue,
            reason: 'durable DB file must survive',
          );
          expect(dbWal.existsSync(), isTrue);
          expect(dbVersion.existsSync(), isTrue);
          expect(Directory(protectedPath).existsSync(), isTrue);

          // Disposable caches and unrelated entries are gone.
          expect(cacheSync.existsSync(), isFalse);
          expect(
            Directory(p.join(tmp.path, 'openvine', 'cache')).existsSync(),
            isFalse,
          );
          expect(other.existsSync(), isFalse);
          expect(top.existsSync(), isFalse);

          // The ancestor dir of the protected subtree is kept (it holds it).
          expect(
            Directory(p.join(tmp.path, 'openvine')).existsSync(),
            isTrue,
          );
          expect(cleared, greaterThan(0));
        },
      );

      test('clears everything when the protected dir is absent', () async {
        write('openvine/cache/cache_sync.db', 'cache');
        write('top_level.txt', 'top');

        final protectedPath = p.join(tmp.path, 'openvine', 'database');
        await CacheRecoveryService.deleteDirectoryContentsExcept(
          tmp,
          protectedPath: protectedPath,
        );

        expect(tmp.listSync(), isEmpty);
      });

      test('preserves the protected dir even at the top level', () async {
        final db = write('divine_db.db', 'data');
        write('scratch.txt', 'scratch');

        // Protect the file's own directory (the temp root would be too broad);
        // use a top-level protected directory instead.
        final protectedDir = Directory(p.join(tmp.path, 'db'))
          ..createSync(recursive: true);
        final keep = File(p.join(protectedDir.path, 'divine_db.db'))
          ..writeAsStringSync('keep');
        db.deleteSync();

        await CacheRecoveryService.deleteDirectoryContentsExcept(
          tmp,
          protectedPath: protectedDir.path,
        );

        expect(keep.existsSync(), isTrue);
        expect(File(p.join(tmp.path, 'scratch.txt')).existsSync(), isFalse);
      });

      test('does not clear contents when dir is the protected dir', () async {
        final protectedDir = Directory(p.join(tmp.path, 'openvine', 'database'))
          ..createSync(recursive: true);
        final keep = File(p.join(protectedDir.path, 'divine_db.db'))
          ..writeAsStringSync('keep');

        final cleared =
            await CacheRecoveryService.deleteDirectoryContentsExcept(
              protectedDir,
              protectedPath: protectedDir.path,
            );

        expect(cleared, 0);
        expect(keep.existsSync(), isTrue);
      });
    });
  });
}
