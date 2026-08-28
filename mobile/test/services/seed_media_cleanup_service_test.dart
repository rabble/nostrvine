// ABOUTME: Unit tests for SeedMediaCleanupService
// ABOUTME: Pins the marker-gated deletion of stranded seed media (#8242)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/seed_media_cleanup_service.dart';
import 'package:path/path.dart' as path;

void main() {
  group(SeedMediaCleanupService, () {
    late Directory tempDir;
    late Directory cacheDir;
    late SeedMediaCleanupService service;

    const seedVideoName =
        '606486ed7079b4b2614e9ca3e0f46c1c9a4a39d52c90dd25a9e51d1b7cf96b33';
    const seedThumbnailName = 'thumbnail_$seedVideoName.jpg';
    const markerName = '.seed_media_loaded';

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('seed_cleanup_test_');
      cacheDir = Directory(path.join(tempDir.path, 'openvine_video_cache'))
        ..createSync(recursive: true);
      service = SeedMediaCleanupService(
        tempDirectoryProvider: () async => tempDir,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    File writeFile(String name, [int bytes = 8]) {
      return File(path.join(cacheDir.path, name))
        ..writeAsBytesSync(List<int>.filled(bytes, 0));
    }

    group('cleanUpStrandedSeedMediaIfNeeded', () {
      test('deletes seed videos, seed thumbnails, and the marker', () async {
        final marker = writeFile(markerName);
        final seedVideo = writeFile(seedVideoName, 128);
        final seedThumbnail = writeFile(seedThumbnailName, 16);

        await service.cleanUpStrandedSeedMediaIfNeeded();

        expect(seedVideo.existsSync(), isFalse, reason: 'seed video removed');
        expect(
          seedThumbnail.existsSync(),
          isFalse,
          reason: 'seed thumbnail removed',
        );
        expect(marker.existsSync(), isFalse, reason: 'marker removed last');
      });

      test('preserves every non-seed shape in the shared directory', () async {
        writeFile(markerName);
        final managed = writeFile('vid_key_1787621868807443_1.mp4');
        final uuidNamed = writeFile(
          '1b4e28ba-2fa1-11d2-883f-0016d3cca427.mp4',
        );
        final aliases = writeFile('aliases.json');
        final shortThumbnail = writeFile('thumbnail_short.jpg');
        final uppercaseHex = writeFile(seedVideoName.toUpperCase());
        final nested = Directory(path.join(cacheDir.path, 'nested'))
          ..createSync();

        await service.cleanUpStrandedSeedMediaIfNeeded();

        expect(managed.existsSync(), isTrue, reason: 'managed download kept');
        expect(uuidNamed.existsSync(), isTrue, reason: 'uuid download kept');
        expect(aliases.existsSync(), isTrue, reason: 'alias manifest kept');
        expect(
          shortThumbnail.existsSync(),
          isTrue,
          reason: 'non-64-hex thumbnail kept',
        );
        expect(
          uppercaseHex.existsSync(),
          isTrue,
          reason: 'uppercase hex is not a seed write',
        );
        expect(nested.existsSync(), isTrue, reason: 'subdirectory kept');
      });

      test('is a no-op without the marker', () async {
        final seedVideo = writeFile(seedVideoName);

        await service.cleanUpStrandedSeedMediaIfNeeded();

        expect(
          seedVideo.existsSync(),
          isTrue,
          reason: 'only installs the preloader wrote to are swept',
        );
      });

      test('is a no-op when the cache directory is absent', () async {
        cacheDir.deleteSync(recursive: true);

        await expectLater(
          service.cleanUpStrandedSeedMediaIfNeeded(),
          completes,
        );
      });

      test(
        'keeps the marker for retry when a deletion fails',
        () async {
          final marker = writeFile(markerName);
          writeFile(seedVideoName);
          // Read+execute only: listing works, unlinking child entries fails.
          Process.runSync('chmod', ['555', cacheDir.path]);
          addTearDown(() {
            Process.runSync('chmod', ['755', cacheDir.path]);
          });

          await service.cleanUpStrandedSeedMediaIfNeeded();

          expect(
            marker.existsSync(),
            isTrue,
            reason: 'partial cleanup retries on the next launch',
          );
        },
        skip: !Platform.isMacOS && !Platform.isLinux,
      );
    });
  });
}
