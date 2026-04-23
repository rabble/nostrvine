// ABOUTME: Unit tests for TimelineSnapController.
// ABOUTME: Verifies snap detection, release behavior, and reset state.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/timeline_snap_controller.dart';

void main() {
  group(TimelineSnapController, () {
    test('snaps when raw edge is within catch threshold', () {
      final controller = TimelineSnapController(
        direction: SnapEdgeDirection.positive,
        pixelsPerSecond: TimelineConstants.pixelsPerSecond,
      );
      controller.begin(0);

      final snapped = controller.update(2, {0, 1000});

      expect(snapped, equals(0));
      expect(controller.isSnapped, isTrue);
    });

    test('releases snap after exceeding dead zone', () {
      final controller = TimelineSnapController(
        direction: SnapEdgeDirection.positive,
        pixelsPerSecond: TimelineConstants.pixelsPerSecond,
      );
      controller.begin(0);

      controller.update(0, {0});
      controller.accumulate(TimelineConstants.snapDeadZonePx + 1);
      final released = controller.update(300, {0});

      expect(released, equals(0));
      expect(controller.isSnapped, isFalse);
    });

    test('reset clears snapped state and effective accumulator', () {
      final controller = TimelineSnapController(
        direction: SnapEdgeDirection.negative,
        pixelsPerSecond: TimelineConstants.pixelsPerSecond,
      );
      controller.begin(1000);
      controller.accumulate(50);
      controller.update(995, {1000});

      controller.reset();

      expect(controller.isSnapped, isFalse);
      expect(controller.effectiveAccPx, equals(0));
    });
  });
}
