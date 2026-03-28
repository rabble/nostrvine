// ABOUTME: Tests for content warning helper functions.
// ABOUTME: Verifies shouldShowContentWarningOverlay, contentWarningOverlayLabels,
// ABOUTME: and humanizeContentLabel behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';

void main() {
  group('shouldShowContentWarningOverlay', () {
    test('returns false when both label lists are empty', () {
      final result = shouldShowContentWarningOverlay(
        contentWarningLabels: [],
        warnLabels: [],
      );

      expect(result, isFalse);
    });

    test('returns true when contentWarningLabels is non-empty', () {
      final result = shouldShowContentWarningOverlay(
        contentWarningLabels: ['violence'],
        warnLabels: [],
      );

      expect(result, isTrue);
    });

    test('returns true when warnLabels is non-empty', () {
      final result = shouldShowContentWarningOverlay(
        contentWarningLabels: [],
        warnLabels: ['nudity'],
      );

      expect(result, isTrue);
    });

    test('returns true when both lists are non-empty', () {
      final result = shouldShowContentWarningOverlay(
        contentWarningLabels: ['violence'],
        warnLabels: ['nudity'],
      );

      expect(result, isTrue);
    });
  });

  group('contentWarningOverlayLabels', () {
    test('returns warnLabels when non-empty', () {
      final result = contentWarningOverlayLabels(
        contentWarningLabels: ['violence'],
        warnLabels: ['nudity', 'drugs'],
      );

      expect(result, equals(['nudity', 'drugs']));
    });

    test('falls back to contentWarningLabels when warnLabels is empty', () {
      final result = contentWarningOverlayLabels(
        contentWarningLabels: ['violence', 'graphic-media'],
        warnLabels: [],
      );

      expect(result, equals(['violence', 'graphic-media']));
    });

    test('returns empty list when both are empty', () {
      final result = contentWarningOverlayLabels(
        contentWarningLabels: [],
        warnLabels: [],
      );

      expect(result, isEmpty);
    });
  });

  group('humanizeContentLabel', () {
    test('maps known labels to human-readable strings', () {
      expect(humanizeContentLabel('nudity'), equals('Nudity'));
      expect(humanizeContentLabel('violence'), equals('Violence'));
      expect(humanizeContentLabel('drugs'), equals('Drug Use'));
      expect(humanizeContentLabel('ai-generated'), equals('AI-Generated'));
      expect(
        humanizeContentLabel('flashing-lights'),
        equals('Flashing Lights'),
      );
    });

    test('returns generic fallback for unknown labels', () {
      expect(humanizeContentLabel('unknown-label'), equals('Content Warning'));
    });
  });
}
