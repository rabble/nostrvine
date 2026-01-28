// ABOUTME: Tests for VideoRecorderCameraPlaceholder widget
// ABOUTME: Validates placeholder rendering, icons, and recording states

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_camera_placeholder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderCameraPlaceholder Widget Tests', () {
    testWidgets('renders placeholder widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VideoRecorderCameraPlaceholder()),
        ),
      );

      expect(find.byType(VideoRecorderCameraPlaceholder), findsOneWidget);
    });

    testWidgets('shows videocam icon when no error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VideoRecorderCameraPlaceholder()),
        ),
      );

      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
      expect(find.byIcon(Icons.videocam_off_rounded), findsNothing);
    });

    testWidgets('shows videocam_off icon when error message provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoRecorderCameraPlaceholder(
              errorMessage: 'No camera found',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.videocam_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);
    });

    testWidgets('displays error message text when provided', (tester) async {
      const errorMessage = 'No camera found. Please connect a camera.';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoRecorderCameraPlaceholder(errorMessage: errorMessage),
          ),
        ),
      );

      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('does not display error text when no error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VideoRecorderCameraPlaceholder()),
        ),
      );

      // Should not find any Text widget other than potential debug text
      final textWidgets = find.byType(Text);
      expect(textWidgets, findsNothing);
    });
  });
}
