// ABOUTME: TDD tests for clip count provider
// ABOUTME: Tests reactive clip count updates for profile display

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_count_provider.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:pro_video_editor/core/models/video/editor_video_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ClipCountProvider', () {
    late ProviderContainer container;
    late ClipLibraryService clipService;
    late Directory tempDir;
    late List<File> tempFiles;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Create temp directory first so we can use its path in mock
      tempDir = await Directory.systemTemp.createTemp('clip_test_');
      tempFiles = [];

      // Mock path provider to return our temp directory
      const MethodChannel pathProviderChannel = MethodChannel(
        'plugins.flutter.io/path_provider',
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (
            MethodCall methodCall,
          ) async {
            switch (methodCall.method) {
              case 'getTemporaryDirectory':
                return tempDir.path;
              case 'getApplicationDocumentsDirectory':
                return tempDir.path;
              case 'getApplicationSupportDirectory':
                return tempDir.path;
              default:
                return null;
            }
          });

      SharedPreferences.setMockInitialValues({});
      clipService = ClipLibraryService();

      container = ProviderContainer(
        overrides: [
          clipLibraryServiceProvider.overrideWith((ref) => clipService),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      for (final file in tempFiles) {
        if (file.existsSync()) {
          await file.delete();
        }
      }
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    File createTempVideoFile(String name) {
      final file = File('${tempDir.path}/$name.mp4');
      file.writeAsStringSync('fake video');
      tempFiles.add(file);
      return file;
    }

    test('should return 0 when no clips exist', () async {
      final count = await container.read(clipCountProvider.future);
      expect(count, 0);
    });

    test('should return correct count when clips exist', () async {
      final file1 = createTempVideoFile('video1');
      final file2 = createTempVideoFile('video2');

      await clipService.saveClip(
        DivineVideoClip(
          id: 'clip_1',
          video: EditorVideo.file(file1),
          duration: const Duration(seconds: 1),
          targetAspectRatio: .square,
          recordedAt: .now(),
          originalAspectRatio: 9 / 16,
        ),
      );
      await clipService.saveClip(
        DivineVideoClip(
          id: 'clip_2',
          video: EditorVideo.file(file2),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .square,
          recordedAt: .now(),
          originalAspectRatio: 9 / 16,
        ),
      );

      container.invalidate(clipCountProvider);
      final count = await container.read(clipCountProvider.future);

      expect(count, 2);
    });

    test('should only count clips with existing video files', () async {
      final existingFile = createTempVideoFile('existing');

      await clipService.saveClip(
        DivineVideoClip(
          id: 'clip_valid',
          video: EditorVideo.file(existingFile),
          duration: const Duration(seconds: 1),
          targetAspectRatio: .square,
          recordedAt: .now(),
          originalAspectRatio: 9 / 16,
        ),
      );
      await clipService.saveClip(
        DivineVideoClip(
          id: 'clip_orphan',
          video: EditorVideo.file('/nonexistent/path.mp4'),
          targetAspectRatio: .square,
          duration: const Duration(seconds: 1),
          recordedAt: .now(),
          originalAspectRatio: 9 / 16,
        ),
      );

      container.invalidate(clipCountProvider);
      final count = await container.read(clipCountProvider.future);

      expect(count, 1);
    });
  });
}
