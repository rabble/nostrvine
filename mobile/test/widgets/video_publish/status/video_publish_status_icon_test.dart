import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/widgets/video_publish/status/video_publish_status_icon.dart';

void main() {
  group('VideoPublishStatusIcon', () {
    testWidgets('shows error icon for error state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPublishStatusIcon(publishState: VideoPublishState.error),
          ),
        ),
      );

      final iconFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.error_outline &&
            widget.color == Colors.red,
      );
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('shows check icon for completed state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPublishStatusIcon(
              publishState: VideoPublishState.completed,
            ),
          ),
        ),
      );

      final iconFinder = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Icons.check_circle,
      );
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator for uploading state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPublishStatusIcon(
              publishState: VideoPublishState.uploading,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator for retryUpload state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPublishStatusIcon(
              publishState: VideoPublishState.retryUpload,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows cloud upload icon for publishToNostr state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPublishStatusIcon(
              publishState: VideoPublishState.publishToNostr,
            ),
          ),
        ),
      );

      final iconFinder = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Icons.cloud_upload,
      );
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator for idle state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPublishStatusIcon(publishState: VideoPublishState.idle),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator for initialize state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPublishStatusIcon(
              publishState: VideoPublishState.initialize,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator for preparing state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPublishStatusIcon(
              publishState: VideoPublishState.preparing,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
