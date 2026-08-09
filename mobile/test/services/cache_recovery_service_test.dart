// ABOUTME: Tests for CacheRecoveryService's directory clearing
// ABOUTME: Pins #4968 — the durable database dir is preserved while caches are cleared

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/cache_recovery_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../helpers/test_helpers.dart';
import '../mocks/mock_path_provider_platform.dart';

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
        await TestHelpers.cleanupHiveBox('notifications');
        await TestHelpers.cleanupHiveBox('pending_uploads');
        await TestHelpers.cleanupHiveBox('video_cache');
      });

      tearDown(() async {
        await TestHelpers.cleanupHiveBox('notifications');
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
          expect(Hive.isBoxOpen('video_cache'), isFalse);
          final reopenedVideoCache = await Hive.openBox('video_cache');
          addTearDown(reopenedVideoCache.close);
          expect(reopenedVideoCache.get('cache-id'), isNull);
        },
      );

      test(
        'preserves durable notification preferences while clearing caches',
        () async {
          final notifications = Hive.isBoxOpen('notifications')
              ? Hive.box('notifications')
              : await Hive.openBox('notifications');
          final videoCache = Hive.isBoxOpen('video_cache')
              ? Hive.box('video_cache')
              : await Hive.openBox('video_cache');
          const preferences = NotificationPreferences(commentsEnabled: false);
          final storedPreferences = jsonEncode(preferences.toJson());
          await notifications.put('push_preferences', storedPreferences);
          await videoCache.put('cache-id', 'cached video');

          await CacheRecoveryService.clearHiveBoxesForTesting();

          expect(
            Hive.box('notifications').get('push_preferences'),
            storedPreferences,
          );
          expect(Hive.isBoxOpen('video_cache'), isFalse);
          final reopenedVideoCache = await Hive.openBox('video_cache');
          addTearDown(reopenedVideoCache.close);
          expect(reopenedVideoCache.get('cache-id'), isNull);
        },
      );
    });

    group('full cache recovery', () {
      late Directory tmp;
      late PathProviderPlatform originalPathProviderInstance;

      setUp(() {
        tmp = Directory.systemTemp.createTempSync('cache_recovery_full_test');
        originalPathProviderInstance = PathProviderPlatform.instance;
        final mockPathProvider = MockPathProviderPlatform()
          ..setTemporaryPath(p.join(tmp.path, 'temp'))
          ..setApplicationSupportPath(p.join(tmp.path, 'support'))
          ..setApplicationCachePath(p.join(tmp.path, 'cache'));
        PathProviderPlatform.instance = mockPathProvider;
      });

      tearDown(() {
        PathProviderPlatform.instance = originalPathProviderInstance;
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      File write(String relative, String contents) {
        final file = File(p.join(tmp.path, relative))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(contents);
        return file;
      }

      test('preserves durable pending uploads during clearAllCaches', () async {
        final db = write('support/openvine/database/divine_db.db', 'database');
        final pendingUploads = write(
          'support/openvine/pending_uploads.hive',
          'pending uploads',
        );
        final pendingUploadsLock = write(
          'support/openvine/pending_uploads.lock',
          'lock',
        );
        final cacheSync = write(
          'support/openvine/cache/cache_sync.db',
          'cache',
        );
        final scratch = write('support/openvine/scratch.txt', 'scratch');
        final temp = write('temp/transient.tmp', 'temp');
        final cache = write('cache/download.bin', 'cache');

        final recovered = await CacheRecoveryService.clearAllCaches();

        expect(recovered, isTrue);
        expect(db.existsSync(), isTrue);
        expect(pendingUploads.existsSync(), isTrue);
        expect(pendingUploadsLock.existsSync(), isTrue);
        expect(cacheSync.existsSync(), isFalse);
        expect(scratch.existsSync(), isFalse);
        expect(temp.existsSync(), isFalse);
        expect(cache.existsSync(), isFalse);
      });
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
          expect(Directory(p.join(tmp.path, 'openvine')).existsSync(), isTrue);
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
