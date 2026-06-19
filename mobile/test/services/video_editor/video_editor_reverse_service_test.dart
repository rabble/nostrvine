import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_reverse_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform({required this.documentsPath});

  final String documentsPath;

  @override
  Future<String?> getApplicationCachePath() async {
    return path.join(path.dirname(documentsPath), 'cache');
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return documentsPath;
  }
}

class _FakeProVideoEditor extends ProVideoEditor {
  final canceledTaskIds = <String>[];
  final renderedPaths = <String>[];
  final renderedData = <VideoRenderData>[];
  final outputExistedWhenRenderStarted = <bool>[];

  bool cancelShouldThrow = false;
  bool renderShouldThrow = false;
  bool createPartialOutputBeforeThrow = false;

  @override
  void initializeStream() {}

  @override
  Future<void> cancel(String taskId) async {
    canceledTaskIds.add(taskId);
    if (cancelShouldThrow) {
      throw ArgumentError('unknown task');
    }
  }

  @override
  Future<String> renderVideoToFile(
    String filePath,
    VideoRenderData value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    outputExistedWhenRenderStarted.add(File(filePath).existsSync());
    renderedPaths.add(filePath);
    renderedData.add(value);

    if (renderShouldThrow) {
      if (createPartialOutputBeforeThrow) {
        await File(filePath).writeAsString('partial reverse render');
      }
      throw Exception('reverse render failed');
    }

    return filePath;
  }
}

// Permanent: swaps PathProviderPlatform.instance and ProVideoEditor.instance;
// keep isolated until VideoEditorReverseService accepts injected dependencies.
@Tags(['skip_very_good_optimization'])
void main() {
  late Directory tempDir;
  late String documentsPath;
  late PathProviderPlatform originalPathProvider;
  late ProVideoEditor originalProVideoEditor;
  late _FakeProVideoEditor proVideoEditor;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    originalPathProvider = PathProviderPlatform.instance;
    originalProVideoEditor = ProVideoEditor.instance;

    tempDir = await Directory.systemTemp.createTemp(
      'video_editor_reverse_service_test_',
    );
    documentsPath = path.join(tempDir.path, 'documents');
    await Directory(documentsPath).create(recursive: true);

    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: documentsPath,
    );
    proVideoEditor = _FakeProVideoEditor();
    ProVideoEditor.instance = proVideoEditor;
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    ProVideoEditor.instance = originalProVideoEditor;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('VideoEditorReverseService', () {
    test('renders the source clip as a reversed video segment', () async {
      final inputPath = path.join(tempDir.path, 'source.mp4');
      final sourceClip = _clip(id: 'clip-1', inputPath: inputPath);

      final result = await VideoEditorReverseService.reverseClip(
        sourceClip: sourceClip,
        renderId: 'reverse-render-1',
      );

      final expectedOutputPath = path.join(
        documentsPath,
        'clip-1_reversed.mp4',
      );
      expect(result.file?.path, expectedOutputPath);
      expect(proVideoEditor.canceledTaskIds, ['reverse-render-1']);
      expect(proVideoEditor.renderedPaths, [expectedOutputPath]);

      final renderData = proVideoEditor.renderedData.single;
      expect(renderData.id, 'reverse-render-1');
      expect(renderData.videoSegments, hasLength(1));

      final segment = renderData.videoSegments!.single;
      expect(segment.reverseVideo, isTrue);
      expect(segment.startTime, isNull);
      expect(segment.endTime, isNull);
      expect(await segment.video.safeFilePath(), inputPath);
    });

    test(
      'continues rendering when there is no active render to cancel',
      () async {
        proVideoEditor.cancelShouldThrow = true;
        final sourceClip = _clip(
          id: 'clip-cancel-miss',
          inputPath: path.join(tempDir.path, 'source.mp4'),
        );

        await VideoEditorReverseService.reverseClip(
          sourceClip: sourceClip,
          renderId: 'reverse-render-missing',
        );

        expect(proVideoEditor.canceledTaskIds, ['reverse-render-missing']);
        expect(proVideoEditor.renderedData, hasLength(1));
      },
    );

    test('deletes stale output before starting a new reverse render', () async {
      final sourceClip = _clip(
        id: 'clip-stale-output',
        inputPath: path.join(tempDir.path, 'source.mp4'),
      );
      final outputPath = path.join(
        documentsPath,
        'clip-stale-output_reversed.mp4',
      );
      await File(outputPath).writeAsString('old reverse render');

      await VideoEditorReverseService.reverseClip(
        sourceClip: sourceClip,
        renderId: 'reverse-render-stale',
      );

      expect(proVideoEditor.outputExistedWhenRenderStarted, [isFalse]);
    });

    test('does not delete the source video when input equals output', () async {
      final collidingPath = path.join(
        documentsPath,
        'clip-reversed_reversed.mp4',
      );
      await File(collidingPath).writeAsString('source video');
      final sourceClip = _clip(
        id: 'clip-reversed',
        inputPath: collidingPath,
      );

      await expectLater(
        () => VideoEditorReverseService.reverseClip(
          sourceClip: sourceClip,
          renderId: 'reverse-render-collision',
        ),
        throwsA(isA<StateError>()),
      );

      expect(await File(collidingPath).readAsString(), 'source video');
      expect(proVideoEditor.canceledTaskIds, isEmpty);
      expect(proVideoEditor.renderedData, isEmpty);
    });

    test('deletes partial output when rendering fails', () async {
      proVideoEditor
        ..renderShouldThrow = true
        ..createPartialOutputBeforeThrow = true;
      final sourceClip = _clip(
        id: 'clip-partial-output',
        inputPath: path.join(tempDir.path, 'source.mp4'),
      );
      final outputPath = path.join(
        documentsPath,
        'clip-partial-output_reversed.mp4',
      );

      await expectLater(
        () => VideoEditorReverseService.reverseClip(
          sourceClip: sourceClip,
          renderId: 'reverse-render-failure',
        ),
        throwsException,
      );

      expect(File(outputPath).existsSync(), isFalse);
    });
  });
}

DivineVideoClip _clip({
  required String id,
  required String inputPath,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file(inputPath),
    duration: const Duration(seconds: 6),
    recordedAt: DateTime(2026, 6, 10, 12),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );
}
