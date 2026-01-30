import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationCachePath() async {
    return '/cache';
  }
}

class MockProVideoEditor extends ProVideoEditor {
  bool shouldThrowError = false;
  final List<String> renderedPaths = [];

  @override
  Stream<dynamic> initializeStream() {
    return const Stream.empty();
  }

  @override
  Future<String> renderVideoToFile(
    String outputPath,
    VideoRenderData renderData,
  ) async {
    if (shouldThrowError) {
      throw Exception('Render failed');
    }
    renderedPaths.add(outputPath);
    // Simulate successful render
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return outputPath;
  }
}

void main() {
  late MockProVideoEditor mockProVideoEditor;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = MockPathProviderPlatform();
    mockProVideoEditor = MockProVideoEditor();
    ProVideoEditor.instance = mockProVideoEditor;
    mockProVideoEditor.renderedPaths.clear();
  });

  group('VideoEditorSplitService', () {
    group('isValidSplitPosition', () {
      test('returns true for valid split position', () {
        final clip = RecordingClip(
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
        final clip = RecordingClip(
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
        final clip = RecordingClip(
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
        final clip = RecordingClip(
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
    });

    group('splitClip', () {
      test('throws ArgumentError for invalid split position', () async {
        final clip = RecordingClip(
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
        final clip = RecordingClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        RecordingClip? capturedStartClip;
        RecordingClip? capturedEndClip;

        final result = await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: (start, end) {
            capturedStartClip = start;
            capturedEndClip = end;
          },
          onThumbnailExtracted: null,
          onClipRendered: null,
        );

        expect(result.startClip.duration, const Duration(seconds: 2));
        expect(result.endClip.duration, const Duration(seconds: 3));
        expect(capturedStartClip, isNotNull);
        expect(capturedEndClip, isNotNull);
        expect(capturedStartClip!.duration, const Duration(seconds: 2));
        expect(capturedEndClip!.duration, const Duration(seconds: 3));
      });

      test('calls onClipsCreated before rendering', () async {
        final clip = RecordingClip(
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

      test('renders both clips in parallel', () async {
        final clip = RecordingClip(
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

        // Should have rendered 2 clips
        expect(mockProVideoEditor.renderedPaths.length, 2);
        expect(
          mockProVideoEditor.renderedPaths.any((p) => p.contains('_start.mp4')),
          isTrue,
        );
        expect(
          mockProVideoEditor.renderedPaths.any((p) => p.contains('_end.mp4')),
          isTrue,
        );
      });

      test('calls onClipRendered for both clips', () async {
        final clip = RecordingClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        final renderedClips = <RecordingClip>[];

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
        final clip = RecordingClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        final result = await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: null,
          onThumbnailExtracted: null,
          onClipRendered: null,
        );

        expect(result.startClip.processingCompleter?.isCompleted, isTrue);
        expect(result.endClip.processingCompleter?.isCompleted, isTrue);

        final startSuccess = await result.startClip.processingCompleter!.future;
        final endSuccess = await result.endClip.processingCompleter!.future;

        expect(startSuccess, isTrue);
        expect(endSuccess, isTrue);
      });

      test('completes processing completers on failure', () async {
        mockProVideoEditor.shouldThrowError = true;

        final clip = RecordingClip(
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

      test('generates unique IDs for split clips', () async {
        final clip = RecordingClip(
          id: 'original-clip',
          video: EditorVideo.file('/test/video.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        final result1 = await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: null,
          onThumbnailExtracted: null,
          onClipRendered: null,
        );

        // Wait a bit to ensure different timestamp
        await Future<void>.delayed(const Duration(milliseconds: 2));

        final result2 = await VideoEditorSplitService.splitClip(
          sourceClip: clip,
          splitPosition: const Duration(seconds: 2),
          onClipsCreated: null,
          onThumbnailExtracted: null,
          onClipRendered: null,
        );

        expect(result1.endClip.id, isNot(equals(result2.endClip.id)));
      });
    });
  });
}
