import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';

void main() {
  group(VideoRecorderMode, () {
    group('label', () {
      test('capture has label "Capture"', () {
        expect(VideoRecorderMode.capture.label, equals('Capture'));
      });

      test('classic has label "Classic"', () {
        expect(VideoRecorderMode.classic.label, equals('Classic'));
      });
    });

    group('hasRecordingLimit', () {
      test('capture has no recording limit', () {
        expect(VideoRecorderMode.capture.hasRecordingLimit, isFalse);
      });

      test('classic has recording limit', () {
        expect(VideoRecorderMode.classic.hasRecordingLimit, isTrue);
      });
    });

    group('hasVideoEditor', () {
      test('capture has video editor', () {
        expect(VideoRecorderMode.capture.hasVideoEditor, isTrue);
      });

      test('classic has no video editor', () {
        expect(VideoRecorderMode.classic.hasVideoEditor, isFalse);
      });
    });

    group('supportGridLines', () {
      test('capture does not support grid lines', () {
        expect(VideoRecorderMode.capture.supportGridLines, isFalse);
      });

      test('classic supports grid lines', () {
        expect(VideoRecorderMode.classic.supportGridLines, isTrue);
      });
    });

    group('defaultAspectRatio', () {
      test('capture defaults to vertical', () {
        expect(
          VideoRecorderMode.capture.defaultAspectRatio,
          equals(model.AspectRatio.vertical),
        );
      });

      test('classic defaults to square', () {
        expect(
          VideoRecorderMode.classic.defaultAspectRatio,
          equals(model.AspectRatio.square),
        );
      });
    });
  });
}
