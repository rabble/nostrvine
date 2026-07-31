// ABOUTME: Pins that the thumbnail leg reports progress to the publish-facing
// ABOUTME: callback, not only to the store, so the bar keeps moving past 80%.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider_platform.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UploadManager thumbnail progress', () {
    late _MockBlossomUploadService mockBlossom;
    late UploadManager uploadManager;
    late Directory testDir;
    late PathProviderPlatform originalPathProvider;

    setUpAll(() {
      registerFallbackValue(File(''));
    });

    setUp(() async {
      testDir = await Directory.systemTemp.createTemp(
        'upload_thumbnail_progress_test_',
      );
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setTemporaryPath(testDir.path)
        ..setApplicationDocumentsPath('${testDir.path}/documents')
        ..setApplicationSupportPath('${testDir.path}/support');
      await Directory('${testDir.path}/support').create(recursive: true);

      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'check') return ['wifi'];
            return null;
          });

      mockBlossom = _MockBlossomUploadService();

      // Stands in for the native extractor: writes a real file so the
      // thumbnail leg proceeds to the upload step.
      final thumbnailPath = '${testDir.path}/thumb.jpg';
      uploadManager = UploadManager(
        blossomService: mockBlossom,
        thumbnailExtractor:
            ({
              required String videoPath,
              required Duration targetTimestamp,
              required int quality,
            }) async {
              File(thumbnailPath).writeAsBytesSync([0xFF, 0xD8, 0xFF]);
              return ThumbnailFileResult(
                path: thumbnailPath,
                timestamp: targetTimestamp,
              );
            },
      );
      await uploadManager.initialize();
    });

    tearDown(() async {
      uploadManager.dispose();
      PathProviderPlatform.instance = originalPathProvider;
      try {
        await Hive.close();
      } catch (_) {}
      try {
        await testDir.delete(recursive: true);
      } catch (_) {}
    });

    test('forwards the thumbnail leg to the publish-facing callback', () async {
      when(() => mockBlossom.isBlossomEnabled()).thenAnswer((_) async => false);
      when(
        () => mockBlossom.uploadVideoWithResume(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          proofManifestJson: any(named: 'proofManifestJson'),
          useBackgroundFirst: any(named: 'useBackgroundFirst'),
          resumableTimeout: any(named: 'resumableTimeout'),
          resumableSession: any(named: 'resumableSession'),
          onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          videoId: 'vid-1',
          url: 'https://media.divine.video/vid-1',
          fallbackUrl: 'https://media.divine.video/vid-1',
        ),
      );

      // Report a mid-transfer tick so the 85%-100% mapping is observable.
      when(
        () => mockBlossom.uploadImage(
          imageFile: any(named: 'imageFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          allowResumable: any(named: 'allowResumable'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        (invocation.namedArguments[#onProgress] as void Function(double)?)
            ?.call(0.5);
        return const BlossomUploadResult(
          success: true,
          videoId: 'thumb-1',
          url: 'https://media.divine.video/thumb-1.jpg',
          fallbackUrl: 'https://media.divine.video/thumb-1.jpg',
        );
      });

      final videoFile = File('${testDir.path}/video.mp4')
        ..writeAsBytesSync([0, 1, 2, 3]);

      final reported = <double>[];
      await uploadManager.startUpload(
        videoFile: videoFile,
        nostrPubkey: 'pubkey-1',
        onProgress: reported.add,
      );

      // Before the fix the callback jumped straight from the end of the video
      // transfer to 1.0, leaving the publish bar frozen for the whole leg.
      expect(reported, contains(0.85));
      expect(reported.any((value) => (value - 0.925).abs() < 0.0001), isTrue);
      expect(reported.last, equals(1.0));
    });
  });
}
