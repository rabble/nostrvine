// ABOUTME: Unit tests for SeedMediaPreloadService
// ABOUTME: Tests bundled media file preloading into cache directory on first launch

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/seed_media_preload_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider_platform.dart';

/// Wires up a mock handler for `flutter/assets` so [rootBundle] reads return
/// [manifestPayload] for the seed-media manifest path and [videoPayload] for
/// any `.mp4` asset path. Returning [Uint8List] from a single source-of-truth
/// here keeps the handler stable across [setUp] / test-body boundaries — see
/// the `seed_data_preload_service_test.dart` pattern.
void _mockSeedMediaAssets({
  required String manifestPayload,
  Uint8List? videoBytes,
  bool Function(String assetName)? videoMatcher,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        if (message == null) return null;
        final assetName = utf8.decode(message.buffer.asUint8List());

        if (assetName == 'assets/seed_media/manifest.json') {
          final bytes = Uint8List.fromList(utf8.encode(manifestPayload));
          return ByteData.sublistView(bytes);
        }

        if (videoBytes != null &&
            (videoMatcher?.call(assetName) ?? assetName.endsWith('.mp4'))) {
          return ByteData.sublistView(videoBytes);
        }

        return null;
      });
}

void _clearAssetMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SeedMediaPreloadService', () {
    late Directory tempDir;
    late MockPathProviderPlatform mockPathProvider;
    late PathProviderPlatform originalPathProviderInstance;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('seed_media_test_');

      originalPathProviderInstance = PathProviderPlatform.instance;
      mockPathProvider = MockPathProviderPlatform();
      mockPathProvider.setTemporaryPath(tempDir.path);
      PathProviderPlatform.instance = mockPathProvider;

      // rootBundle caches across tests in the merged VGV runner. Drop any
      // cached payloads so the per-test asset mock is always observed.
      rootBundle.clear();
      _clearAssetMock();
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPathProviderInstance;

      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }

      rootBundle.clear();
      _clearAssetMock();
    });

    test(
      'loadSeedMediaIfNeeded skips load when cache already populated',
      () async {
        final cacheDir = Directory(
          path.join(tempDir.path, 'openvine_video_cache'),
        );
        await cacheDir.create(recursive: true);

        final markerFile = File(path.join(cacheDir.path, '.seed_media_loaded'));
        await markerFile.writeAsString('loaded');

        await SeedMediaPreloadService.loadSeedMediaIfNeeded();

        expect(
          markerFile.existsSync(),
          isTrue,
          reason: 'Marker file should still exist',
        );
      },
    );

    test(
      'loadSeedMediaIfNeeded copies bundled videos to cache when empty',
      () async {
        final manifestJson = jsonEncode({
          'videos': [
            {
              'eventId':
                  'test_event_1111111111111111111111111111111111111111111111111111111111111111',
              'filename':
                  'test_event_1111111111111111111111111111111111111111111111111111111111111111.mp4',
              'url': 'https://test.com/video1.mp4',
              'size': 1024,
            },
          ],
          'thumbnails': [],
          'generatedAt': '2025-11-10T00:00:00.000000',
        });

        _mockSeedMediaAssets(
          manifestPayload: manifestJson,
          videoBytes: Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
        );

        await SeedMediaPreloadService.loadSeedMediaIfNeeded();

        final cacheDir = Directory(
          path.join(tempDir.path, 'openvine_video_cache'),
        );
        final markerFile = File(path.join(cacheDir.path, '.seed_media_loaded'));
        expect(
          markerFile.existsSync(),
          isTrue,
          reason: 'Marker file should be created after load',
        );
      },
    );

    test('loadSeedMediaIfNeeded handles missing manifest gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
            return null;
          });

      expect(
        () async => SeedMediaPreloadService.loadSeedMediaIfNeeded(),
        returnsNormally,
        reason: 'Missing manifest should be non-critical',
      );
    });

    test(
      'loadSeedMediaIfNeeded handles corrupted manifest gracefully',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', (ByteData? message) async {
              if (message == null) return null;
              final bytes = Uint8List.fromList(utf8.encode('not valid json'));
              return ByteData.sublistView(bytes);
            });

        expect(
          () async => SeedMediaPreloadService.loadSeedMediaIfNeeded(),
          returnsNormally,
          reason: 'Corrupted manifest should be non-critical',
        );
      },
    );

    test(
      'loadSeedMediaIfNeeded uses eventId as filename in cache directory',
      () async {
        const testEventId =
            'unique0000test1111cafe2222beef3333dead4444face5555abcd6666ef0012345678';
        const testFilename = '$testEventId.mp4';
        final manifestJson = jsonEncode({
          'videos': [
            {
              'eventId': testEventId,
              'filename': testFilename,
              'url': 'https://test.com/video.mp4',
              'size': 512,
            },
          ],
          'thumbnails': [],
          'generatedAt': '2025-11-10T00:00:00.000000',
        });

        final testVideoBytes = Uint8List.fromList([
          0xAB,
          0xCD,
          0xEF,
          0x01,
          0x23,
          0x45,
        ]);

        _mockSeedMediaAssets(
          manifestPayload: manifestJson,
          videoBytes: testVideoBytes,
          videoMatcher: (assetName) =>
              assetName.contains('unique0000test1111') &&
              assetName.endsWith('.mp4'),
        );

        await SeedMediaPreloadService.loadSeedMediaIfNeeded();

        final cacheDir = Directory(
          path.join(tempDir.path, 'openvine_video_cache'),
        );
        final videoFile = File(path.join(cacheDir.path, testEventId));

        expect(
          videoFile.existsSync(),
          isTrue,
          reason: 'Video file should exist with eventId as filename',
        );

        final fileBytes = await videoFile.readAsBytes();
        expect(
          fileBytes,
          equals(testVideoBytes),
          reason: 'File content should match asset bytes',
        );
      },
    );
  });
}
