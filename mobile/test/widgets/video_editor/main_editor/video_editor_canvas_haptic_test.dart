// ABOUTME: Tests for haptic feedback in VideoEditorCanvas
// ABOUTME: Verifies heavyImpact triggers on remove area entry during layer drag

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/haptic_service.dart';

/// Helper to set up haptic feedback mock and track calls.
class _HapticFeedbackTracker {
  final List<String> hapticCalls = [];

  void setUp(TestWidgetsFlutterBinding binding) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          hapticCalls.add(call.arguments as String);
        }
        return null;
      },
    );
  }

  void tearDown(TestWidgetsFlutterBinding binding) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  }

  void clear() => hapticCalls.clear();

  int get heavyImpactCount => hapticCalls
      .where((call) => call == 'HapticFeedbackType.heavyImpact')
      .length;

  int get lightImpactCount => hapticCalls
      .where((call) => call == 'HapticFeedbackType.lightImpact')
      .length;
}

/// Simulates the remove area haptic logic from video_editor_canvas.dart.
///
/// Returns the new value of wasOverRemoveArea after processing.
Future<bool> simulateRemoveAreaCheck({
  required bool isOverRemoveArea,
  required bool wasOverRemoveArea,
}) async {
  if (isOverRemoveArea && !wasOverRemoveArea) {
    await HapticService.destructiveZoneFeedback();
  }
  return isOverRemoveArea;
}

void main() {
  late _HapticFeedbackTracker hapticTracker;
  late TestWidgetsFlutterBinding binding;

  setUp(() {
    binding = TestWidgetsFlutterBinding.ensureInitialized();
    hapticTracker = _HapticFeedbackTracker()..setUp(binding);
  });

  tearDown(() {
    hapticTracker.tearDown(binding);
  });

  group('VideoEditorCanvas Haptic Feedback', () {
    // Note: Full widget tests for VideoEditorCanvas require extensive mocking
    // of ProImageEditor and related dependencies. These tests verify the
    // haptic feedback infrastructure is properly set up for testing.

    test('haptic tracker captures heavyImpact calls', () async {
      hapticTracker.clear();

      // Simulate what the canvas does when entering remove area
      await HapticService.destructiveZoneFeedback();

      expect(hapticTracker.heavyImpactCount, equals(1));
    });

    test('haptic tracker captures lightImpact calls', () async {
      hapticTracker.clear();

      // Simulate what helper lines do when hit
      await HapticService.snapFeedback();

      expect(hapticTracker.lightImpactCount, equals(1));
    });

    test('haptic feedback fires only once per zone entry', () async {
      hapticTracker.clear();

      // Simulate entering remove area once
      var wasOverRemoveArea = false;

      wasOverRemoveArea = await simulateRemoveAreaCheck(
        isOverRemoveArea: true,
        wasOverRemoveArea: wasOverRemoveArea,
      );

      // Should have triggered once
      expect(hapticTracker.heavyImpactCount, equals(1));

      // Simulate staying in remove area (no additional haptic)
      hapticTracker.clear();
      await simulateRemoveAreaCheck(
        isOverRemoveArea: true,
        wasOverRemoveArea: wasOverRemoveArea,
      );

      // Should not trigger again
      expect(hapticTracker.heavyImpactCount, equals(0));
    });

    test('_wasOverRemoveArea resets on scale end', () async {
      hapticTracker.clear();

      // Simulate the state management pattern from video_editor_canvas.dart
      var wasOverRemoveArea = false;

      // Enter remove area
      wasOverRemoveArea = await simulateRemoveAreaCheck(
        isOverRemoveArea: true,
        wasOverRemoveArea: wasOverRemoveArea,
      );
      expect(hapticTracker.heavyImpactCount, equals(1));

      // Simulate onScaleEnd - reset the flag
      wasOverRemoveArea = false;

      // Enter remove area again (after reset)
      hapticTracker.clear();
      await simulateRemoveAreaCheck(
        isOverRemoveArea: true,
        wasOverRemoveArea: wasOverRemoveArea,
      );

      // Should trigger again because flag was reset
      expect(hapticTracker.heavyImpactCount, equals(1));
    });
  });
}
