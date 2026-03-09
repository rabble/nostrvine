import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/video_presentation.dart';

void main() {
  group('videoAlignmentForDimensions', () {
    test('square videos are top-aligned', () {
      expect(videoAlignmentForDimensions(480, 480), Alignment.topCenter);
    });

    test('portrait videos stay centered', () {
      expect(videoAlignmentForDimensions(607, 1080), Alignment.center);
    });

    test('landscape videos stay centered', () {
      expect(videoAlignmentForDimensions(1920, 1080), Alignment.center);
    });

    test('near-square videos still count as square', () {
      expect(isSquareVideoDimensions(500, 480), isTrue);
    });
  });
}
