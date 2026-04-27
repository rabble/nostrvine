// ABOUTME: Tests for importing classic Vine videos into the local clip library.
// ABOUTME: Covers validation, file copying, clip creation, and save failures.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/classic_vine_clip_import_service.dart';
import 'package:openvine/services/clip_library_service.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _FakeDivineVideoClip extends Fake implements DivineVideoClip {}

models.VideoEvent _video({
  String id = 'classic-vine-event-id',
  String? videoUrl = 'https://cdn.example.com/classic.mp4',
  int? duration = 6,
  String? dimensions = '480x480',
  Map<String, String> rawTags = const {'platform': 'vine'},
}) {
  return models.VideoEvent(
    id: id,
    pubkey: 'classic-vine-author-pubkey',
    createdAt: 1451606400,
    content: 'classic vine',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      1451606400 * 1000,
      isUtc: true,
    ),
    videoUrl: videoUrl,
    duration: duration,
    dimensions: dimensions,
    rawTags: rawTags,
    vineId: 'vine-123',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDivineVideoClip());
  });

  late Directory tempDir;
  late Directory docsDir;
  late File sourceVideo;
  late _MockClipLibraryService clipLibraryService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'classic_vine_import_test_',
    );
    docsDir = Directory('${tempDir.path}/documents')..createSync();
    sourceVideo = File('${tempDir.path}/source.mp4')
      ..writeAsBytesSync(List<int>.filled(16, 7));
    clipLibraryService = _MockClipLibraryService();
    when(() => clipLibraryService.saveClip(any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ClassicVineClipImportService buildService({
    Future<File?> Function({
      required String url,
      required String cacheKey,
    })?
    downloadVideo,
    Future<ClassicVineThumbnail?> Function({
      required String videoPath,
      required Duration targetTimestamp,
    })?
    extractThumbnail,
    Future<String?> Function({
      required String videoPath,
      required Duration videoDuration,
    })?
    extractLastFrame,
    DateTime? now,
  }) {
    return ClassicVineClipImportService(
      clipLibraryService: clipLibraryService,
      getDocumentsPath: () async => docsDir.path,
      downloadVideo:
          downloadVideo ??
          ({required url, required cacheKey}) async => sourceVideo,
      extractThumbnail:
          extractThumbnail ??
          ({required videoPath, required targetTimestamp}) async {
            final thumbnail = File('${docsDir.path}/thumb.jpg')
              ..writeAsBytesSync(const [1, 2, 3]);
            return ClassicVineThumbnail(
              path: thumbnail.path,
              timestamp: targetTimestamp,
            );
          },
      extractLastFrame:
          extractLastFrame ??
          ({required videoPath, required videoDuration}) async {
            final ghost = File('${docsDir.path}/ghost.jpg')
              ..writeAsBytesSync(const [4, 5, 6]);
            return ghost.path;
          },
      now: () => now ?? DateTime.utc(2026, 4, 27, 12),
    );
  }

  test('imports a classic Vine as a saved square library clip', () async {
    final service = buildService();

    final result = await service.importToLibrary(_video());

    expect(result, isA<ClassicVineClipImportSuccess>());
    final success = result as ClassicVineClipImportSuccess;
    expect(success.clip.id, startsWith('classic_vine_vine-123_'));
    expect(success.clip.duration, const Duration(seconds: 6));
    expect(success.clip.targetAspectRatio, models.AspectRatio.square);
    expect(success.clip.originalAspectRatio, 1);
    expect(success.clip.thumbnailPath, endsWith('thumb.jpg'));
    expect(success.clip.ghostFramePath, endsWith('ghost.jpg'));
    expect(success.clip.video.file!.path, startsWith(docsDir.path));
    expect(
      File(success.clip.video.file!.path).readAsBytesSync(),
      sourceVideo.readAsBytesSync(),
    );

    final captured =
        verify(
              () => clipLibraryService.saveClip(captureAny()),
            ).captured.single
            as DivineVideoClip;
    expect(captured.id, success.clip.id);
  });

  test('rejects non-classic videos without saving', () async {
    final service = buildService();

    final result = await service.importToLibrary(
      _video(rawTags: const {'platform': 'divine'}),
    );

    expect(
      result,
      isA<ClassicVineClipImportFailure>().having(
        (result) => result.reason,
        'reason',
        ClassicVineClipImportFailureReason.notClassicVine,
      ),
    );
    verifyNever(() => clipLibraryService.saveClip(any()));
  });

  test('returns missingVideoUrl when no playable URL is available', () async {
    final service = buildService();

    final result = await service.importToLibrary(_video(videoUrl: null));

    expect(
      result,
      isA<ClassicVineClipImportFailure>().having(
        (result) => result.reason,
        'reason',
        ClassicVineClipImportFailureReason.missingVideoUrl,
      ),
    );
    verifyNever(() => clipLibraryService.saveClip(any()));
  });

  test('returns downloadFailed when the cache cannot provide a file', () async {
    final service = buildService(
      downloadVideo: ({required url, required cacheKey}) async => null,
    );

    final result = await service.importToLibrary(_video());

    expect(
      result,
      isA<ClassicVineClipImportFailure>().having(
        (result) => result.reason,
        'reason',
        ClassicVineClipImportFailureReason.downloadFailed,
      ),
    );
    verifyNever(() => clipLibraryService.saveClip(any()));
  });
}
