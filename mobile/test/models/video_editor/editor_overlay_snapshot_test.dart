// ABOUTME: Tests for EditorOverlaySnapshot - windowing overlays onto one clip's
// ABOUTME: slice of the editor timeline.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/editor_overlay_snapshot.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

ExportedLayer _layer({String id = 'l', Duration? start, Duration? end}) {
  return ExportedLayer(
    layer: Layer(id: id, startTime: start, endTime: end),
    bytes: Uint8List.fromList([1, 2, 3]),
    logicalSize: const Size(10, 10),
  );
}

FilterState _filter({String id = 'f', Duration? start, Duration? end}) {
  return FilterState(
    id: id,
    name: id,
    matrices: [
      [1.0],
    ],
    startTime: start,
    endTime: end,
  );
}

TuneAdjustmentMatrix _tune({String id = 't', Duration? start, Duration? end}) {
  return TuneAdjustmentMatrix(
    id: id,
    value: 1,
    matrix: const [1.0],
    startTime: start,
    endTime: end,
  );
}

const _s1 = Duration(seconds: 1);
const _s2 = Duration(seconds: 2);
const _s3 = Duration(seconds: 3);
const _s4 = Duration(seconds: 4);
const _s5 = Duration(seconds: 5);
const _s6 = Duration(seconds: 6);

void main() {
  group(EditorOverlaySnapshot, () {
    group('isEmpty', () {
      test('is true with nothing to bake', () {
        expect(const EditorOverlaySnapshot().isEmpty, isTrue);
      });

      test('is false when only a blur is set', () {
        expect(const EditorOverlaySnapshot(blur: 3).isEmpty, isFalse);
      });

      test('is false when a layer is present', () {
        expect(
          EditorOverlaySnapshot(capturedLayers: [_layer()]).isEmpty,
          isFalse,
        );
      });
    });

    group('windowedTo layers', () {
      test('keeps a layer inside the window, rebased to zero', () {
        // Clip occupies 3s-6s; layer sits at 4s-5s over it.
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer(start: _s4, end: _s5)],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.capturedLayers, hasLength(1));
        expect(result.capturedLayers.single.layer.startTime, equals(_s1));
        expect(result.capturedLayers.single.layer.endTime, equals(_s2));
      });

      test('drops a layer that ends before the window', () {
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer(start: _s1, end: _s2)],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.capturedLayers, isEmpty);
      });

      test('drops a layer that starts after the window', () {
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer(start: const Duration(seconds: 7))],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.capturedLayers, isEmpty);
      });

      test('drops a layer that only touches the window boundary', () {
        // Ends exactly where the clip starts — it was never over this clip.
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer(start: _s1, end: _s3)],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.capturedLayers, isEmpty);
      });

      test('clamps a layer that starts before the window', () {
        // Layer runs 1s-4s, clip is 3s-6s → visible for the clip's first second.
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer(start: _s1, end: _s4)],
        ).windowedTo(start: _s3, end: _s6);

        expect(
          result.capturedLayers.single.layer.startTime,
          equals(Duration.zero),
        );
        expect(result.capturedLayers.single.layer.endTime, equals(_s1));
      });

      test('clamps a layer that outlives the window', () {
        // Layer runs 4s-10s, clip is 3s-6s → visible from 1s to the clip's end.
        final result = EditorOverlaySnapshot(
          capturedLayers: [
            _layer(start: _s4, end: const Duration(seconds: 10)),
          ],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.capturedLayers.single.layer.startTime, equals(_s1));
        expect(result.capturedLayers.single.layer.endTime, equals(_s3));
      });

      test('binds an unbounded layer to the window', () {
        // null/null spans the whole composition, so it covers all of the clip.
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer()],
        ).windowedTo(start: _s3, end: _s6);

        expect(
          result.capturedLayers.single.layer.startTime,
          equals(Duration.zero),
        );
        expect(result.capturedLayers.single.layer.endTime, equals(_s3));
      });

      test('carries the rasterized bytes and layout through untouched', () {
        final source = _layer(start: _s4, end: _s5);
        final result = EditorOverlaySnapshot(
          capturedLayers: [source],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.capturedLayers.single.bytes, same(source.bytes));
        expect(
          result.capturedLayers.single.logicalSize,
          equals(const Size(10, 10)),
        );
      });

      test("does not mutate the editor's live layer", () {
        // Layer.startTime is mutable and this instance belongs to the editor —
        // rebasing it in place would corrupt the running session.
        final source = _layer(start: _s4, end: _s5);
        EditorOverlaySnapshot(
          capturedLayers: [source],
        ).windowedTo(start: _s3, end: _s6);

        expect(source.layer.startTime, equals(_s4));
        expect(source.layer.endTime, equals(_s5));
      });

      test('keeps only the layers overlapping the window', () {
        final result = EditorOverlaySnapshot(
          capturedLayers: [
            _layer(id: 'before', start: Duration.zero, end: _s1),
            _layer(id: 'over', start: _s4, end: _s5),
            _layer(id: 'after', start: const Duration(seconds: 8)),
          ],
        ).windowedTo(start: _s3, end: _s6);

        expect(
          result.capturedLayers.map((l) => l.layer.id),
          equals(['over']),
        );
      });
    });

    group('windowedTo filters and tune', () {
      test('windows a filter like a layer', () {
        final result = EditorOverlaySnapshot(
          filterStates: [_filter(start: _s4, end: const Duration(seconds: 10))],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.filterStates.single.startTime, equals(_s1));
        expect(result.filterStates.single.endTime, equals(_s3));
      });

      test('drops a filter outside the window', () {
        final result = EditorOverlaySnapshot(
          filterStates: [_filter(start: Duration.zero, end: _s1)],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.filterStates, isEmpty);
      });

      test('windows a tune adjustment like a layer', () {
        final result = EditorOverlaySnapshot(
          tuneAdjustments: [_tune(start: _s1, end: _s4)],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.tuneAdjustments.single.startTime, equals(Duration.zero));
        expect(result.tuneAdjustments.single.endTime, equals(_s1));
      });

      test('drops a tune adjustment outside the window', () {
        final result = EditorOverlaySnapshot(
          tuneAdjustments: [
            _tune(start: const Duration(seconds: 7)),
          ],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.tuneAdjustments, isEmpty);
      });
    });

    group('windowedTo pass-through', () {
      test(
        'carries blur and bodySize through — neither is a timeline value',
        () {
          final result = const EditorOverlaySnapshot(
            blur: 5,
            bodySize: Size(100, 200),
          ).windowedTo(start: _s3, end: _s6);

          expect(result.blur, equals(5));
          expect(result.bodySize, equals(const Size(100, 200)));
        },
      );

      test('keeps blur but drops timed overlays for an empty window', () {
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer(start: Duration.zero, end: _s6)],
          filterStates: [_filter()],
          blur: 5,
          bodySize: const Size(100, 200),
        ).windowedTo(start: _s3, end: _s3);

        expect(result.capturedLayers, isEmpty);
        expect(result.filterStates, isEmpty);
        expect(result.blur, equals(5));
        expect(result.bodySize, equals(const Size(100, 200)));
      });
    });
  });
}
