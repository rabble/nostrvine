import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_clip_editor/gallery/controllers/clip_reorder_controller.dart';

void main() {
  group('ClipReorderController', () {
    late ClipReorderController controller;

    setUp(() {
      controller = ClipReorderController();
    });

    tearDown(() {
      controller.dispose();
    });

    group('startReorder', () {
      test('initializes all indices to the given clip index', () {
        controller.startReorder(3);

        expect(controller.startIndex, 3);
        expect(controller.targetIndex, 3);
        expect(controller.updatedIndex, 3);
      });

      test('resets accumulated drag offset', () {
        controller
          ..addDragOffset(100)
          ..startReorder(2);

        expect(controller.accumulatedDragOffset, 0);
      });

      test('enables tween offset', () {
        controller
          ..disableTweenOffset()
          ..startReorder(0);

        expect(controller.enableTweenOffset, true);
      });
    });

    group('addDragOffset', () {
      test('accumulates positive drag offsets', () {
        controller
          ..addDragOffset(10)
          ..addDragOffset(20);

        expect(controller.accumulatedDragOffset, 30);
      });

      test('accumulates negative drag offsets', () {
        controller
          ..addDragOffset(-15)
          ..addDragOffset(-25);

        expect(controller.accumulatedDragOffset, -40);
      });

      test('accumulates mixed drag offsets correctly', () {
        controller
          ..addDragOffset(50)
          ..addDragOffset(-30);

        expect(controller.accumulatedDragOffset, 20);
      });
    });

    group('resetAccumulatedOffset', () {
      test('resets offset to zero', () {
        controller
          ..addDragOffset(100)
          ..resetAccumulatedOffset();

        expect(controller.accumulatedDragOffset, 0);
      });
    });

    group('updateTargetIndex', () {
      test('updates target and updated index', () {
        controller
          ..startReorder(0)
          ..updateTargetIndex(2);

        expect(controller.targetIndex, 2);
        expect(controller.updatedIndex, 2);
      });

      test('preserves start index', () {
        controller
          ..startReorder(1)
          ..updateTargetIndex(3);

        expect(controller.startIndex, 1);
      });

      test('resets accumulated drag offset', () {
        controller
          ..addDragOffset(50)
          ..updateTargetIndex(2);

        expect(controller.accumulatedDragOffset, 0);
      });
    });

    group('drag reset animation', () {
      test('prepareForDragReset saves current drag offset', () {
        controller.dragOffsetNotifier.value = 42.5;
        controller.prepareForDragReset();

        expect(controller.dragResetStartValue, 42.5);
      });

      test('updateDragOffsetFromAnimation interpolates to zero', () {
        controller.dragOffsetNotifier.value = 100;
        controller
          ..prepareForDragReset()
          // At 0% progress, offset should be at start value
          ..updateDragOffsetFromAnimation(0);
        expect(controller.dragOffsetNotifier.value, 100);

        // At 50% progress, offset should be half
        controller.updateDragOffsetFromAnimation(0.5);
        expect(controller.dragOffsetNotifier.value, 50);

        // At 100% progress, offset should be zero
        controller.updateDragOffsetFromAnimation(1);
        expect(controller.dragOffsetNotifier.value, 0);
      });

      test('updateDragOffsetFromAnimation works with negative offset', () {
        controller.dragOffsetNotifier.value = -80;
        controller
          ..prepareForDragReset()
          ..updateDragOffsetFromAnimation(0.5);
        expect(controller.dragOffsetNotifier.value, -40);
      });
    });

    group('completeReorder', () {
      test('resets drag offset notifier to zero', () {
        controller.dragOffsetNotifier.value = 50;
        controller.completeReorder();

        expect(controller.dragOffsetNotifier.value, 0);
      });

      test('resets accumulated drag offset', () {
        controller
          ..addDragOffset(100)
          ..completeReorder();

        expect(controller.accumulatedDragOffset, 0);
      });
    });

    group('disableTweenOffset', () {
      test('sets enableTweenOffset to false', () {
        controller
          ..startReorder(0) // enables tween
          ..disableTweenOffset();

        expect(controller.enableTweenOffset, false);
      });
    });

    group('shouldAnimateReset', () {
      test('returns true when drag offset exceeds threshold', () {
        controller.dragOffsetNotifier.value = 0.2;
        expect(controller.shouldAnimateReset, true);

        controller.dragOffsetNotifier.value = -0.2;
        expect(controller.shouldAnimateReset, true);
      });

      test('returns false when drag offset is below threshold', () {
        controller.dragOffsetNotifier.value = 0.05;
        expect(controller.shouldAnimateReset, false);

        controller.dragOffsetNotifier.value = 0;
        expect(controller.shouldAnimateReset, false);
      });

      test('threshold is 0.1', () {
        controller.dragOffsetNotifier.value = 0.1;
        expect(controller.shouldAnimateReset, false);

        controller.dragOffsetNotifier.value = 0.11;
        expect(controller.shouldAnimateReset, true);
      });
    });

    group('full reorder workflow', () {
      test('simulates complete reorder from index 1 to 3', () {
        // Start reorder at clip 1
        controller.startReorder(1);
        expect(controller.startIndex, 1);
        expect(controller.enableTweenOffset, true);

        // Drag right
        controller.addDragOffset(50);
        controller.dragOffsetNotifier.value = 20;

        // Move to index 2
        controller.updateTargetIndex(2);
        expect(controller.targetIndex, 2);
        expect(controller.accumulatedDragOffset, 0);

        // Continue dragging
        controller
          ..addDragOffset(50)
          // Move to index 3
          ..updateTargetIndex(3);
        expect(controller.targetIndex, 3);

        // Complete reorder
        controller
          ..prepareForDragReset()
          ..updateDragOffsetFromAnimation(1)
          ..completeReorder();

        expect(controller.startIndex, 1);
        expect(controller.updatedIndex, 3);
        expect(controller.dragOffsetNotifier.value, 0);
      });
    });

    group('isLeavingClipArea', () {
      test('returns true when pointer is below clip area with padding', () {
        // clipAreaPadding is 20, so maxHeight + 20 is the threshold
        expect(controller.isLeavingClipArea(121, 100), true);
      });

      test('returns false when pointer is within clip area', () {
        expect(controller.isLeavingClipArea(100, 100), false);
        expect(controller.isLeavingClipArea(120, 100), false);
      });

      test('returns false when pointer is exactly at boundary', () {
        // At exactly maxHeight + clipAreaPadding, should return false
        expect(controller.isLeavingClipArea(120, 100), false);
      });
    });

    group('updateVisualDragOffset', () {
      test('updates drag offset notifier with delta', () {
        controller.updateVisualDragOffset(10, 100);
        expect(controller.dragOffsetNotifier.value, 10);
      });

      test('accumulates multiple updates', () {
        controller
          ..updateVisualDragOffset(10, 100)
          ..updateVisualDragOffset(15, 100);
        expect(controller.dragOffsetNotifier.value, 25);
      });

      test('clamps positive values to max drag offset', () {
        // dragClampFactor is 0.3, so maxDragOffset = 100 * 0.3 = 30
        controller.updateVisualDragOffset(50, 100);
        expect(controller.dragOffsetNotifier.value, 30);
      });

      test('clamps negative values to negative max drag offset', () {
        controller.updateVisualDragOffset(-50, 100);
        expect(controller.dragOffsetNotifier.value, -30);
      });
    });

    group('calculateReorderThreshold', () {
      test('returns threshold based on viewport and clip count', () {
        // viewportFraction is 0.8
        // threshold = 400 * 0.8 / 4 / 2 = 40
        final threshold = controller.calculateReorderThreshold(400, 4);
        expect(threshold, 40);
      });

      test('clamps to minimum threshold', () {
        // reorderThresholdMin is 30
        // With many clips: 400 * 0.8 / 20 / 2 = 8, clamped to 30
        final threshold = controller.calculateReorderThreshold(400, 20);
        expect(threshold, 30);
      });

      test('clamps to maximum threshold', () {
        // reorderThresholdMax is 120
        // With 1 clip: 400 * 0.8 / 1 / 2 = 160, clamped to 120
        final threshold = controller.calculateReorderThreshold(400, 1);
        expect(threshold, 120);
      });
    });

    group('calculateNewTargetIndex', () {
      test('returns next index when dragging right', () {
        controller
          ..startReorder(1)
          ..addDragOffset(50);

        expect(controller.calculateNewTargetIndex(5), 2);
      });

      test('returns previous index when dragging left', () {
        controller
          ..startReorder(2)
          ..addDragOffset(-50);

        expect(controller.calculateNewTargetIndex(5), 1);
      });

      test('returns null when at last index and dragging right', () {
        controller
          ..startReorder(4)
          ..addDragOffset(50);

        expect(controller.calculateNewTargetIndex(5), null);
      });

      test('returns null when at first index and dragging left', () {
        controller
          ..startReorder(0)
          ..addDragOffset(-50);

        expect(controller.calculateNewTargetIndex(5), null);
      });

      test('returns null when no drag offset', () {
        controller.startReorder(2);

        expect(controller.calculateNewTargetIndex(5), null);
      });
    });

    group('handleEnterDeleteZone', () {
      test('prepares for drag reset if offset exceeds threshold', () {
        controller.dragOffsetNotifier.value = 50;
        final shouldAnimate = controller.handleEnterDeleteZone();

        expect(shouldAnimate, true);
        expect(controller.dragResetStartValue, 50);
        expect(controller.accumulatedDragOffset, 0);
      });

      test('returns false if offset below threshold', () {
        controller.dragOffsetNotifier.value = 0.05;
        final shouldAnimate = controller.handleEnterDeleteZone();

        expect(shouldAnimate, false);
        expect(controller.accumulatedDragOffset, 0);
      });

      test('resets accumulated offset regardless of threshold', () {
        controller.addDragOffset(100);
        controller.dragOffsetNotifier.value = 0;
        controller.handleEnterDeleteZone();

        expect(controller.accumulatedDragOffset, 0);
      });
    });

    group('calculateIndexAfterDeletion', () {
      test('returns same index if within bounds', () {
        controller.startReorder(2);

        expect(controller.calculateIndexAfterDeletion(5), 2);
      });

      test('returns last index if target exceeds remaining count', () {
        controller.startReorder(4);

        expect(controller.calculateIndexAfterDeletion(3), 2);
      });

      test('returns 0 for single remaining clip', () {
        controller.startReorder(0);

        expect(controller.calculateIndexAfterDeletion(1), 0);
      });
    });
  });
}
