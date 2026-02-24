// ABOUTME: Tests for haptic feedback logic in VideoEditorClipGallery
// ABOUTME: Verifies the haptic feedback state management pattern

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
}

/// Simulates the delete zone haptic logic from video_editor_clip_gallery.dart.
///
/// Returns the new value of wasOverDeleteZone after processing.
Future<bool> simulateDeleteZoneCheck({
  required bool isOverDeleteZone,
  required bool wasOverDeleteZone,
}) async {
  if (isOverDeleteZone && !wasOverDeleteZone) {
    await HapticService.destructiveZoneFeedback();
  }
  return isOverDeleteZone;
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

  group('VideoEditorClipGallery Haptic Feedback Logic', () {
    // These tests verify the haptic feedback state management pattern
    // used in video_editor_clip_gallery.dart without requiring full
    // widget rendering (which needs VideoPlayer platform mocks).

    test('haptic tracker captures heavyImpact calls', () async {
      hapticTracker.clear();

      // Simulate what the gallery does when entering delete zone
      await HapticService.destructiveZoneFeedback();

      expect(hapticTracker.heavyImpactCount, equals(1));
    });

    test('heavyImpact fires only once when entering delete zone', () async {
      hapticTracker.clear();

      // Simulate the _updateDeleteZoneState pattern from gallery
      var wasOverDeleteZone = false;

      // First entry into delete zone
      wasOverDeleteZone = await simulateDeleteZoneCheck(
        isOverDeleteZone: true,
        wasOverDeleteZone: wasOverDeleteZone,
      );

      expect(hapticTracker.heavyImpactCount, equals(1));

      // Staying in delete zone - should not trigger again
      hapticTracker.clear();
      wasOverDeleteZone = await simulateDeleteZoneCheck(
        isOverDeleteZone: true,
        wasOverDeleteZone: wasOverDeleteZone,
      );

      expect(hapticTracker.heavyImpactCount, equals(0));
    });

    test('_wasOverDeleteZone resets after reorder cancel', () async {
      hapticTracker.clear();

      // Simulate the state management pattern
      var wasOverDeleteZone = false;

      // Enter delete zone
      wasOverDeleteZone = await simulateDeleteZoneCheck(
        isOverDeleteZone: true,
        wasOverDeleteZone: wasOverDeleteZone,
      );
      expect(hapticTracker.heavyImpactCount, equals(1));

      // Simulate _handleReorderCancel - resets the flag
      wasOverDeleteZone = false;

      // Enter delete zone again (after reset)
      hapticTracker.clear();
      await simulateDeleteZoneCheck(
        isOverDeleteZone: true,
        wasOverDeleteZone: wasOverDeleteZone,
      );

      // Should trigger again because flag was reset
      expect(hapticTracker.heavyImpactCount, equals(1));
    });

    test('no haptic when leaving delete zone', () async {
      hapticTracker.clear();

      // Start over delete zone
      const wasOverDeleteZone = true;

      // Leave delete zone
      await simulateDeleteZoneCheck(
        isOverDeleteZone: false,
        wasOverDeleteZone: wasOverDeleteZone,
      );

      // Moving out of zone should not trigger
      expect(hapticTracker.heavyImpactCount, equals(0));
    });
  });
}
