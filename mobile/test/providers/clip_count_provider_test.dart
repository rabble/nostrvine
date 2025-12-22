// ABOUTME: TDD tests for clip count provider
// ABOUTME: Tests reactive clip count updates for profile display

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_count_provider.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ClipCountProvider', () {
    late ProviderContainer container;
    late ClipLibraryService clipService;
    late Directory tempDir;
    late List<File> tempFiles;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      clipService = ClipLibraryService(prefs);

      tempDir = await Directory.systemTemp.createTemp('clip_test_');
      tempFiles = [];

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
        SavedClip(
          id: 'clip_1',
          filePath: file1.path,
          thumbnailPath: null,
          duration: const Duration(seconds: 1),
          createdAt: DateTime.now(),
          aspectRatio: 'square',
        ),
      );
      await clipService.saveClip(
        SavedClip(
          id: 'clip_2',
          filePath: file2.path,
          thumbnailPath: null,
          duration: const Duration(seconds: 2),
          createdAt: DateTime.now(),
          aspectRatio: 'square',
        ),
      );

      container.invalidate(clipCountProvider);
      final count = await container.read(clipCountProvider.future);

      expect(count, 2);
    });

    test('should only count clips with existing video files', () async {
      final existingFile = createTempVideoFile('existing');

      await clipService.saveClip(
        SavedClip(
          id: 'clip_valid',
          filePath: existingFile.path,
          thumbnailPath: null,
          duration: const Duration(seconds: 1),
          createdAt: DateTime.now(),
          aspectRatio: 'square',
        ),
      );
      await clipService.saveClip(
        SavedClip(
          id: 'clip_orphan',
          filePath: '/nonexistent/path.mp4',
          thumbnailPath: null,
          duration: const Duration(seconds: 1),
          createdAt: DateTime.now(),
          aspectRatio: 'square',
        ),
      );

      container.invalidate(clipCountProvider);
      final count = await container.read(clipCountProvider.future);

      expect(count, 1);
    });
  });
}
