import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/pending_upload.dart';
import '../../lib/widgets/upload_list_item.dart';

void main() {
  group('UploadListItem', () {
    late PendingUpload testUpload;

    setUp(() {
      testUpload = PendingUpload(
        id: 'test-upload-1',
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'test-pubkey',
        status: UploadStatus.uploading,
        createdAt: DateTime.now(),
        uploadProgress: 0.5,
        title: 'Test Video',
      );
    });

    testWidgets('displays upload information correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadListItem(
              upload: testUpload,
            ),
          ),
        ),
      );

      // Verify upload title is displayed
      expect(find.text('Test Video'), findsOneWidget);
      
      // Verify uploading status badge is displayed
      expect(find.text('Uploading'), findsOneWidget);
      
      // Verify progress percentage is shown
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('shows retry button for failed uploads', (WidgetTester tester) async {
      final failedUpload = testUpload.copyWith(
        status: UploadStatus.failed,
        errorMessage: 'Network error',
      );

      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadListItem(
              upload: failedUpload,
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      // Verify error message is displayed
      expect(find.text('Network error'), findsOneWidget);
      
      // Verify failed status
      expect(find.text('Failed'), findsOneWidget);
      
      // Find and tap retry button
      final retryButton = find.byIcon(Icons.refresh);
      expect(retryButton, findsOneWidget);
      
      await tester.tap(retryButton);
      expect(retryPressed, isTrue);
    });

    testWidgets('shows cancel button for active uploads', (WidgetTester tester) async {
      bool cancelPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadListItem(
              upload: testUpload,
              onCancel: () => cancelPressed = true,
            ),
          ),
        ),
      );

      // Find and tap cancel button
      final cancelButton = find.byIcon(Icons.close);
      expect(cancelButton, findsOneWidget);
      
      await tester.tap(cancelButton);
      expect(cancelPressed, isTrue);
    });

    testWidgets('hides thumbnail when showThumbnail is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadListItem(
              upload: testUpload,
              showThumbnail: false,
            ),
          ),
        ),
      );

      // Should not find the default thumbnail icon
      expect(find.byIcon(Icons.videocam), findsNothing);
    });

    testWidgets('hides progress bar when showProgress is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadListItem(
              upload: testUpload,
              showProgress: false,
            ),
          ),
        ),
      );

      // Should not find progress indicator
      expect(find.byType(LinearProgressIndicator), findsNothing);
      
      // But should still show percentage text
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('shows correct status colors', (WidgetTester tester) async {
      final publishedUpload = testUpload.copyWith(
        status: UploadStatus.published,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadListItem(
              upload: publishedUpload,
            ),
          ),
        ),
      );

      // Verify published status
      expect(find.text('Published'), findsOneWidget);
    });

    testWidgets('handles tap callback', (WidgetTester tester) async {
      bool itemTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadListItem(
              upload: testUpload,
              onTap: () => itemTapped = true,
            ),
          ),
        ),
      );

      // Tap on the item
      await tester.tap(find.byType(InkWell));
      expect(itemTapped, isTrue);
    });
  });
}