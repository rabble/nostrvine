import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';

void main() {
  group(VideoRecorderMode, () {
    group('label', () {
      test('capture has label "Capture"', () {
        expect(VideoRecorderMode.capture.label, equals('Capture'));
      });

      test('lipSync has label "Lip Sync"', () {
        expect(VideoRecorderMode.lipSync.label, equals('Lip Sync'));
      });

      test('classic has label "Classic"', () {
        expect(VideoRecorderMode.classic.label, equals('Classic'));
      });

      test('upload returns "Upload" label', () {
        expect(VideoRecorderMode.upload.label, equals('Upload'));
      });
    });

    group('hasRecordingLimit', () {
      test('capture has no recording limit', () {
        expect(VideoRecorderMode.capture.hasRecordingLimit, isFalse);
      });

      test('lipSync has no recording limit', () {
        expect(VideoRecorderMode.lipSync.hasRecordingLimit, isFalse);
      });

      test('classic has recording limit', () {
        expect(VideoRecorderMode.classic.hasRecordingLimit, isTrue);
      });

      test('upload has no recording limit', () {
        expect(VideoRecorderMode.upload.hasRecordingLimit, isFalse);
      });
    });

    group('hasVideoEditor', () {
      test('capture has video editor', () {
        expect(VideoRecorderMode.capture.hasVideoEditor, isTrue);
      });

      test('lipSync has video editor', () {
        expect(VideoRecorderMode.lipSync.hasVideoEditor, isTrue);
      });

      test('classic has no video editor', () {
        expect(VideoRecorderMode.classic.hasVideoEditor, isFalse);
      });

      test('upload has no video editor', () {
        expect(VideoRecorderMode.upload.hasVideoEditor, isFalse);
      });
    });

    group('supportGridLines', () {
      test('capture does not support grid lines', () {
        expect(VideoRecorderMode.capture.supportGridLines, isFalse);
      });

      test('lipSync does not support grid lines', () {
        expect(VideoRecorderMode.lipSync.supportGridLines, isFalse);
      });

      test('classic supports grid lines', () {
        expect(VideoRecorderMode.classic.supportGridLines, isTrue);
      });

      test('upload does not support grid lines', () {
        expect(VideoRecorderMode.upload.supportGridLines, isFalse);
      });
    });

    group('defaultAspectRatio', () {
      test('capture defaults to vertical', () {
        expect(
          VideoRecorderMode.capture.defaultAspectRatio,
          equals(model.AspectRatio.vertical),
        );
      });

      test('lipSync defaults to vertical', () {
        expect(
          VideoRecorderMode.lipSync.defaultAspectRatio,
          equals(model.AspectRatio.vertical),
        );
      });

      test('classic defaults to square', () {
        expect(
          VideoRecorderMode.classic.defaultAspectRatio,
          equals(model.AspectRatio.square),
        );
      });

      test('upload defaults to vertical aspect ratio', () {
        expect(
          VideoRecorderMode.upload.defaultAspectRatio,
          equals(model.AspectRatio.vertical),
        );
      });
    });

    group('stopMotion', () {
      test('has label "Stop Motion"', () {
        expect(VideoRecorderMode.stopMotion.label, equals('Stop Motion'));
      });

      test('has no recording limit', () {
        expect(VideoRecorderMode.stopMotion.hasRecordingLimit, isFalse);
      });

      test(
        'has a video editor (previews frames via the stop-motion player)',
        () {
          expect(VideoRecorderMode.stopMotion.hasVideoEditor, isTrue);
        },
      );

      test('supports grid lines (shot-to-shot alignment)', () {
        expect(VideoRecorderMode.stopMotion.supportGridLines, isTrue);
      });

      test('does not support a countdown timer', () {
        expect(VideoRecorderMode.stopMotion.supportsCountdownTimer, isFalse);
      });

      test('defaults to vertical aspect ratio', () {
        expect(
          VideoRecorderMode.stopMotion.defaultAspectRatio,
          equals(model.AspectRatio.vertical),
        );
      });
    });

    group('capturesStills', () {
      test('is true only for stop-motion', () {
        expect(VideoRecorderMode.stopMotion.capturesStills, isTrue);
        expect(VideoRecorderMode.capture.capturesStills, isFalse);
        expect(VideoRecorderMode.classic.capturesStills, isFalse);
        expect(VideoRecorderMode.upload.capturesStills, isFalse);
      });
    });

    group('constrainsAspectRatio', () {
      test('is true only for classic', () {
        // Classic is the 1:1 Vine format by definition. Every other mode must
        // leave the shape to the user's toggle, so switching between them
        // cannot silently rewrite it (#6200).
        expect(VideoRecorderMode.classic.constrainsAspectRatio, isTrue);
        expect(VideoRecorderMode.capture.constrainsAspectRatio, isFalse);
        expect(VideoRecorderMode.lipSync.constrainsAspectRatio, isFalse);
        expect(VideoRecorderMode.stopMotion.constrainsAspectRatio, isFalse);
        expect(VideoRecorderMode.upload.constrainsAspectRatio, isFalse);
      });

      test('every mode that constrains the shape declares its own default', () {
        for (final mode in VideoRecorderMode.values) {
          if (!mode.constrainsAspectRatio) continue;
          expect(
            mode.defaultAspectRatio,
            equals(model.AspectRatio.square),
            reason:
                '${mode.name} constrains the aspect ratio, so its default must '
                'be the shape it enforces',
          );
        }
      });
    });

    group('shape-constraining modes', () {
      // The mode wheel renders VideoRecorderMode.values verbatim, and its end
      // entries are where an over-fling lands. Reordering the enum silently
      // moved `classic` (square) into the last slot in 1.0.16, which is how
      // #6200 shipped — nothing in the suite noticed.
      //
      // The guarantee is NOT that a square mode never sits at an end (the
      // wheel's order is a product decision). It is that reaching such a mode
      // always takes a deliberate gesture, which is pinned in
      // video_recorder_mode_selector_test.dart. What belongs here is the
      // narrower invariant: exactly one mode may impose a shape, so a reorder
      // cannot quietly add another square trap.
      test('classic is the only mode allowed to impose a shape', () {
        final constraining = VideoRecorderMode.values
            .where((m) => m.constrainsAspectRatio)
            .toList();

        expect(constraining, equals([VideoRecorderMode.classic]));
      });

      test('every non-constraining mode defaults to vertical', () {
        for (final mode in VideoRecorderMode.values) {
          if (mode.constrainsAspectRatio) continue;
          expect(
            mode.defaultAspectRatio,
            equals(model.AspectRatio.vertical),
            reason:
                '${mode.name} does not impose a shape, so its default must be '
                'the portrait capture default',
          );
        }
      });
    });
  });
}
