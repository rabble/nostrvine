// ABOUTME: Tests DraftRenderParametersService restoring a draft's overlays
// ABOUTME: Covers layers, timed filters, tune and the graceful degrade paths

import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart' hide AspectRatio;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/video_editor/draft_render_parameters_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip() => DivineVideoClip(
  id: 'clip_1',
  video: EditorVideo.file('/tmp/test.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

DivineVideoDraft _draft({
  Map<String, dynamic> editorStateHistory = const {},
  Map<String, dynamic> editorEditingParameters = const {},
}) => DivineVideoDraft(
  id: 'draft_1',
  clips: [_clip()],
  title: '',
  description: '',
  hashtags: const {},
  selectedApproach: 'camera',
  createdAt: DateTime(2025),
  lastModified: DateTime(2025),
  publishStatus: PublishStatus.draft,
  publishAttempts: 0,
  editorStateHistory: editorStateHistory,
  editorEditingParameters: editorEditingParameters,
);

/// The persisted shape of a session laid out against [bodySize].
///
/// This is what `CompleteParameters.toMap` writes into a draft — note it has
/// no `capturedLayers`, `filterStates`, `tuneAdjustments` or `audioTracks`,
/// which is the gap the service exists to close.
Map<String, dynamic> _persistedParameters({Size? bodySize}) => {
  if (bodySize != null)
    'bodySize': {'width': bodySize.width, 'height': bodySize.height},
};

Map<String, dynamic> _historyWithTextLayer() => {
  'position': 0,
  'references': {
    'text-1': TextLayer(id: 'text-1', text: 'hello').toMap(),
  },
  'history': [
    {
      'layers': [
        {'id': 'text-1'},
      ],
    },
  ],
};

void main() {
  group(DraftRenderParametersService, () {
    late LayerRasterizer rasterizer;
    late DraftRenderParametersService service;

    setUp(() {
      rasterizer = LayerRasterizer();
      service = DraftRenderParametersService(rasterizer: rasterizer);
    });

    tearDown(() => rasterizer.dispose());

    test('returns null when the draft carries no editor state', () async {
      expect(await service.buildForDraft(_draft()), isNull);
    });

    test(
      'restores timed filters and tune the persisted parameters drop',
      () async {
        final draft = _draft(
          editorEditingParameters: _persistedParameters(),
          editorStateHistory: {
            'position': 0,
            'history': [
              {
                'filters': [
                  {
                    'matrices': [
                      List<double>.filled(20, 0.5),
                    ],
                    'startTime': 1000,
                    'endTime': 3000,
                  },
                ],
                'tune': [
                  {'id': 'brightness', 'value': 0.4, 'matrix': <double>[]},
                ],
              },
            ],
          },
        );

        final parameters = await service.buildForDraft(draft);

        expect(parameters, isNotNull);
        expect(parameters!.filterStates, hasLength(1));
        expect(
          parameters.filterStates.single.startTime,
          equals(const Duration(milliseconds: 1000)),
          reason: 'the timeline window is what the raw matrix list loses',
        );
        expect(parameters.tuneAdjustments, hasLength(1));
      },
    );

    // The three cases below all mean "this draft has overlays we cannot
    // reproduce". Returning parameters without them would publish a video
    // silently missing text/stickers the user still sees on the draft — the
    // #5203 failure — so the publish is blocked instead.
    test('refuses to build when the draft has no editor body size', () async {
      final draft = _draft(
        editorEditingParameters: _persistedParameters(),
        editorStateHistory: _historyWithTextLayer(),
      );

      await expectLater(
        service.buildForDraft(draft),
        throwsA(isA<DraftOverlayRestoreException>()),
      );
    });

    test('refuses to build when the state history is malformed', () async {
      // A history that will not parse may well describe layers, and there is
      // no way to tell from the outside.
      final draft = _draft(
        editorEditingParameters: _persistedParameters(
          bodySize: const Size(300, 500),
        ),
        editorStateHistory: const {'position': 0, 'history': 'not-a-list'},
      );

      await expectLater(
        service.buildForDraft(draft),
        throwsA(isA<DraftOverlayRestoreException>()),
      );
    });

    test('refuses to build when rasterizing the layers fails', () async {
      final draft = _draft(
        editorEditingParameters: _persistedParameters(
          bodySize: const Size(300, 500),
        ),
        editorStateHistory: _historyWithTextLayer(),
      );

      // No host is mounted, so the real rasterizer throws a StateError.
      await expectLater(
        service.buildForDraft(draft),
        throwsA(isA<DraftOverlayRestoreException>()),
      );
    });

    test('rasterizes the restored layers into capturedLayers', () async {
      // The rasterizer is stubbed here: producing real bytes means PNG
      // encoding through the isolate-backed recorder, which a widget test
      // cannot drive. pro_image_editor's own LayerRasterizer tests cover that
      // mount-paint-capture mechanism end to end; what matters here is that
      // the service hands it the layers it recovered from storage and puts
      // the result where the render reads it.
      final stub = _StubLayerRasterizer();
      addTearDown(stub.dispose);

      final draft = _draft(
        editorEditingParameters: _persistedParameters(
          bodySize: const Size(300, 500),
        ),
        editorStateHistory: _historyWithTextLayer(),
      );

      final parameters = await DraftRenderParametersService(
        rasterizer: stub,
      ).buildForDraft(draft);

      expect(
        stub.capturedLayerCount,
        equals(1),
        reason:
            'a layer restored from storage has never been rasterized, so '
            'without this the render would drop it entirely',
      );
      expect(
        stub.editorBodySize,
        equals(const Size(300, 500)),
        reason: 'layer offsets are relative to the editor body size',
      );
      expect(
        stub.basePixelRatio,
        equals(
          VideoEditorConstants.quality
                  .resolutionForAspectRatio(AspectRatio.vertical)
                  .width /
              300,
        ),
        reason:
            'capturing at the render scale gives one raster pixel per '
            'output pixel',
      );
      expect(parameters!.capturedLayers, hasLength(1));
    });
  });
}

/// Stands in for the real rasterizer so the service can be exercised without
/// a widget tree, recording what it was asked to bake.
class _StubLayerRasterizer extends LayerRasterizer {
  int? capturedLayerCount;
  Size? editorBodySize;
  double? basePixelRatio;

  @override
  Future<List<ExportedLayer>> capture({
    required List<Layer> layers,
    required Size editorBodySize,
    ProImageEditorConfigs configs = const ProImageEditorConfigs(),
    double? pixelRatio,
    double? basePixelRatio,
    bool applyTransforms = true,
    ImageByteFormat format = ImageByteFormat.png,
    Future<void> Function()? awaitContentReady,
  }) async {
    capturedLayerCount = layers.length;
    this.editorBodySize = editorBodySize;
    this.basePixelRatio = basePixelRatio;
    await awaitContentReady?.call();
    return [
      for (final layer in layers)
        ExportedLayer(
          layer: layer,
          bytes: Uint8List.fromList(const [1, 2, 3]),
          logicalSize: const Size(10, 10),
        ),
    ];
  }
}
