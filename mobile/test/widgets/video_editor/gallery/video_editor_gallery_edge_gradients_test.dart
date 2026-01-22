// ABOUTME: Tests for ClipGalleryEdgeGradients widget
// ABOUTME: Verifies gradient behavior and IgnorePointer behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_gallery_edge_gradients.dart';

void main() {
  group('ClipGalleryEdgeGradients', () {
    testWidgets('should render with gradient decoration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: Stack(
                children: [
                  ClipGalleryEdgeGradients(opacity: 1, isReordering: false),
                ],
              ),
            ),
          ),
        ),
      );

      // Should have AnimatedContainer with gradient decoration
      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    testWidgets('should ignore pointer events', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClipGalleryEdgeGradients(opacity: 1, isReordering: false),
          ),
        ),
      );

      final ignorePointer = tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(ClipGalleryEdgeGradients),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointer.ignoring, true);
    });

    testWidgets('should apply scaled opacity', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClipGalleryEdgeGradients(opacity: 1, isReordering: false),
          ),
        ),
      );

      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      // Opacity is scaled by 0.65
      expect(opacityWidget.opacity, closeTo(0.65, 0.01));
    });

    testWidgets('should be invisible when opacity is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClipGalleryEdgeGradients(opacity: 0, isReordering: false),
          ),
        ),
      );

      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 0.0);
    });

    testWidgets('should have center transparent area when not reordering', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClipGalleryEdgeGradients(opacity: 1, isReordering: false),
          ),
        ),
      );

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;

      // When not reordering, should have 3 colors (with transparent center)
      expect(gradient.colors.length, 3);
    });

    testWidgets('should have solid gradient when reordering', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClipGalleryEdgeGradients(opacity: 1, isReordering: true),
          ),
        ),
      );

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;

      // When reordering, should have 2 colors (no transparent center)
      expect(gradient.colors.length, 2);
    });
  });
}
