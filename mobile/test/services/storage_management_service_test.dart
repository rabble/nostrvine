import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

class _MockCache extends Mock implements MediaCacheManager {}

class _MockClipLibrary extends Mock implements ClipLibraryService {}

void main() {
  group(StorageManagementService, () {
    late _MockCache videoCache;
    late _MockCache imageCache;
    late _MockClipLibrary clipLibrary;
    late Directory temp;
    late Directory docs;
    late StorageManagementService service;

    setUp(() {
      videoCache = _MockCache();
      imageCache = _MockCache();
      clipLibrary = _MockClipLibrary();
      temp = Directory.systemTemp.createTempSync('storage_temp_');
      docs = Directory.systemTemp.createTempSync('storage_docs_');
      when(() => videoCache.clearCache()).thenAnswer((_) async {});
      when(() => imageCache.clearCache()).thenAnswer((_) async {});
      service = StorageManagementService(
        videoCache: videoCache,
        imageCache: imageCache,
        clipLibrary: clipLibrary,
        temporaryDirectoryProvider: () async => temp,
        documentsDirectoryProvider: () async => docs,
      );
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    });

    File writeFile(String path, int bytes) {
      final file = File(path)..parent.createSync(recursive: true);
      return file..writeAsBytesSync(List<int>.filled(bytes, 0));
    }

    DivineVideoClip clip(String id, String videoPath) => DivineVideoClip(
      id: id,
      video: editor.EditorVideo.file(File(videoPath)),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime(2024),
      targetAspectRatio: model.AspectRatio.square,
      originalAspectRatio: 1,
    );

    group('cacheSizeBytes', () {
      test('sums cache dirs, seams and temp renders, ignoring other '
          'files', () async {
        writeFile('${temp.path}/openvine_video_cache/a.mp4', 100);
        writeFile('${temp.path}/openvine_image_cache/b.jpg', 50);
        writeFile('${docs.path}/transition_seams/s.mp4', 30);
        writeFile('${temp.path}/watermarked_1.mp4', 20);
        writeFile('${temp.path}/merged_2.mp4', 10);
        writeFile('${temp.path}/unrelated.txt', 5);
        writeFile('${docs.path}/my_clip.mp4', 999);

        expect(await service.cacheSizeBytes(), 100 + 50 + 30 + 20 + 10);
      });

      test('returns zero when nothing is cached', () async {
        expect(await service.cacheSizeBytes(), 0);
      });
    });

    group('clearCaches', () {
      test('clears both caches, deletes temp renders and seams, keeps other '
          'files', () async {
        final watermark = writeFile('${temp.path}/watermarked_1.mp4', 20);
        final merged = writeFile('${temp.path}/merged_2.mp4', 10);
        final seam = writeFile('${docs.path}/transition_seams/s.mp4', 30);
        final unrelated = writeFile('${temp.path}/unrelated.txt', 5);
        final userClip = writeFile('${docs.path}/my_clip.mp4', 999);

        await service.clearCaches();

        verify(() => videoCache.clearCache()).called(1);
        verify(() => imageCache.clearCache()).called(1);
        expect(watermark.existsSync(), isFalse);
        expect(merged.existsSync(), isFalse);
        expect(seam.existsSync(), isFalse);
        expect(unrelated.existsSync(), isTrue, reason: 'non-render temp kept');
        expect(userClip.existsSync(), isTrue, reason: 'user clip untouched');
      });

      test('does not throw when nothing exists to clear', () async {
        await expectLater(service.clearCaches(), completes);
      });
    });

    group('findBrokenClips', () {
      test('returns only clips whose backing file is missing', () async {
        final present = writeFile('${docs.path}/present.mp4', 10);
        final good = clip('good', present.path);
        final broken = clip('broken', '${docs.path}/gone.mp4');
        when(
          clipLibrary.getAllClips,
        ).thenAnswer((_) async => [good, broken]);

        final result = await service.findBrokenClips();

        expect(result.map((c) => c.id), equals(['broken']));
      });
    });

    group('removeBrokenClips', () {
      test('hard-deletes each given clip', () async {
        when(() => clipLibrary.hardDelete(any())).thenAnswer((_) async {});
        final broken = [
          clip('a', '${docs.path}/gone_a.mp4'),
          clip('b', '${docs.path}/gone_b.mp4'),
        ];

        await service.removeBrokenClips(broken);

        verify(() => clipLibrary.hardDelete('a')).called(1);
        verify(() => clipLibrary.hardDelete('b')).called(1);
      });
    });
  });
}
