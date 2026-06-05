// ABOUTME: Tests for composite export progress in VideoEditorRenderService
// ABOUTME: Verifies render/proof sequencing and ProofMode budget allocation

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _ProgressProVideoEditor extends ProVideoEditor {
  final _progressController = StreamController<ProgressModel>.broadcast();

  @override
  void initializeStream() {}

  void emitProgress(String taskId, double progress) {
    _progressController.add(ProgressModel(id: taskId, progress: progress));
  }

  @override
  Stream<ProgressModel> progressStreamById(String taskId) {
    return _progressController.stream.where(
      (progress) => progress.id == taskId,
    );
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    return VideoMetadata(
      duration: const Duration(seconds: 6),
      extension: 'mp4',
      fileSize: 1024,
      resolution: const Size(1080, 1920),
      rotation: 0,
      bitrate: 1_000_000,
    );
  }

  Future<void> dispose() => _progressController.close();
}

Future<void> _flushStreamEvents() => Future<void>.delayed(Duration.zero);

DivineVideoClip _createClip(int index) {
  return DivineVideoClip(
    id: 'clip-$index',
    video: EditorVideo.file('${Directory.systemTemp.path}/clip-$index.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2026, 6, 5, 12, index),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );
}

void main() {
  group('VideoEditorRenderService proof progress allocation', () {
    test('reserves a minimum of 5 percent for proof finalization', () {
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(1),
        closeTo(0.05, 1e-9),
      );
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(3),
        closeTo(0.05, 1e-9),
      );
    });

    test('scales proof budget with clip count until the 10 percent cap', () {
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(5),
        closeTo(0.05, 1e-9),
      );
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(7),
        closeTo(0.07, 1e-9),
      );
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(10),
        closeTo(0.10, 1e-9),
      );
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(30),
        closeTo(0.10, 1e-9),
      );
    });
  });

  group('VideoEditorRenderService composite progress sequence', () {
    late ProVideoEditor originalProVideoEditor;
    late _ProgressProVideoEditor proVideoEditor;

    setUp(() {
      originalProVideoEditor = ProVideoEditor.instance;
      proVideoEditor = _ProgressProVideoEditor();
      ProVideoEditor.instance = proVideoEditor;
    });

    tearDown(() async {
      VideoEditorRenderService.renderVideoOverride = null;
      NativeProofModeService.proofFileOverride = null;
      await proVideoEditor.dispose();
      ProVideoEditor.instance = originalProVideoEditor;
    });

    test(
      'scales render progress, counts proof steps, and stays monotonic',
      () async {
        const taskId = 'composite-sequence-test';
        final progressValues = <double>[];
        final proofCallClipCounts = <int?>[];
        final editorStateHistory = <String, dynamic>{
          'clips': ['clip-0', 'clip-1', 'clip-2'],
        };

        final progressSubscription =
            VideoEditorRenderService.compositeProgressStreamById(taskId).listen(
              (progress) => progressValues.add(progress.progress),
            );
        addTearDown(progressSubscription.cancel);

        VideoEditorRenderService.renderVideoOverride =
            ({
              required clips,
              required usePersistentStorage,
              aspectRatio,
              parameters,
              taskId,
            }) async {
              expect(usePersistentStorage, isTrue);
              expect(taskId, equals('composite-sequence-test'));

              proVideoEditor.emitProgress(taskId!, 0.25);
              await _flushStreamEvents();
              proVideoEditor.emitProgress(taskId, 0.75);
              await _flushStreamEvents();
              proVideoEditor.emitProgress(taskId, 0.40);
              await _flushStreamEvents();

              return '${Directory.systemTemp.path}/rendered-composite.mp4';
            };

        NativeProofModeService.proofFileOverride =
            (
              File videoFile, {
              required bool enableAdvancedCawgEmbedding,
              creatorBindingAssertion,
              cawgIdentityAssertion,
              verifiedIdentityBundle,
              clips,
              editorStateHistory,
            }) async {
              proofCallClipCounts.add(clips?.length);

              if (proofCallClipCounts.length == 1) {
                proVideoEditor.emitProgress(taskId, 0.10);
                await _flushStreamEvents();
              }

              return model.NativeProofData(
                videoHash: 'proof-${proofCallClipCounts.length}',
              );
            };

        final result = await VideoEditorRenderService.renderVideoToClip(
          clips: [_createClip(0), _createClip(1), _createClip(2)],
          editorStateHistory: editorStateHistory,
          taskId: taskId,
        );
        await _flushStreamEvents();

        expect(result, isNotNull);
        expect(result?.$2, isNotNull);
        expect(
          proofCallClipCounts,
          equals([null, null, null, 3]),
          reason:
              'three clip-proof steps plus the final combined proofFile step',
        );

        const renderBudget = 0.95;
        const proofBudget = 0.05;
        final expectedProgressValues = [
          0.0,
          0.25 * renderBudget,
          0.75 * renderBudget,
          renderBudget,
          renderBudget + proofBudget / 4,
          renderBudget + proofBudget * 2 / 4,
          renderBudget + proofBudget * 3 / 4,
          1.0,
        ];

        expect(progressValues, hasLength(expectedProgressValues.length));
        for (var i = 0; i < expectedProgressValues.length; i++) {
          expect(progressValues[i], closeTo(expectedProgressValues[i], 1e-9));
        }
        for (var i = 1; i < progressValues.length; i++) {
          expect(
            progressValues[i],
            greaterThanOrEqualTo(progressValues[i - 1]),
          );
        }
        expect(progressValues.last, equals(1.0));
      },
    );
  });
}
