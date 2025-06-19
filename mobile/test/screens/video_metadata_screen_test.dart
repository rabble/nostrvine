// ABOUTME: Test file for VideoMetadataScreen UI and functionality
// ABOUTME: Verifies video preview, form validation, and upload integration

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../lib/screens/video_metadata_screen.dart';
import '../../lib/services/upload_manager.dart';
import '../../lib/services/nostr_service_interface.dart';
import '../../lib/models/pending_upload.dart';

// Mock classes
class MockUploadManager extends Mock implements UploadManager {}
class MockNostrService extends Mock implements INostrService {}
class MockFile extends Mock implements File {}
class MockPendingUpload extends Mock implements PendingUpload {}

// Fake classes for fallbacks
class FakeFile extends Fake implements File {}
class FakePendingUpload extends Fake implements PendingUpload {}

void main() {
  late MockUploadManager mockUploadManager;
  late MockNostrService mockNostrService;
  late MockFile mockVideoFile;
  late MockPendingUpload mockUpload;

  setUpAll(() {
    registerFallbackValue(FakeFile());
    registerFallbackValue(FakePendingUpload());
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    mockUploadManager = MockUploadManager();
    mockNostrService = MockNostrService();
    mockVideoFile = MockFile();
    mockUpload = MockPendingUpload();

    // Setup mock file
    when(() => mockVideoFile.path).thenReturn('/tmp/test_video.mp4');
    when(() => mockVideoFile.existsSync()).thenReturn(true);

    // Setup mock NostrService
    when(() => mockNostrService.publicKey).thenReturn('test_pubkey_123');

    // Setup mock upload
    when(() => mockUpload.id).thenReturn('test_upload_id');
    when(() => mockUploadManager.uploadVideo(
      videoFile: any(named: 'videoFile'),
      nostrPubkey: any(named: 'nostrPubkey'),
      title: any(named: 'title'),
      description: any(named: 'description'),
      hashtags: any(named: 'hashtags'),
    )).thenAnswer((_) async => mockUpload);
  });

  Widget createTestWidget({
    VoidCallback? onCancel,
    VoidCallback? onPublish,
  }) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<UploadManager>.value(value: mockUploadManager),
          ChangeNotifierProvider<INostrService>.value(value: mockNostrService),
        ],
        child: VideoMetadataScreen(
          videoFile: mockVideoFile,
          onCancel: onCancel,
          onPublish: onPublish,
        ),
      ),
    );
  }

  group('VideoMetadataScreen', () {
    testWidgets('displays basic UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for main UI elements
      expect(find.text('Add Details'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Hashtags'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
    });

    testWidgets('title field works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find and interact with title field
      final titleField = find.byKey(const Key('title_field')).first;
      await tester.enterText(titleField, 'My Test Video');
      await tester.pumpAndSettle();

      // Verify text was entered
      expect(find.text('My Test Video'), findsOneWidget);
    });

    testWidgets('description field works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find and interact with description field
      final descriptionField = find.byKey(const Key('description_field')).first;
      await tester.enterText(descriptionField, 'This is a test video description');
      await tester.pumpAndSettle();

      // Verify text was entered
      expect(find.text('This is a test video description'), findsOneWidget);
    });

    testWidgets('publish button is disabled when title is empty', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find publish button
      final publishButton = find.text('Publish');
      expect(publishButton, findsOneWidget);

      // Button should be disabled when no title is entered
      final buttonWidget = tester.widget<TextButton>(find.ancestor(
        of: publishButton,
        matching: find.byType(TextButton),
      ));
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('publish button is enabled when title is filled', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter title
      final titleField = find.byKey(const Key('title_field')).first;
      await tester.enterText(titleField, 'Test Video');
      await tester.pumpAndSettle();

      // Find publish button
      final publishButton = find.text('Publish');
      expect(publishButton, findsOneWidget);

      // Button should be enabled when title is entered
      final buttonWidget = tester.widget<TextButton>(find.ancestor(
        of: publishButton,
        matching: find.byType(TextButton),
      ));
      expect(buttonWidget.onPressed, isNotNull);
    });

    testWidgets('character counters display correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show initial character counts
      expect(find.text('0/100'), findsOneWidget); // Title counter
      expect(find.text('0/280'), findsOneWidget); // Description counter
    });

    testWidgets('close button triggers onCancel callback', (WidgetTester tester) async {
      bool cancelCalled = false;
      
      await tester.pumpWidget(createTestWidget(
        onCancel: () => cancelCalled = true,
      ));
      await tester.pumpAndSettle();

      // Tap close button
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
    });

    testWidgets('video upload is triggered with correct parameters', (WidgetTester tester) async {
      bool publishCalled = false;
      
      await tester.pumpWidget(createTestWidget(
        onPublish: () => publishCalled = true,
      ));
      await tester.pumpAndSettle();

      // Fill in the form
      final titleField = find.byKey(const Key('title_field')).first;
      await tester.enterText(titleField, 'Test Video Title');
      
      final descriptionField = find.byKey(const Key('description_field')).first;
      await tester.enterText(descriptionField, 'Test video description');
      
      await tester.pumpAndSettle();

      // Tap publish button
      final publishButton = find.text('Publish');
      await tester.tap(publishButton);
      await tester.pumpAndSettle();

      // Verify upload was called with correct parameters
      verify(() => mockUploadManager.uploadVideo(
        videoFile: mockVideoFile,
        nostrPubkey: 'test_pubkey_123',
        title: 'Test Video Title',
        description: 'Test video description',
        hashtags: any(named: 'hashtags'),
      )).called(1);

      // Note: onPublish callback is called after successful upload
      expect(publishCalled, isTrue);
    });
  });

  group('Form Validation', () {
    testWidgets('enforces title character limit', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter text exceeding limit
      final titleField = find.byKey(const Key('title_field')).first;
      final longTitle = 'A' * 150; // Exceeds 100 character limit
      await tester.enterText(titleField, longTitle);
      await tester.pumpAndSettle();

      // Character counter should show over limit
      expect(find.text('150/100'), findsOneWidget);
    });

    testWidgets('enforces description character limit', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter text exceeding limit
      final descriptionField = find.byKey(const Key('description_field')).first;
      final longDescription = 'A' * 300; // Exceeds 280 character limit
      await tester.enterText(descriptionField, longDescription);
      await tester.pumpAndSettle();

      // Character counter should show over limit
      expect(find.text('300/280'), findsOneWidget);
    });
  });
}