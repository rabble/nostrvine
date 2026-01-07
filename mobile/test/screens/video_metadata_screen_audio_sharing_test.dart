// ABOUTME: Tests for per-video audio sharing toggle in VideoMetadataScreenPure
// ABOUTME: Verifies toggle displays, defaults from global setting, and can be overridden

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:models/models.dart' as vine_aspect_ratio show AspectRatio;
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'video_metadata_screen_audio_sharing_test.mocks.dart';

@GenerateMocks([UploadManager, AuthService, AudioSharingPreferenceService])
void main() {
  group('VideoMetadataScreenPure - Audio Sharing Toggle', () {
    late MockUploadManager mockUploadManager;
    late MockAuthService mockAuthService;
    late MockAudioSharingPreferenceService mockAudioSharingService;
    late DraftStorageService draftStorage;
    late VineDraft testDraft;
    late File testVideoFile;

    setUp(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      draftStorage = DraftStorageService(prefs);

      mockUploadManager = MockUploadManager();
      when(mockUploadManager.isInitialized).thenReturn(true);

      mockAuthService = MockAuthService();
      when(mockAuthService.currentPublicKeyHex).thenReturn('test-pubkey');
      when(mockAuthService.isAuthenticated).thenReturn(true);

      mockAudioSharingService = MockAudioSharingPreferenceService();
      when(mockAudioSharingService.isAudioSharingEnabled).thenReturn(false);

      // Create a temporary test video file
      final tempDir = Directory.systemTemp.createTempSync('test_video_audio');
      testVideoFile = File('${tempDir.path}/test_video.mp4');
      await testVideoFile.writeAsBytes([0, 1, 2, 3, 4]); // Dummy video data

      // Create test draft using factory method
      testDraft = VineDraft.create(
        videoFile: testVideoFile,
        title: 'Test Video',
        description: 'Test Description',
        hashtags: ['test'],
        frameCount: 30,
        selectedApproach: 'image_stream',
        aspectRatio: vine_aspect_ratio.AspectRatio.square,
      );

      // Save draft to storage
      await draftStorage.saveDraft(testDraft);

      // Setup mock for background upload
      final mockUpload = PendingUpload.create(
        localVideoPath: testVideoFile.path,
        nostrPubkey: 'test-pubkey',
        title: testDraft.title,
        description: testDraft.description,
        hashtags: testDraft.hashtags,
      );

      when(
        mockUploadManager.startUploadFromDraft(
          draft: anyNamed('draft'),
          nostrPubkey: anyNamed('nostrPubkey'),
          videoDuration: anyNamed('videoDuration'),
        ),
      ).thenAnswer((_) async => mockUpload);
    });

    tearDown(() {
      // Clean up test files
      if (testVideoFile.existsSync()) {
        testVideoFile.parent.deleteSync(recursive: true);
      }
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          uploadManagerProvider.overrideWithValue(mockUploadManager),
          authServiceProvider.overrideWithValue(mockAuthService),
          audioSharingPreferenceServiceProvider.overrideWithValue(
            mockAudioSharingService,
          ),
        ],
        child: MaterialApp(
          theme: VineTheme.theme,
          home: VideoMetadataScreenPure(draftId: testDraft.id),
        ),
      );
    }

    testWidgets('displays audio sharing toggle after draft loads', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      // Allow async operations to complete
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Should find the toggle
      expect(find.text('Allow others to use this audio'), findsOneWidget);
    });

    testWidgets('toggle defaults to global preference (OFF)', (tester) async {
      when(mockAudioSharingService.isAudioSharingEnabled).thenReturn(false);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Find the SwitchListTile and verify it's OFF
      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data == 'Allow others to use this audio' &&
            widget.value == false,
      );
      expect(switchFinder, findsOneWidget);

      // Check subtitle text for OFF state
      expect(find.text('Audio is exclusive to this video'), findsOneWidget);
    });

    testWidgets('toggle defaults to global preference (ON)', (tester) async {
      when(mockAudioSharingService.isAudioSharingEnabled).thenReturn(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Find the SwitchListTile and verify it's ON
      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data == 'Allow others to use this audio' &&
            widget.value == true,
      );
      expect(switchFinder, findsOneWidget);

      // Check subtitle text for ON state
      expect(
        find.text('Others can reuse audio from this video'),
        findsOneWidget,
      );
    });

    testWidgets('tapping toggle changes state from OFF to ON', (tester) async {
      when(mockAudioSharingService.isAudioSharingEnabled).thenReturn(false);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Scroll down to make the audio sharing toggle visible
      await tester.scrollUntilVisible(
        find.text('Allow others to use this audio'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Find and tap the switch
      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data == 'Allow others to use this audio',
      );
      await tester.tap(switchFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the toggle is now ON
      final onSwitchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data == 'Allow others to use this audio' &&
            widget.value == true,
      );
      expect(onSwitchFinder, findsOneWidget);

      // Check subtitle text changed
      expect(
        find.text('Others can reuse audio from this video'),
        findsOneWidget,
      );
    });

    testWidgets('tapping toggle changes state from ON to OFF', (tester) async {
      when(mockAudioSharingService.isAudioSharingEnabled).thenReturn(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Scroll down to make the audio sharing toggle visible
      await tester.scrollUntilVisible(
        find.text('Allow others to use this audio'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Find and tap the switch
      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data == 'Allow others to use this audio',
      );
      await tester.tap(switchFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the toggle is now OFF
      final offSwitchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data == 'Allow others to use this audio' &&
            widget.value == false,
      );
      expect(offSwitchFinder, findsOneWidget);

      // Check subtitle text changed
      expect(find.text('Audio is exclusive to this video'), findsOneWidget);
    });

    testWidgets('toggle uses VineTheme green for active thumb', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Find the switch and verify it uses vineGreen for active thumb
      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data == 'Allow others to use this audio' &&
            widget.activeThumbColor == VineTheme.vineGreen,
      );
      expect(switchFinder, findsOneWidget);
    });

    testWidgets('toggle has music note icon', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Find the music note icon
      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });
  });
}
