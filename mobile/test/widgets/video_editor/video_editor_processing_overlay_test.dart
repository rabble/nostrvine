// ABOUTME: Tests for VideoEditorProcessingOverlay widget
// ABOUTME: Validates processing overlay UI and styling

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/video_editor_processing_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorProcessingOverlay Widget Tests', () {
    Widget buildTestWidget() {
      return const MaterialApp(
        home: Scaffold(body: VideoEditorProcessingOverlay()),
      );
    }

    testWidgets('displays processing text', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Processing...'), findsOneWidget);
    });

    testWidgets('displays divine icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/icon/divine_icon_transparent.png',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(VideoEditorProcessingOverlay), findsOneWidget);
    });
  });
}
