import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';

void main() {
  group(StopMotionClipFrame, () {
    const frame = StopMotionClipFrame(
      path: '/frames/f0.jpg',
      duration: Duration(milliseconds: 83),
    );

    test('holdOverridden defaults to false', () {
      expect(frame.holdOverridden, isFalse);
    });

    test('copyWith updates holdOverridden', () {
      final overridden = frame.copyWith(holdOverridden: true);
      expect(overridden.holdOverridden, isTrue);
      expect(overridden.path, frame.path);
      expect(overridden.duration, frame.duration);
    });

    test('equality and hashCode include holdOverridden', () {
      final overridden = frame.copyWith(holdOverridden: true);
      expect(frame == overridden, isFalse);
      expect(frame.hashCode == overridden.hashCode, isFalse);
      expect(overridden, equals(frame.copyWith(holdOverridden: true)));
    });

    test('JSON round-trips holdOverridden', () {
      final overridden = frame.copyWith(holdOverridden: true);
      final restored = StopMotionClipFrame.fromJson(
        overridden.toJson(),
        '/docs',
        useOriginalPath: true,
      );
      expect(restored.holdOverridden, isTrue);
      expect(restored.duration, overridden.duration);
    });

    test(
      'holdOverridden defaults to false for legacy JSON without the key',
      () {
        final restored = StopMotionClipFrame.fromJson(
          const {'path': 'f0.jpg', 'durationMs': 83},
          '/docs',
          useOriginalPath: true,
        );
        expect(restored.holdOverridden, isFalse);
      },
    );
  });
}
