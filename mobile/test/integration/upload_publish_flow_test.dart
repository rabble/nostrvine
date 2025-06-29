// ABOUTME: Integration test for the complete video upload and publish flow
// ABOUTME: Tests the interaction between VinePreviewScreen, UploadManager, and VideoEventPublisher

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/screens/vine_preview_screen.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/nostr_service_interface.dart';
// import 'package:openvine/services/upload_service.dart'; // Service doesn't exist
import 'package:openvine/providers/profile_videos_provider.dart';

class MockFile extends Mock implements File {}
class MockUploadManager extends Mock implements UploadManager {}
class MockVideoEventPublisher extends Mock implements VideoEventPublisher {}
class MockINostrService extends Mock implements INostrService {}
// class MockUploadService extends Mock implements UploadService {} // Service doesn't exist
class MockProfileVideosProvider extends Mock implements ProfileVideosProvider {}
class MockNavigatorObserver extends Mock implements NavigatorObserver {}
class FakePendingUpload extends Fake implements PendingUpload {}
void main() {
  setUpAll(() {
    registerFallbackValue(FakePendingUpload());
  });
  late MockFile mockVideoFile;
  late MockUploadManager mockUploadManager;
  late MockVideoEventPublisher mockVideoEventPublisher;
  late MockINostrService mockNostrService;
  late MockProfileVideosProvider mockProfileVideosProvider;
  late MockNavigatorObserver mockNavigatorObserver;

  setUp(() {
    mockVideoFile = MockFile();
    mockUploadManager = MockUploadManager();
    mockVideoEventPublisher = MockVideoEventPublisher();
    mockNostrService = MockINostrService();
    mockProfileVideosProvider = MockProfileVideosProvider();
    mockNavigatorObserver = MockNavigatorObserver();

    // Setup basic mock behaviors
    when(() => mockVideoFile.path).thenReturn('/path/to/test/video.mp4');
    when(() => mockVideoFile.existsSync()).thenReturn(true);
    when(() => mockVideoFile.exists()).thenAnswer((_) async => true);
    when(() => mockVideoFile.readAsBytes()).thenAnswer((_) async => List.filled(1000, 0));
    
    when(() => mockNostrService.userPublicKey).thenReturn('test-pubkey-123');
    when(() => mockProfileVideosProvider.refreshVideos()).thenAnswer((_) async {});
  });

  group('Upload and Publish Flow Integration', () {
    testWidgets('should upload once and publish with custom metadata', (WidgetTester tester) async {
      // Arrange
      final testUpload = PendingUpload.create(
        localVideoPath: '/path/to/test/video.mp4',
        nostrPubkey: 'test-pubkey-123',
        title: 'Placeholder Title',
        description: 'Placeholder Description',
      ).copyWith(
        id: 'upload-123',
        status: UploadStatus.readyToPublish,
        cdnUrl: 'https://cdn.example.com/video.mp4',
        videoId: 'video-123',
      );

      // Configure mocks
      when(() => mockUploadManager.getUploadByFilePath('/path/to/test/video.mp4'))
          .thenReturn(testUpload);
      
      when(() => mockVideoEventPublisher.publishVideoEvent(
        upload: any(named: 'upload'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        hashtags: any(named: 'hashtags'),
      )).thenAnswer((_) async => true);

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [mockNavigatorObserver],
          home: MultiProvider(
            providers: [
              Provider<INostrService>.value(value: mockNostrService),
              ChangeNotifierProvider<UploadManager>.value(value: mockUploadManager),
              Provider<VideoEventPublisher>.value(value: mockVideoEventPublisher),
              ChangeNotifierProvider<ProfileVideosProvider>.value(value: mockProfileVideosProvider),
            ],
            child: VinePreviewScreen(
              videoFile: mockVideoFile,
              isFromGallery: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Enter title and description
      await tester.enterText(find.byType(TextField).first, 'My Custom Title');
      await tester.enterText(find.byType(TextField).last, 'My custom description #test #vine');
      await tester.pumpAndSettle();

      // Tap the publish button
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      // Assert
      // Verify no new upload was started (should use existing)
      verifyNever(() => mockUploadManager.startUpload(
        videoPath: any(named: 'videoPath'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        hashtags: any(named: 'hashtags'),
      ));

      // Verify the existing upload was found by file path
      verify(() => mockUploadManager.getUploadByFilePath('/path/to/test/video.mp4')).called(1);

      // Verify publish was called with custom metadata
      verify(() => mockVideoEventPublisher.publishVideoEvent(
        upload: testUpload,
        title: 'My Custom Title',
        description: 'My custom description #test #vine',
        hashtags: ['test', 'vine'],
      )).called(1);

      // Verify profile refresh was called
      verify(() => mockProfileVideosProvider.refreshVideos()).called(1);
    });

    testWidgets('should handle when no existing upload is found', (WidgetTester tester) async {
      // Arrange
      when(() => mockUploadManager.getUploadByFilePath('/path/to/test/video.mp4'))
          .thenReturn(null); // No existing upload

      when(() => mockUploadManager.startUpload(
        videoPath: any(named: 'videoPath'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        hashtags: any(named: 'hashtags'),
      )).thenAnswer((_) async => 'new-upload-123');

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [mockNavigatorObserver],
          home: MultiProvider(
            providers: [
              Provider<INostrService>.value(value: mockNostrService),
              ChangeNotifierProvider<UploadManager>.value(value: mockUploadManager),
              Provider<VideoEventPublisher>.value(value: mockVideoEventPublisher),
              ChangeNotifierProvider<ProfileVideosProvider>.value(value: mockProfileVideosProvider),
            ],
            child: VinePreviewScreen(
              videoFile: mockVideoFile,
              isFromGallery: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.enterText(find.byType(TextField).first, 'New Upload Title');
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      // Assert
      // Verify a new upload was started since no existing one was found
      verify(() => mockUploadManager.startUpload(
        videoPath: '/path/to/test/video.mp4',
        title: 'New Upload Title',
        description: '',
        hashtags: [],
      )).called(1);
    });

    testWidgets('should handle upload not ready to publish', (WidgetTester tester) async {
      // Arrange
      final uploadingUpload = PendingUpload.create(
        localVideoPath: '/path/to/test/video.mp4',
        nostrPubkey: 'test-pubkey-123',
      ).copyWith(
        id: 'upload-123',
        status: UploadStatus.uploading, // Not ready
        uploadProgress: 0.5,
      );

      when(() => mockUploadManager.getUploadByFilePath('/path/to/test/video.mp4'))
          .thenReturn(uploadingUpload);

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [mockNavigatorObserver],
          home: MultiProvider(
            providers: [
              Provider<INostrService>.value(value: mockNostrService),
              ChangeNotifierProvider<UploadManager>.value(value: mockUploadManager),
              Provider<VideoEventPublisher>.value(value: mockVideoEventPublisher),
              ChangeNotifierProvider<ProfileVideosProvider>.value(value: mockProfileVideosProvider),
            ],
            child: VinePreviewScreen(
              videoFile: mockVideoFile,
              isFromGallery: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      // Assert
      // Verify publish was not called since upload isn't ready
      verifyNever(() => mockVideoEventPublisher.publishVideoEvent(
        upload: any(named: 'upload'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        hashtags: any(named: 'hashtags'),
      ));

      // Should show error message
      expect(find.text('Upload not ready to publish'), findsOneWidget);
    });

    testWidgets('should extract hashtags from description', (WidgetTester tester) async {
      // Arrange
      final testUpload = PendingUpload.create(
        localVideoPath: '/path/to/test/video.mp4',
        nostrPubkey: 'test-pubkey-123',
      ).copyWith(
        id: 'upload-123',
        status: UploadStatus.readyToPublish,
        cdnUrl: 'https://cdn.example.com/video.mp4',
      );

      when(() => mockUploadManager.getUploadByFilePath('/path/to/test/video.mp4'))
          .thenReturn(testUpload);
      
      when(() => mockVideoEventPublisher.publishVideoEvent(
        upload: any(named: 'upload'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        hashtags: any(named: 'hashtags'),
      )).thenAnswer((_) async => true);

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [mockNavigatorObserver],
          home: MultiProvider(
            providers: [
              Provider<INostrService>.value(value: mockNostrService),
              ChangeNotifierProvider<UploadManager>.value(value: mockUploadManager),
              Provider<VideoEventPublisher>.value(value: mockVideoEventPublisher),
              ChangeNotifierProvider<ProfileVideosProvider>.value(value: mockProfileVideosProvider),
            ],
            child: VinePreviewScreen(
              videoFile: mockVideoFile,
              isFromGallery: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Enter description with multiple hashtags
      await tester.enterText(
        find.byType(TextField).last,
        'Check out this #awesome #video with #OpenVine! #nostr #decentralized',
      );
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      // Assert - Verify hashtags were extracted correctly
      final verification = verify(() => mockVideoEventPublisher.publishVideoEvent(
        upload: testUpload,
        title: '',
        description: 'Check out this #awesome #video with #OpenVine! #nostr #decentralized',
        hashtags: captureAny(named: 'hashtags'),
      ));
      
      verification.called(1);
      final capturedHashtags = verification.captured.single as List<String>;
      expect(capturedHashtags, containsAll(['awesome', 'video', 'openvine', 'nostr', 'decentralized']));
    });
  });
}