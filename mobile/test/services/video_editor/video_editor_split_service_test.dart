import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  MockPathProviderPlatform({required this.documentsPath});

  final String documentsPath;

  @override
  Future<String?> getApplicationCachePath() async {
    return '/cache';
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return documentsPath;
  }
}

class MockProVideoEditor extends ProVideoEditor {
  bool shouldThrowError = false;
  bool createOutputFiles = true;
  final List<SplitVideoModel> splitRequests = [];

  @override
  Stream<dynamic> initializeStream() {
    return const Stream.empty();
  }

  @override
  Future<List<String>> splitVideo(
    SplitVideoModel value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    if (shouldThrowError) {
      throw Exception('Split failed');
    }
    splitRequests.add(value);
    // Simulate a frame-accurate split producing two files.
    if (createOutputFiles) {
      for (final outputPath in [value.startOutputPath, value.endOutputPath]) {
        final file = File(outputPath);
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync([0]);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return [value.startOutputPath, value.endOutputPath];
  }
}

// Permanent: swaps PathProviderPlatform.instance and ProVideoEditor.instance;
// keep isolated until VideoEditorSplitService accepts injected dependencies.
@Tags(['skip_very_good_optimization'])
void main() {
  late MockProVideoEditor mockProVideoEditor;
  late PathProviderPlatform originalPathProviderInstance;
  late Directory tempDir;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync(
      'openvine_split_service_test_',
    );
    originalPathProviderInstance = PathProviderPlatform.instance;
    PathProviderPlatform.instance = MockPathProviderPlatform(
      documentsPath: '${tempDir.path}/documents',
    );
    mockProVideoEditor = MockProVideoEditor();
    ProVideoEditor.instance = mockProVideoEditor;
    mockProVideoEditor.splitRequests.clear();
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProviderInstance;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('VideoEditorSplitService', () {
    group('isValidSplitPosition', () {
      test('returns true for valid split position', () {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        // Split at 2.5s - both clips will be 2.5s
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 2500),
          ),
          isTrue,
        );
      });

      test('returns false when start clip is too short', () {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        // Split at 20ms - start clip too short (min 30ms)
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 20),
          ),
          isFalse,
        );
      });

      test('returns false when end clip is too short', () {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        // Split at 980ms - end clip only 20ms (min 30ms)
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 980),
          ),
          isFalse,
        );
      });

      test('returns true for minimum valid durations', () {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(milliseconds: 60),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        // Split exactly at 30ms - both clips exactly minimum
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 30),
          ),
          isTrue,
        );
      });

      test('validates against trimmedDuration for trimmed clips', () {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 10),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
          trimStart: const Duration(seconds: 3),
          trimEnd: const Duration(seconds: 2),
        );

        // trimmedDuration = 10 - 3 - 2 = 5s
        // Split at 4.98s — end clip would only be 20ms (< 30ms min)
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 4980),
          ),
          isFalse,
        );

        // Split at 2.5s — both clips are 2.5s
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 2500),
          ),
          isTrue,
        );
      });
    });

    group('splitClip', () {
      test('throws ArgumentError for invalid split position', () async {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        expect(
          () => VideoEditorSplitService.splitClip(
            sourceClip: clip,
            splitPosition: const Duration(milliseconds: 10),
            onClipsCreated: null,
            onThumbnailExtracted: null,
            onClipRendered: null,
          ),
          throwsArgumentError,
        );
      });

      test('creates two clips with correct durations', () async {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        DivineVideoClip? capturedStartClip;
        DivineVideoClip? capturedEndClip;

        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (start, end) {
            capturedStartClip = start;
            capturedEndClip = end;
          },
          onThumbnailExtracted: null,
          onClipRendered: null,
        );

        expect(capturedStartClip, isNotNull);
        expect(capturedEndClip, isNotNull);
        expect(capturedStartClip!.duration, const Duration(seconds: 2));
        expect(capturedEndClip!.duration, const Duration(seconds: 5));
        expect(capturedEndClip!.trimStart, const Duration(seconds: 2));
        expect(capturedEndClip!.trimmedDuration, const Duration(seconds: 3));
      });

      test('calls onClipsCreated before rendering', () async {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        var onClipsCreatedCalled = false;
        var onClipRenderedCalled = false;
        var clipsCreatedFirst = false;

        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (start, end) {
            onClipsCreatedCalled = true;
            if (!onClipRenderedCalled) {
              clipsCreatedFirst = true;
            }
          },
          onThumbnailExtracted: null,
          onClipRendered: (clip, video) {
            onClipRenderedCalled = true;
          },
        );

        expect(onClipsCreatedCalled, isTrue);
        expect(clipsCreatedFirst, isTrue);
      });

      test('cuts the source with a single frame-accurate split', () async {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: null,
          onThumbnailExtracted: null,
          onClipRendered: null,
        );

        // A single native split replaces the two full render passes.
        expect(mockProVideoEditor.splitRequests, hasLength(1));
        final request = mockProVideoEditor.splitRequests.single;
        expect(request.splitPosition, const Duration(seconds: 2));
        expect(request.startOutputPath, contains('_start.mp4'));
        expect(request.endOutputPath, contains('_end.mp4'));
        expect(request.startOutputPath, isNot(request.endOutputPath));
      });

      test('reports both halves as two distinct output files', () async {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        final renderedVideos = <EditorVideo>[];
        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: null,
          onThumbnailExtracted: null,
          onClipRendered: (clip, video) => renderedVideos.add(video),
        );
        expect(renderedVideos, hasLength(2));
        final paths = renderedVideos.map((v) => v.file?.path).toList();
        expect(paths.any((p) => p?.contains('_start.mp4') ?? false), isTrue);
        expect(paths.any((p) => p?.contains('_end.mp4') ?? false), isTrue);
        expect(paths.first, isNot(paths.last));

        // Regression: the clip id already ends in `_start` / `_end`, so the
        // filename must not double that suffix (`_start_start.mp4`).
        final request = mockProVideoEditor.splitRequests.single;
        expect(request.startOutputPath, isNot(contains('_start_start')));
        expect(request.endOutputPath, isNot(contains('_end_end')));
      });

      test('a second split immediately afterwards still works', () async {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        Future<int> runSplit() async {
          var renderedCount = 0;
          await VideoEditorSplitService.splitClip(
            sourceClip: clip,
            splitPosition: const Duration(seconds: 2),
            onClipsCreated: null,
            onThumbnailExtracted: null,
            onClipRendered: (_, _) => renderedCount++,
          );
          return renderedCount;
        }

        // Regression for #4801: the split future always completes, so a
        // back-to-back split is never silently dropped.
        expect(await runSplit(), 2);
        expect(await runSplit(), 2);
        expect(mockProVideoEditor.splitRequests, hasLength(2));
      });

      test('calls onClipRendered for both clips', () async {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        final renderedClips = <DivineVideoClip>[];

        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: null,
          onThumbnailExtracted: null,
          onClipRendered: (clip, video) {
            renderedClips.add(clip);
          },
        );

        expect(renderedClips.length, 2);
      });

      test('completes processing completers on success', () async {
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        DivineVideoClip? capturedStartClip;
        DivineVideoClip? capturedEndClip;

        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (start, end) {
            capturedStartClip = start;
            capturedEndClip = end;
          },
          onThumbnailExtracted: null,
          onClipRendered: null,
        );

        expect(capturedStartClip!.processingCompleter?.isCompleted, isTrue);
        expect(capturedEndClip!.processingCompleter?.isCompleted, isTrue);

        final startSuccess =
            await capturedStartClip!.processingCompleter!.future;
        final endSuccess = await capturedEndClip!.processingCompleter!.future;

        expect(startSuccess, isTrue);
        expect(endSuccess, isTrue);
      });

      test('completes processing completers on failure', () async {
        mockProVideoEditor.shouldThrowError = true;

        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        try {
          await VideoEditorSplitService.splitClip(
            sourceClip: clip,
            splitPosition: const Duration(seconds: 2),
            onClipsCreated: null,
            onThumbnailExtracted: null,
            onClipRendered: null,
          );
          fail('Should have thrown exception');
        } catch (e) {
          expect(e, isException);
        }
      });

      test(
        'does not report rendered clips when output files are missing',
        () async {
          mockProVideoEditor.createOutputFiles = false;

          final clip = DivineVideoClip(
            id: 'test-clip',
            video: EditorVideo.file('/test/video.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            targetAspectRatio: model.AspectRatio.square,
            originalAspectRatio: 9 / 16,
          );

          final renderedClips = <DivineVideoClip>[];

          await expectLater(
            VideoEditorSplitService.splitClip(
              sourceClip: clip,
              splitPosition: const Duration(seconds: 2),
              onClipsCreated: (_, _) {},
              onThumbnailExtracted: null,
              onClipRendered: (renderedClip, _) {
                renderedClips.add(renderedClip);
              },
            ),
            throwsStateError,
          );

          expect(renderedClips, isEmpty);
        },
      );

      test('generates unique IDs for split clips', () async {
        final clip = DivineVideoClip(
          id: 'original-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        DivineVideoClip? endClip1;
        DivineVideoClip? endClip2;

        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (_, end) => endClip1 = end,
          onThumbnailExtracted: null,
          onClipRendered: null,
        );

        // Wait a bit to ensure different timestamp
        await Future<void>.delayed(const Duration(milliseconds: 2));

        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (_, end) => endClip2 = end,
          onThumbnailExtracted: null,
          onClipRendered: null,
        );

        expect(endClip1!.id, isNot(equals(endClip2!.id)));
      });

      test('splits trimmed clip at correct absolute position', () async {
        // 10s clip trimmed to show 3s–8s (trimmedDuration = 5s)
        final clip = DivineVideoClip(
          id: 'trimmed-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 10),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
          trimStart: const Duration(seconds: 3),
          trimEnd: const Duration(seconds: 2),
        );

        DivineVideoClip? capturedStartClip;
        DivineVideoClip? capturedEndClip;

        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          // Split at 2s into the trimmed clip (absolute 5s)
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (start, end) {
            capturedStartClip = start;
            capturedEndClip = end;
          },
          onThumbnailExtracted: null,
          onClipRendered: null,
        );

        expect(capturedStartClip, isNotNull);
        expect(capturedEndClip, isNotNull);

        // Start clip: 0–5s (absolute), trimStart=3s, trimEnd=0
        // trimmedDuration = 5 - 3 = 2s ✓
        expect(capturedStartClip!.duration, const Duration(seconds: 5));
        expect(capturedStartClip!.trimStart, const Duration(seconds: 3));
        expect(capturedStartClip!.trimEnd, Duration.zero);
        expect(capturedStartClip!.trimmedDuration, const Duration(seconds: 2));

        // Preview end clip still points at the original source while the
        // rendered end file is being produced, so trimStart is absolute.
        // trimmedDuration = 10 - 5 - 2 = 3s ✓
        expect(capturedEndClip!.duration, const Duration(seconds: 10));
        expect(capturedEndClip!.trimStart, const Duration(seconds: 5));
        expect(capturedEndClip!.trimEnd, const Duration(seconds: 2));
        expect(capturedEndClip!.trimmedDuration, const Duration(seconds: 3));

        // Total trimmedDuration preserved: 2 + 3 = 5s
        expect(
          capturedStartClip!.trimmedDuration + capturedEndClip!.trimmedDuration,
          clip.trimmedDuration,
        );
      });

      test('start half drops the transition; end half keeps it', () async {
        const dissolve = ClipTransition(type: ClipTransitionType.dissolve);
        // Source clip A → B carries the dissolve into the next clip.
        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
          transition: dissolve,
        );

        DivineVideoClip? capturedStartClip;
        DivineVideoClip? capturedEndClip;

        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (start, end) {
            capturedStartClip = start;
            capturedEndClip = end;
          },
          onThumbnailExtracted: null,
          onClipRendered: null,
        );

        // The split point (A1 → A2) is a hard cut.
        expect(capturedStartClip!.transition, isNull);
        // A2 → B keeps the original boundary.
        expect(capturedEndClip!.transition, equals(dissolve));
      });

      test('reports rendered end clip with trimStart reset to zero', () async {
        final clip = DivineVideoClip(
          id: 'trimmed-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 10),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
          trimStart: const Duration(seconds: 3),
          trimEnd: const Duration(seconds: 2),
        );

        final renderedClips = <DivineVideoClip>[];

        await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: null,
          onThumbnailExtracted: null,
          onClipRendered: (clip, video) => renderedClips.add(clip),
        );

        final endClip = renderedClips.singleWhere(
          (clip) => clip.id.endsWith('_end'),
        );

        expect(endClip.duration, const Duration(seconds: 5));
        expect(endClip.trimStart, Duration.zero);
        expect(endClip.trimEnd, const Duration(seconds: 2));
        expect(endClip.trimmedDuration, const Duration(seconds: 3));
      });
    });
  });
}
