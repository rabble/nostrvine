import 'package:divine_video_player/src/web/web_clip_duration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveClipDurationSeconds', () {
    test('reports the source length when no clip end is set', () {
      expect(
        resolveClipDurationSeconds(
          clipStartSeconds: 0,
          clipEndSeconds: null,
          sourceDurationSeconds: 3.2,
        ),
        3.2,
      );
    });

    test('clamps a clip end past the source to the source length', () {
      expect(
        resolveClipDurationSeconds(
          clipStartSeconds: 0,
          clipEndSeconds: 7,
          sourceDurationSeconds: 3.2,
        ),
        3.2,
        reason:
            'The feed caps every clip blindly; without the clamp a 3.2s video '
            'reports the 7s cap and no consumer arming on duration - epsilon '
            'ever fires.',
      );
    });

    test('keeps a clip end inside the source', () {
      expect(
        resolveClipDurationSeconds(
          clipStartSeconds: 0,
          clipEndSeconds: 7,
          sourceDurationSeconds: 60,
        ),
        7,
      );
    });

    test('subtracts the clip start from the resolved end', () {
      expect(
        resolveClipDurationSeconds(
          clipStartSeconds: 1,
          clipEndSeconds: 3,
          sourceDurationSeconds: 60,
        ),
        2,
      );
      expect(
        resolveClipDurationSeconds(
          clipStartSeconds: 1,
          clipEndSeconds: null,
          sourceDurationSeconds: 3,
        ),
        2,
      );
    });

    test('uses the requested end while the source duration is unknown', () {
      expect(
        resolveClipDurationSeconds(
          clipStartSeconds: 0,
          clipEndSeconds: 7,
          sourceDurationSeconds: double.nan,
        ),
        7,
        reason:
            'element.duration is NaN until metadata loads; reporting zero '
            'there would flap the duration on every refresh before playback.',
      );
    });

    test('uses the requested end for a live source', () {
      expect(
        resolveClipDurationSeconds(
          clipStartSeconds: 0,
          clipEndSeconds: 7,
          sourceDurationSeconds: double.infinity,
        ),
        7,
      );
    });

    test('reports zero when neither a clip end nor a source length exists', () {
      expect(
        resolveClipDurationSeconds(
          clipStartSeconds: 0,
          clipEndSeconds: null,
          sourceDurationSeconds: double.nan,
        ),
        0,
      );
    });

    test('never reports a negative duration for a start past the end', () {
      expect(
        resolveClipDurationSeconds(
          clipStartSeconds: 5,
          clipEndSeconds: 2,
          sourceDurationSeconds: 60,
        ),
        0,
      );
    });
  });
}
