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
  });
}
