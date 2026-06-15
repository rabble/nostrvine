// ABOUTME: Tests for importing videos into the local clip library.
// ABOUTME: Covers validation, file copying, clip creation, and save failures.

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _FakeDivineVideoClip extends Fake implements DivineVideoClip {}

const _defaultVineId = 'vine-123';

models.VideoEvent _video({
  String id = 'classic-vine-event-id',
  String? videoUrl = 'https://cdn.example.com/classic.mp4',
  int? duration = 6,
  String? dimensions = '480x480',
  Map<String, String> rawTags = const {'platform': 'vine'},
  String? vineId = _defaultVineId,
  String? title,
  String content = 'classic vine',
  String? textTrackContent,
}) {
  return models.VideoEvent(
    id: id,
    pubkey: 'classic-vine-author-pubkey',
    createdAt: 1451606400,
    content: content,
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      1451606400 * 1000,
      isUtc: true,
    ),
    title: title,
    videoUrl: videoUrl,
    duration: duration,
    dimensions: dimensions,
    rawTags: rawTags,
    vineId: vineId,
    textTrackContent: textTrackContent,
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

  VideoClipImportService buildService({
    Future<File?> Function({
      required String url,
      required String cacheKey,
    })?
    downloadVideo,
    Future<VideoClipThumbnail?> Function({
      required String videoPath,
      required Duration targetTimestamp,
    })?
    extractThumbnail,
    Future<String?> Function({
      required String videoPath,
      required Duration videoDuration,
    })?
    extractLastFrame,
    Future<VideoMetadata> Function(EditorVideo video)? readVideoMetadata,
    DateTime? now,
  }) {
    return VideoClipImportService(
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
            return VideoClipThumbnail(
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
      // Default to a stub so the production ctor never evaluates its
      // `?? ProVideoEditor.instance.getMetadata` fallback, which would construct
      // the real MethodChannelProVideoEditor and leak EventChannel subscriptions
      // into the merged VGV optimizer isolate (#5159). Tests that exercise the
      // metadata path inject their own reader.
      readVideoMetadata:
          readVideoMetadata ??
          (video) async => VideoMetadata(
            duration: Duration.zero,
            extension: 'mp4',
            fileSize: 0,
            resolution: Size.zero,
            rotation: 0,
            bitrate: 0,
          ),
      now: () => now ?? DateTime.utc(2026, 4, 27, 12),
    );
  }

  test('imports a classic Vine as a saved square library clip', () async {
    final service = buildService();

    final result = await service.importToLibrary(_video());

    expect(result, isA<VideoClipImportSuccess>());
    final success = result as VideoClipImportSuccess;
    expect(success.clip.id, startsWith('classic_vine_vine-123_'));
    expect(success.clip.duration, const Duration(seconds: 6));
    expect(success.clip.targetAspectRatio, models.AspectRatio.square);
    expect(success.clip.originalAspectRatio, 1);
    expect(success.clip.thumbnailPath, endsWith('thumb.jpg'));
    expect(success.clip.ghostFramePath, endsWith('ghost.jpg'));
    expect(success.clip.video.file!.path, startsWith(docsDir.path));
    expect(success.clip.libraryTitle, 'classic vine');
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

  test('uses an explicit user title when importing to the library', () async {
    final service = buildService();

    final result = await service.importToLibrary(
      _video(title: 'Published title'),
      libraryTitle: 'My local cut',
    );

    final success = result as VideoClipImportSuccess;
    expect(success.clip.libraryTitle, 'My local cut');
  });

  test('derives the default library title from post title first', () async {
    final service = buildService();

    final result = await service.importToLibrary(
      _video(title: 'Published title', content: 'Published description'),
    );

    final success = result as VideoClipImportSuccess;
    expect(success.clip.libraryTitle, 'Published title');
  });

  test(
    'derives the default library title from description when title is empty',
    () async {
      final service = buildService();

      final result = await service.importToLibrary(
        _video(title: '  ', content: 'A useful description'),
      );

      final success = result as VideoClipImportSuccess;
      expect(success.clip.libraryTitle, 'A useful description');
    },
  );

  test('derives the default library title from embedded subtitles', () async {
    final service = buildService();

    final result = await service.importToLibrary(
      _video(
        title: '',
        content: '',
        textTrackContent: '''
WEBVTT

00:00.000 --> 00:02.000
First useful caption
''',
      ),
    );

    final success = result as VideoClipImportSuccess;
    expect(success.clip.libraryTitle, 'First useful caption');
  });

  test('uses a timestamp fallback when metadata has no title text', () {
    final title = VideoClipImportService.defaultLibraryTitleFor(
      _video(title: '', content: '', textTrackContent: ''),
      fallbackTime: DateTime(2026, 6, 13, 15, 45),
    );

    expect(title, 'Clip Jun 13, 3:45 PM');
  });

  test('normalizes whitespace and truncates long library titles', () {
    final title = VideoClipImportService.defaultLibraryTitleFor(
      _video(
        title:
            '  This title has     extra spaces and it keeps going past the eighty character limit for local clip names  ',
        content: 'fallback description',
      ),
    );

    expect(title, hasLength(80));
    expect(
      title,
      'This title has extra spaces and it keeps going past the eighty character limi...',
    );
  });

  test('imports an own (non-classic) video as a saved library clip', () async {
    final service = buildService();

    final result = await service.importToLibrary(
      _video(
        id: 'own-video-event-id',
        rawTags: const {'platform': 'divine'},
        vineId: null,
      ),
    );

    expect(result, isA<VideoClipImportSuccess>());
    final success = result as VideoClipImportSuccess;
    expect(success.clip.id, startsWith('own_video_own-video-event-id_'));
    verify(() => clipLibraryService.saveClip(any())).called(1);
  });

  test(
    'falls back to ProVideoEditor metadata when event dimensions are missing '
    'and resolves a vertical target ratio',
    () async {
      final service = buildService(
        readVideoMetadata: (video) async => VideoMetadata(
          duration: const Duration(seconds: 6),
          extension: 'mp4',
          fileSize: 1024,
          resolution: const Size(1080, 1920),
          rotation: 0,
          bitrate: 1000,
        ),
      );

      final result = await service.importToLibrary(
        _video(
          id: 'own-no-dims',
          rawTags: const {'platform': 'divine'},
          vineId: null,
          dimensions: null,
        ),
      );

      final success = result as VideoClipImportSuccess;
      expect(success.clip.targetAspectRatio, models.AspectRatio.vertical);
      expect(success.clip.originalAspectRatio, closeTo(1080 / 1920, 0.001));
    },
  );

  test(
    'falls back to ProVideoEditor metadata for square own videos without '
    'dimensions',
    () async {
      final service = buildService(
        readVideoMetadata: (video) async => VideoMetadata(
          duration: const Duration(seconds: 6),
          extension: 'mp4',
          fileSize: 1024,
          resolution: const Size(720, 720),
          rotation: 0,
          bitrate: 1000,
        ),
      );

      final result = await service.importToLibrary(
        _video(
          id: 'own-square',
          rawTags: const {'platform': 'divine'},
          vineId: null,
          dimensions: null,
        ),
      );

      final success = result as VideoClipImportSuccess;
      expect(success.clip.targetAspectRatio, models.AspectRatio.square);
      expect(success.clip.originalAspectRatio, 1);
    },
  );

  test(
    'maps landscape own video to square target ratio',
    () async {
      final service = buildService(
        readVideoMetadata: (video) async => VideoMetadata(
          duration: const Duration(seconds: 6),
          extension: 'mp4',
          fileSize: 1024,
          resolution: const Size(1920, 1080),
          rotation: 0,
          bitrate: 1000,
        ),
      );

      final result = await service.importToLibrary(
        _video(
          id: 'own-landscape',
          rawTags: const {'platform': 'divine'},
          vineId: null,
          dimensions: null,
        ),
      );

      final success = result as VideoClipImportSuccess;
      // Landscape videos (ratio > 1.0) satisfy _squareishMinAspectRatio and
      // intentionally map to square to match the clip library's crop policy.
      expect(success.clip.targetAspectRatio, models.AspectRatio.square);
      expect(
        success.clip.originalAspectRatio,
        closeTo(1920 / 1080, 0.001),
      );
    },
  );

  test(
    'swaps width and height when metadata reports a 90 degree rotation',
    () async {
      final service = buildService(
        readVideoMetadata: (video) async => VideoMetadata(
          duration: const Duration(seconds: 6),
          extension: 'mp4',
          fileSize: 1024,
          resolution: const Size(1920, 1080),
          rotation: 90,
          bitrate: 1000,
        ),
      );

      final result = await service.importToLibrary(
        _video(
          id: 'own-rotated',
          rawTags: const {'platform': 'divine'},
          vineId: null,
          dimensions: null,
        ),
      );

      final success = result as VideoClipImportSuccess;
      expect(success.clip.targetAspectRatio, models.AspectRatio.vertical);
      expect(success.clip.originalAspectRatio, closeTo(1080 / 1920, 0.001));
    },
  );

  test(
    'falls back to vertical target ratio when metadata probe throws',
    () async {
      final service = buildService(
        readVideoMetadata: (video) async => throw StateError('probe failed'),
      );

      final result = await service.importToLibrary(
        _video(
          id: 'own-probe-fail',
          rawTags: const {'platform': 'divine'},
          vineId: null,
          dimensions: null,
        ),
      );

      final success = result as VideoClipImportSuccess;
      expect(success.clip.targetAspectRatio, models.AspectRatio.vertical);
      expect(success.clip.originalAspectRatio, 1);
    },
  );

  test('returns missingVideoUrl when no playable URL is available', () async {
    final service = buildService();

    final result = await service.importToLibrary(_video(videoUrl: null));

    expect(
      result,
      isA<VideoClipImportFailure>().having(
        (result) => result.reason,
        'reason',
        VideoClipImportFailureReason.missingVideoUrl,
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
      isA<VideoClipImportFailure>().having(
        (result) => result.reason,
        'reason',
        VideoClipImportFailureReason.downloadFailed,
      ),
    );
    verifyNever(() => clipLibraryService.saveClip(any()));
  });
}
