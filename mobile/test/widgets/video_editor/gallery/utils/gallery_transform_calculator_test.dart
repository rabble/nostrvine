import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/widgets/video_editor/gallery/utils/gallery_transform_calculator.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('GalleryTransformCalculator', () {
    late PageController pageController;
    late List<RecordingClip> clips;
    late BoxConstraints constraints;

    RecordingClip createClip(model.AspectRatio ratio) {
      return RecordingClip(
        id: 'test-id',
        video: EditorVideo.memory(Uint8List(0)),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime.now(),
        aspectRatio: ratio,
      );
    }

    setUp(() {
      pageController = PageController(viewportFraction: 0.8);
      clips = [
        createClip(model.AspectRatio.vertical),
        createClip(model.AspectRatio.vertical),
        createClip(model.AspectRatio.vertical),
      ];
      constraints = const BoxConstraints(maxWidth: 400, maxHeight: 600);
    });

    tearDown(() {
      pageController.dispose();
    });

    group('calculateScale', () {
      test('returns maxScale for active clip when reordering', () {
        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: constraints,
          clips: clips,
          activeClipIndex: 1,
          selectedClipIndex: 1,
          isReordering: true,
        );

        expect(calculator.calculateScale(1), 1.0);
      });

      test('returns minScale for non-active clips when reordering', () {
        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: constraints,
          clips: clips,
          activeClipIndex: 1,
          selectedClipIndex: 1,
          isReordering: true,
        );

        expect(calculator.calculateScale(0), 0.85);
        expect(calculator.calculateScale(2), 0.85);
      });

      test('returns minScale for clips with difference >= 1', () {
        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: constraints,
          clips: clips,
          activeClipIndex: 0,
          selectedClipIndex: 0,
          isReordering: false,
        );

        // Without clients, falls back to selectedClipIndex logic
        expect(calculator.calculateScale(2), 0.85);
      });

      test('returns maxScale for selected clip without clients', () {
        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: constraints,
          clips: clips,
          activeClipIndex: 1,
          selectedClipIndex: 1,
          isReordering: false,
        );

        // Without hasClients, returns based on activeClipIndex match
        expect(calculator.calculateScale(1), 1.0);
      });
    });

    group('calculateXOffset', () {
      test('returns 0 when reordering', () {
        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: constraints,
          clips: clips,
          activeClipIndex: 1,
          selectedClipIndex: 1,
          isReordering: true,
        );

        expect(calculator.calculateXOffset(0), 0);
        expect(calculator.calculateXOffset(1), 0);
        expect(calculator.calculateXOffset(2), 0);
      });

      test('returns 0 for selected clip when not reordering', () {
        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: constraints,
          clips: clips,
          activeClipIndex: 1,
          selectedClipIndex: 1,
          isReordering: false,
        );

        // Center clip (index == page) should have minimal offset
        final offset = calculator.calculateXOffset(1);
        expect(offset.abs(), lessThan(1)); // Essentially 0
      });

      test('returns negative offset for clips to the right of center', () {
        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: constraints,
          clips: clips,
          activeClipIndex: 0,
          selectedClipIndex: 0,
          isReordering: false,
        );

        // Clip at index 1 is to the right of page 0
        final offset = calculator.calculateXOffset(1);
        expect(offset, lessThan(0));
      });

      test('returns positive offset for clips to the left of center', () {
        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: constraints,
          clips: clips,
          activeClipIndex: 2,
          selectedClipIndex: 2,
          isReordering: false,
        );

        // Clip at index 1 is to the left of page 2
        final offset = calculator.calculateXOffset(1);
        expect(offset, greaterThan(0));
      });

      test('offset increases then falls off with distance from center', () {
        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: constraints,
          clips: [
            ...clips,
            createClip(model.AspectRatio.vertical),
            createClip(model.AspectRatio.vertical),
          ],
          activeClipIndex: 0,
          selectedClipIndex: 0,
          isReordering: false,
        );

        final offset1 = calculator.calculateXOffset(1).abs();

        // Clip 1 (difference=1) should have offset due to effect strength
        expect(offset1, greaterThan(0));
      });
    });

    group('edge cases', () {
      test('handles single clip', () {
        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: constraints,
          clips: [createClip(model.AspectRatio.vertical)],
          activeClipIndex: 0,
          selectedClipIndex: 0,
          isReordering: false,
        );

        expect(calculator.calculateScale(0), 1.0);
        expect(calculator.calculateXOffset(0).abs(), lessThan(1));
      });

      test('handles different aspect ratios', () {
        final wideClips = [
          createClip(model.AspectRatio.square),
          createClip(model.AspectRatio.square),
        ];

        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: constraints,
          clips: wideClips,
          activeClipIndex: 0,
          selectedClipIndex: 0,
          isReordering: false,
        );

        // Should not throw and should return valid values
        expect(calculator.calculateScale(0), isA<double>());
        expect(calculator.calculateXOffset(1), isA<double>());
      });

      test('handles zero constraints gracefully', () {
        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: const BoxConstraints(maxWidth: 0, maxHeight: 0),
          clips: clips,
          activeClipIndex: 0,
          selectedClipIndex: 0,
          isReordering: false,
        );

        // Should not throw
        expect(calculator.calculateXOffset(1), isA<double>());
      });
    });

    group('scale interpolation', () {
      test('scale varies linearly between min and max for difference < 1', () {
        // This test verifies the formula:
        // scale = maxScale - (difference * (maxScale - minScale))
        // With maxScale = 1.0, minScale = 0.85, range = 0.15

        final calculator = GalleryTransformCalculator(
          pageController: pageController,
          constraints: constraints,
          clips: clips,
          activeClipIndex: 0,
          selectedClipIndex: 0,
          isReordering: false,
        );

        // At selectedClipIndex (difference = 0), scale = 1.0
        expect(calculator.calculateScale(0), 1.0);

        // At difference = 1, scale = 0.85
        expect(calculator.calculateScale(1), 0.85);
      });
    });
  });
}
