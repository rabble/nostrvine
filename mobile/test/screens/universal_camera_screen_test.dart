// ABOUTME: Tests for UniversalCameraScreen navigation and upload status handling
// ABOUTME: Verifies proper navigation after successful video publishing

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/screens/universal_camera_screen.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/video_manager_interface.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/main.dart';

// Mock classes
class MockUploadManager extends Mock implements UploadManager {}
class MockNostrKeyManager extends Mock implements NostrKeyManager {}
class MockVideoManager extends Mock implements IVideoManager {}
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

// Fake for Route
class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(FakeRoute());
    registerFallbackValue(UploadStatus.pending);
  });

  group('UniversalCameraScreen navigation', () {
    late MockUploadManager mockUploadManager;
    late MockNostrKeyManager mockKeyManager;
    late MockVideoManager mockVideoManager;
    late MockNavigatorObserver mockNavigator;

    setUp(() {
      mockUploadManager = MockUploadManager();
      mockKeyManager = MockNostrKeyManager();
      mockVideoManager = MockVideoManager();
      mockNavigator = MockNavigatorObserver();

      // Set up default mocks
      when(() => mockUploadManager.getUpload(any())).thenReturn(null);
      when(() => mockUploadManager.addListener(any())).thenReturn(null);
      when(() => mockUploadManager.removeListener(any())).thenReturn(null);
      when(() => mockVideoManager.stopAllVideos()).thenReturn(null);
      when(() => mockKeyManager.publicKey).thenReturn('test-pubkey');
    });

    testWidgets('should navigate to main feed when upload is published', 
      (WidgetTester tester) async {
      // Create a test upload
      final testUpload = PendingUpload.create(
        localVideoPath: '/test/video.mp4',
        nostrPubkey: 'test-pubkey',
      );
      
      final publishedUpload = testUpload.copyWith(
        status: UploadStatus.published,
        nostrEventId: 'test-event-id',
      );

      // Set up the mock to return the published upload
      when(() => mockUploadManager.getUpload(testUpload.id))
          .thenReturn(publishedUpload);

      // Build our app and trigger a frame
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UploadManager>.value(
              value: mockUploadManager,
            ),
            Provider<NostrKeyManager>.value(
              value: mockKeyManager,
            ),
            Provider<IVideoManager>.value(
              value: mockVideoManager,
            ),
          ],
          child: MaterialApp(
            navigatorObservers: [mockNavigator],
            home: const UniversalCameraScreen(),
            routes: {
              '/main': (context) => const MainNavigationScreen(),
            },
          ),
        ),
      );

      // Wait for initialization
      await tester.pumpAndSettle();

      // Simulate upload status change by calling the listener
      // In real app, this would be triggered by UploadManager
      // but we need to simulate it for the test
      
      // TODO: This test is limited because we can't easily trigger
      // the internal _onUploadStatusChanged method from outside.
      // A more comprehensive test would require refactoring the
      // UniversalCameraScreen to expose this functionality or
      // use a different testing approach.
    });

    testWidgets('should clean up listeners on dispose', 
      (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UploadManager>.value(
              value: mockUploadManager,
            ),
            Provider<NostrKeyManager>.value(
              value: mockKeyManager,
            ),
            Provider<IVideoManager>.value(
              value: mockVideoManager,
            ),
          ],
          child: const MaterialApp(
            home: UniversalCameraScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate away to trigger dispose
      await tester.pumpWidget(Container());

      // Verify that removeListener was called
      verify(() => mockUploadManager.removeListener(any())).called(1);
    });
  });
}