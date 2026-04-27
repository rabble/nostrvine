import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_player.dart';

void main() {
  group(canvasBorderRadiusForAspectRatio, () {
    test('keeps square previews unrounded', () {
      expect(
        canvasBorderRadiusForAspectRatio(model.AspectRatio.square),
        equals(0),
      );
    });

    test('rounds non-square previews', () {
      expect(
        canvasBorderRadiusForAspectRatio(model.AspectRatio.vertical),
        equals(VideoEditorConstants.canvasRadius),
      );
    });
  });

  group(computeClipSize, () {
    group('square (1:1) target', () {
      test('clips tall widget to square using width as shortest side', () {
        // 9:16 video rendered at 219×390
        final result = computeClipSize(
          widgetSize: const Size(219, 390),
          bodySize: const Size(400, 800),
          targetAspectRatio: 1,
        );

        expect(result.width, equals(219));
        expect(result.height, equals(219));
      });

      test('clips wide widget to square using height as shortest side', () {
        // 16:9 video rendered at 640×360
        final result = computeClipSize(
          widgetSize: const Size(640, 360),
          bodySize: const Size(400, 800),
          targetAspectRatio: 1,
        );

        expect(result.width, equals(360));
        expect(result.height, equals(360));
      });

      test('returns same size when widget is already square', () {
        final result = computeClipSize(
          widgetSize: const Size(300, 300),
          bodySize: const Size(400, 800),
          targetAspectRatio: 1,
        );

        expect(result.width, equals(300));
        expect(result.height, equals(300));
      });
    });

    group('vertical (9:16) target', () {
      test('clips to 9:16 when widget matches aspect ratio', () {
        final result = computeClipSize(
          widgetSize: const Size(225, 400),
          bodySize: const Size(400, 800),
          targetAspectRatio: 9 / 16,
        );

        expect(result.width, closeTo(225, 0.01));
        expect(result.height, equals(400));
      });

      test('constrains width for wider-than-target widget', () {
        // Widget is wider than 9:16
        final result = computeClipSize(
          widgetSize: const Size(400, 400),
          bodySize: const Size(400, 800),
          targetAspectRatio: 9 / 16,
        );

        expect(result.width, closeTo(400 * 9 / 16, 0.01));
        expect(result.height, equals(400));
      });
    });

    group('fullscreen mode', () {
      test('returns target-aspect constrained size from widget bounds', () {
        final result = computeClipSize(
          widgetSize: const Size(219, 390),
          bodySize: const Size(400, 800),
          targetAspectRatio: 9 / 16,
        );

        expect(result.width, closeTo(219, 1));
        expect(result.height, closeTo(390, 1));
      });
    });

    group('clip is centered', () {
      test('square clip from tall widget is centered vertically', () {
        const widgetSize = Size(200, 400);
        final clipSize = computeClipSize(
          widgetSize: widgetSize,
          bodySize: const Size(400, 800),
          targetAspectRatio: 1,
        );

        // Verify shortest side is used
        expect(clipSize.width, equals(200));
        expect(clipSize.height, equals(200));

        // Rect.fromCenter would place this at (0, 100) → (200, 300)
        final rect = Rect.fromCenter(
          center: Offset(widgetSize.width / 2, widgetSize.height / 2),
          width: clipSize.width,
          height: clipSize.height,
        );
        expect(rect.left, equals(0));
        expect(rect.top, equals(100));
        expect(rect.right, equals(200));
        expect(rect.bottom, equals(300));
      });
    });
  });
}
