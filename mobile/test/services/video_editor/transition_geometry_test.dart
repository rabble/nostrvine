import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/transition_geometry.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType;

void main() {
  const dissolve = ClipTransition(type: ClipTransitionType.dissolve);
  const fadeToBlack = ClipTransition(type: ClipTransitionType.fadeToBlack);

  group('transitionConsumedPerSide', () {
    test('an overlap consumes twice its duration per side', () {
      final t = dissolve.copyWith(duration: const Duration(milliseconds: 400));
      expect(
        transitionConsumedPerSide(
          const Duration(seconds: 3),
          const Duration(seconds: 3),
          t,
        ),
        equals(const Duration(milliseconds: 800)),
      );
    });

    test('a dip consumes half its duration per side', () {
      final t = fadeToBlack.copyWith(duration: const Duration(seconds: 2));
      expect(
        transitionConsumedPerSide(
          const Duration(seconds: 3),
          const Duration(seconds: 3),
          t,
        ),
        equals(const Duration(seconds: 1)),
      );
    });

    test('clamps to the shorter of the two adjacent clips', () {
      final t = fadeToBlack.copyWith(duration: const Duration(seconds: 4));
      // Half of 4s = 2s, but the shorter clip is only 1s.
      expect(
        transitionConsumedPerSide(
          const Duration(seconds: 1),
          const Duration(seconds: 3),
          t,
        ),
        equals(const Duration(seconds: 1)),
      );
    });
  });

  group('transitionDurationForConsumed', () {
    test('inverts the overlap geometry (consumed × 0.5)', () {
      expect(
        transitionDurationForConsumed(
          const Duration(milliseconds: 800),
          ClipTransitionType.dissolve,
        ),
        equals(const Duration(milliseconds: 400)),
      );
    });

    test('inverts the dip geometry (consumed × 2)', () {
      expect(
        transitionDurationForConsumed(
          const Duration(milliseconds: 500),
          ClipTransitionType.fadeToBlack,
        ),
        equals(const Duration(seconds: 1)),
      );
    });

    test('returns zero when there is no room', () {
      expect(
        transitionDurationForConsumed(
          Duration.zero,
          ClipTransitionType.dissolve,
        ),
        equals(Duration.zero),
      );
      expect(
        transitionDurationForConsumed(
          const Duration(milliseconds: -10),
          ClipTransitionType.fadeToBlack,
        ),
        equals(Duration.zero),
      );
    });

    test('round-trips with transitionConsumedPerSide for in-bounds values', () {
      final t = dissolve.copyWith(duration: const Duration(milliseconds: 600));
      final consumed = transitionConsumedPerSide(
        const Duration(seconds: 5),
        const Duration(seconds: 5),
        t,
      );
      expect(
        transitionDurationForConsumed(consumed, ClipTransitionType.dissolve),
        equals(const Duration(milliseconds: 600)),
      );
    });
  });
}
