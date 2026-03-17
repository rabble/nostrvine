import 'dart:io';
import 'dart:typed_data';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/classic_viner_seed_preload_service.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle({
    required this.strings,
    required this.binaries,
  });

  final Map<String, String> strings;
  final Map<String, Uint8List> binaries;

  @override
  Future<ByteData> load(String key) async {
    final bytes = binaries[key];
    if (bytes == null) {
      throw StateError('Missing binary asset: $key');
    }
    return ByteData.sublistView(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = strings[key];
    if (value == null) {
      throw StateError('Missing string asset: $key');
    }
    return value;
  }
}

void main() {
  late AppDatabase database;
  late Directory markerDirectory;

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());
    markerDirectory = await Directory.systemTemp.createTemp(
      'classic_viner_seed_test_',
    );
  });

  tearDown(() async {
    await database.close();
    if (await markerDirectory.exists()) {
      await markerDirectory.delete(recursive: true);
    }
  });

  group('ClassicVinerSeedPreloadService', () {
    test('imports bundled classic-viner profiles and archived stats', () async {
      final service = ClassicVinerSeedPreloadService(
        assetBundle: _FakeAssetBundle(
          strings: {
            ClassicVinerSeedPreloadService.manifestAssetPath: _manifestJson,
          },
          binaries: const {},
        ),
        markerDirectoryProvider: () async => markerDirectory,
      );

      await service.importProfilesIfNeeded(
        userProfilesDao: database.userProfilesDao,
        profileStatsDao: database.profileStatsDao,
      );

      final profile = await database.userProfilesDao.getProfile(_pubkeyOne);
      final stats = await database.profileStatsDao.getStats(
        _pubkeyOne,
        expiry: const Duration(days: 1),
      );

      expect(profile, isNotNull);
      expect(profile!.bestDisplayName, 'Jerome Jarre');
      expect(
        profile.picture,
        'https://cdn.divine.video/classic-viners/jerome-jarre.png',
      );
      expect(stats, isNotNull);
      expect(stats!.videoCount, 312);
      expect(stats.totalViews, 128000000);
    });

    test('preloads avatar bytes once per manifest version', () async {
      final cachedWrites =
          <({String cacheKey, Uint8List bytes, String extension})>[];
      final service = ClassicVinerSeedPreloadService(
        assetBundle: _FakeAssetBundle(
          strings: {
            ClassicVinerSeedPreloadService.manifestAssetPath: _manifestJson,
          },
          binaries: {
            'assets/seed_media/classic_viner_avatars/jerome-jarre.png':
                Uint8List.fromList([1, 2, 3]),
            'assets/seed_media/classic_viner_avatars/brittany-furlan.png':
                Uint8List.fromList([4, 5, 6]),
          },
        ),
        markerDirectoryProvider: () async => markerDirectory,
      );

      Future<void> cacheWriter({
        required String cacheKey,
        required Uint8List bytes,
        required String fileExtension,
      }) async {
        cachedWrites.add((
          cacheKey: cacheKey,
          bytes: bytes,
          extension: fileExtension,
        ));
      }

      await service.preloadAvatarImagesIfNeeded(cacheWriter: cacheWriter);
      await service.preloadAvatarImagesIfNeeded(cacheWriter: cacheWriter);

      expect(cachedWrites, hasLength(2));
      expect(
        cachedWrites.map((entry) => entry.cacheKey),
        containsAll([
          'https://cdn.divine.video/classic-viners/jerome-jarre.png',
          'https://cdn.divine.video/classic-viners/brittany-furlan.png',
        ]),
      );
      expect(cachedWrites.map((entry) => entry.extension), everyElement('png'));
    });
  });
}

const _pubkeyOne =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _pubkeyTwo =
    '2222222222222222222222222222222222222222222222222222222222222222';

const _manifestJson =
    '''
{
  "version": "2026-03-17-classic-v1",
  "profiles": [
    {
      "pubkey": "$_pubkeyOne",
      "displayName": "Jerome Jarre",
      "name": "jeromejarre",
      "about": "Classic Viner archive profile",
      "pictureUrl": "https://cdn.divine.video/classic-viners/jerome-jarre.png",
      "eventId": "classic-viner-seed-jerome-jarre",
      "createdAt": "2026-03-17T00:00:00.000Z",
      "archivedStats": {
        "videoCount": 312,
        "totalViews": 128000000,
        "totalLikes": 6400000
      },
      "avatarAsset": "assets/seed_media/classic_viner_avatars/jerome-jarre.png"
    },
    {
      "pubkey": "$_pubkeyTwo",
      "displayName": "Brittany Furlan",
      "name": "brittanyfurlan",
      "about": "Classic Viner archive profile",
      "pictureUrl": "https://cdn.divine.video/classic-viners/brittany-furlan.png",
      "eventId": "classic-viner-seed-brittany-furlan",
      "createdAt": "2026-03-17T00:00:00.000Z",
      "archivedStats": {
        "videoCount": 247,
        "totalViews": 99000000,
        "totalLikes": 5400000
      },
      "avatarAsset": "assets/seed_media/classic_viner_avatars/brittany-furlan.png"
    }
  ]
}
''';
