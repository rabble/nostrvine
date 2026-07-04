// ABOUTME: Unit tests for retimeTuneSet and seedTuneEditorPreview helpers.
// ABOUTME: Locks the set-wide retime writeback and the edit-preview seeding.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/tune_editor/tune_set_timeline_ops.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

class _MockTuneEditorState extends Mock implements TuneEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockTuneEditorState';
}

TuneAdjustmentMatrix _member({
  required String kind,
  required String setId,
  required double value,
}) {
  return TuneAdjustmentMatrix(
    id: '${kind}__$setId',
    value: value,
    matrix: const [],
    meta: {
      VideoEditorConstants.tuneSetIdMetaKey: setId,
      VideoEditorConstants.tuneKindMetaKey: kind,
    },
  );
}

TuneAdjustmentItem _item(String id) => TuneAdjustmentItem(
  label: id,
  icon: const IconData(0),
  id: id,
  min: -1,
  max: 1,
  toMatrix: (_) => const [],
);

void main() {
  group('retimeTuneSet', () {
    late _MockProImageEditorState editor;
    late _MockStateManager stateManager;

    setUp(() {
      editor = _MockProImageEditorState();
      stateManager = _MockStateManager();
      when(() => editor.stateManager).thenReturn(stateManager);
    });

    test(
      'applies the new window to every member of the set and skips other sets',
      () {
        when(() => stateManager.activeTuneAdjustments).thenReturn([
          _member(kind: 'brightness', setId: 'set-1', value: 0.2),
          _member(kind: 'contrast', setId: 'set-1', value: -0.1),
          _member(kind: 'brightness', setId: 'set-2', value: 0.3),
        ]);

        retimeTuneSet(
          editor,
          setId: 'set-1',
          startTime: const Duration(seconds: 2),
          endTime: const Duration(seconds: 6),
        );

        verify(
          () => editor.setTuneTimeline(
            index: 0,
            startTime: const Duration(seconds: 2),
            endTime: const Duration(seconds: 6),
            skipUpdateHistory: true,
          ),
        ).called(1);
        verify(
          () => editor.setTuneTimeline(
            index: 1,
            startTime: const Duration(seconds: 2),
            endTime: const Duration(seconds: 6),
            skipUpdateHistory: true,
          ),
        ).called(1);
        // The set-2 member (index 2) is left untouched.
        verifyNever(
          () => editor.setTuneTimeline(
            index: 2,
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
            skipUpdateHistory: any(named: 'skipUpdateHistory'),
          ),
        );
      },
    );
  });

  group('seedTuneEditorPreview', () {
    late _MockTuneEditorState tuneEditor;

    setUp(() {
      tuneEditor = _MockTuneEditorState();
      // Non-zero indices so the value→index mapping is unambiguous and the
      // final reset to 0 is distinguishable.
      when(() => tuneEditor.tuneAdjustmentList).thenReturn([
        _item('exposure'),
        _item('hue'),
        _item('brightness'),
        _item('contrast'),
      ]);
    });

    test(
      'replays each member value at its preset index then resets selection',
      () {
        seedTuneEditorPreview(
          tuneEditor: tuneEditor,
          active: [
            _member(kind: 'brightness', setId: 'set-1', value: 0.2),
            _member(kind: 'contrast', setId: 'set-1', value: -0.1),
            _member(kind: 'brightness', setId: 'set-2', value: 0.3),
          ],
          setId: 'set-1',
        );

        verifyInOrder([
          () => tuneEditor.selectedIndex = 2,
          () => tuneEditor.onChanged(0.2),
          () => tuneEditor.selectedIndex = 3,
          () => tuneEditor.onChanged(-0.1),
          () => tuneEditor.selectedIndex = 0,
        ]);
        // The set-2 member is never previewed.
        verifyNever(() => tuneEditor.onChanged(0.3));
      },
    );
  });
}
