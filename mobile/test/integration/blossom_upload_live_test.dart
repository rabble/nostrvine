// ABOUTME: Live integration test for Blossom uploads using real staging server
// ABOUTME: Tests actual authentication and file upload with real Nostr keys

import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/service_init_helper.dart';

class _BlossomAuthAdapter implements BlossomAuthProvider {
  _BlossomAuthAdapter(this._authService);
  final AuthService _authService;

  @override
  bool get isAuthenticated => _authService.isAuthenticated;

  @override
  Future<BlossomSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
  }) async {
    final event = await _authService.createAndSignEvent(
      kind: kind,
      content: content,
      tags: tags,
    );
    if (event == null) return null;
    return BlossomSignedEvent(json: event.toJson());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Blossom Upload Live Integration', () {
    late BlossomUploadService blossomService;
    late AuthService authService;
    late File testVideoFile;

    const stagingServer =
        'https://cf-stream-service-staging.protestnet.workers.dev';
    const prodServer = 'https://cf-stream-service-prod.protestnet.workers.dev';

    setUpAll(() async {
      // Initialize test environment first
      ServiceInitHelper.initializeTestEnvironment();

      // Create a real test video file
      testVideoFile = File('/tmp/test_blossom_upload.mp4');

      // Create a minimal valid MP4 file (just for testing)
      final testVideoData = Uint8List.fromList([
        // MP4 file signature and minimal header
        0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70,
        0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
        0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31,
        // Add some more data to make it a reasonable size
        ...List.filled(1000, 0x00),
      ]);

      await testVideoFile.writeAsBytes(testVideoData);

      // Create real services for live testing using the factory pattern
      // Generate a test key container for live testing
      final keyContainer = await SecureKeyContainer.generate();
      print('Generated test keys: ${keyContainer.publicKeyHex}...');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final keyStorage = SecureKeyStorage();
      authService = AuthService(
        userDataCleanupService: UserDataCleanupService(prefs),
        keyStorage: keyStorage,
      );
      await authService.initialize();

      blossomService = BlossomUploadService(
        authProvider: _BlossomAuthAdapter(authService),
      );

      // Configure to use staging server
      await blossomService.setBlossomServer(stagingServer);
      await blossomService.setBlossomEnabled(true);
    });

    tearDownAll(() async {
      // Clean up test file
      if (testVideoFile.existsSync()) {
        await testVideoFile.delete();
      }
    });

    test('should successfully upload to staging server', () async {
      // Skip if we don't have real keys
      if (!authService.isAuthenticated) {
        markTestSkipped('No authenticated user available for live test');
        return;
      }

      print('🔄 Testing upload to staging server: $stagingServer');
      print('📁 Test file size: ${await testVideoFile.length()} bytes');
      print('👤 Using pubkey: ${authService.currentPublicKeyHex}...');

      final result = await blossomService.uploadVideo(
        videoFile: testVideoFile,
        nostrPubkey: authService.currentPublicKeyHex!,
        title: 'Blossom Integration Test',
        description: 'Test upload from Flutter integration test',
        hashtags: ['test', 'integration'],
        proofManifestJson: null,
        onProgress: (progress) {
          print('📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      print('✅ Upload result: success=${result.success}');
      if (result.success) {
        print('📍 CDN URL: ${result.cdnUrl}');
        print('🆔 Video ID: ${result.videoId}');
      } else {
        print('❌ Error: ${result.errorMessage}');
      }

      // Assert successful upload
      expect(
        result.success,
        isTrue,
        reason: 'Upload should succeed: ${result.errorMessage}',
      );
      expect(result.cdnUrl, isNotNull, reason: 'Should return CDN URL');
      expect(result.videoId, isNotNull, reason: 'Should return video ID');
      expect(
        result.cdnUrl,
        contains(result.videoId),
        reason: 'CDN URL should contain video ID',
      );
    });

    test(
      'should handle authentication with proper Blossom kind 24242 event',
      () async {
        if (!authService.isAuthenticated) {
          markTestSkipped('No authenticated user available for live test');
          return;
        }

        print('🔐 Testing Blossom authentication (kind 24242)');

        // This test verifies that our fixed authentication works
        final result = await blossomService.uploadVideo(
          videoFile: testVideoFile,
          nostrPubkey: authService.currentPublicKeyHex!,
          title: 'Auth Test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Should not get "unauthorized" error anymore
        expect(
          result.errorMessage?.toLowerCase(),
          isNot(contains('unauthorized')),
          reason: 'Should not get unauthorized error with proper Blossom auth',
        );

        if (!result.success) {
          print('❌ Upload failed: ${result.errorMessage}');
          // Print more details for debugging
          print('🔍 Auth status: ${authService.isAuthenticated}');
          print('🔍 Current pubkey: ${authService.currentPublicKeyHex}...');
          print('🔍 Server: ${await blossomService.getBlossomServer()}');
          print('🔍 Enabled: ${await blossomService.isBlossomEnabled()}');
        }
      },
    );

    test('should work with production server as fallback', () async {
      if (!authService.isAuthenticated) {
        markTestSkipped('No authenticated user available for live test');
        return;
      }

      print('🔄 Testing fallback to production server: $prodServer');

      // Switch to production server
      await blossomService.setBlossomServer(prodServer);

      final result = await blossomService.uploadVideo(
        videoFile: testVideoFile,
        nostrPubkey: authService.currentPublicKeyHex!,
        title: 'Production Fallback Test',
        description: null,
        hashtags: null,
        proofManifestJson: null,
      );

      if (result.success) {
        print('✅ Production server upload successful');
        print('📍 CDN URL: ${result.cdnUrl}');
      } else {
        print('❌ Production server upload failed: ${result.errorMessage}');
      }

      // Don't require success since prod might have different restrictions
      // Just verify we're not getting auth errors
      expect(
        result.errorMessage?.toLowerCase(),
        isNot(contains('unauthorized')),
        reason: 'Should not get unauthorized error with proper Blossom auth',
      );
    });
  });
}
