import 'dart:ui';

import 'package:divine_camera/divine_camera.dart' show DivineVideoQuality;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/extensions/aspect_ratio_extensions.dart';

void main() {
  group('DivineVideoQualityAspectRatio', () {
    group('resolutionForAspectRatio', () {
      for (final quality in DivineVideoQuality.values) {
        final width = quality.resolution.width;

        test('returns ${width.toInt()}x${width.toInt()} '
            'for square at ${quality.name}', () {
          final result = quality.resolutionForAspectRatio(AspectRatio.square);

          expect(result, equals(Size(width, width)));
        });

        test('returns correct vertical resolution at ${quality.name}', () {
          final result = quality.resolutionForAspectRatio(AspectRatio.vertical);

          expect(result.width, equals(width));
          expect(result.height, closeTo(width / (9 / 16), 0.1));
        });
      }
    });
  });
}
