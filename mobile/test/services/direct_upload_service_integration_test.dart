// ABOUTME: Complete end-to-end integration test for DirectUploadService
// ABOUTME: Tests real video upload flow with NIP-98 auth and backend communication

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/services/direct_upload_service.dart';
import 'package:nostrvine_app/services/nip98_auth_service.dart';
import 'package:nostrvine_app/services/auth_service.dart';
import 'package:nostrvine_app/config/app_config.dart';
import 'package:nostrvine_app/services/key_storage_service.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostrvine_app/utils/nostr_encoding.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

void main() {
  group('DirectUploadService Integration', () {
    late Directory tempDir;
    late File testVideoFile;
    
    setUpAll(() async {
      // Create temporary directory for test files
      tempDir = await Directory.systemTemp.createTemp('nostrvine_test_');
      
      // Use existing video file instead of creating a minimal one
      final existingVideoPath = path.join(
        Directory.current.path, 
        'assets', 
        'videos', 
        'default_intro.mp4'
      );
      
      final existingVideo = File(existingVideoPath);
      if (await existingVideo.exists()) {
        // Copy existing video to temp directory for testing
        testVideoFile = File(path.join(tempDir.path, 'test_video.mp4'));
        await existingVideo.copy(testVideoFile.path);
        final fileSize = await testVideoFile.length();
        print('📁 Using existing video file: ${testVideoFile.path} (${fileSize} bytes)');
      } else {
        // Fallback: create a minimal test MP4 file
        testVideoFile = File(path.join(tempDir.path, 'test_video.mp4'));
        final mp4Data = _createMinimalMp4Data();
        await testVideoFile.writeAsBytes(mp4Data);
        print('📁 Created minimal test video file: ${testVideoFile.path} (${mp4Data.length} bytes)');
      }
    });
    
    tearDownAll(() async {
      // Clean up test files
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        print('🧹 Cleaned up test directory: ${tempDir.path}');
      }
    });

    test('should use correct backend URL configuration', () {
      // Test that our configuration changes are correct
      expect(AppConfig.backendBaseUrl, equals('https://api.openvine.co'));
      expect(AppConfig.nip96InfoUrl, equals('https://api.openvine.co/.well-known/nostr/nip96.json'));
    });

    test('should initialize without throwing', () {
      // Test service can be created
      final service = DirectUploadService();
      expect(service, isNotNull);
      
      // Test service has no active uploads initially
      expect(service.activeUploads, isEmpty);
    });

    test('upload endpoint URL should be correctly formed', () {
      // This is testing the URL formation logic from the source
      final expectedUrl = '${AppConfig.backendBaseUrl}/api/upload';
      expect(expectedUrl, equals('https://api.openvine.co/api/upload'));
    });

    group('End-to-End Upload Flow', () {
      test('should successfully upload video with NIP-98 auth', () async {
        print('\n🧪 Starting end-to-end upload test...');
        
        // 1. Create test authentication setup using real cryptographic keys
        final keyPair = _generateRealKeyPair();
        print('🔑 Generated test keypair: ${keyPair.publicKeyHex}');
        
        // Create mock auth service that returns our test key
        final authService = TestAuthService(keyPair: keyPair);
        final nip98Service = Nip98AuthService(authService: authService);
        
        // 2. Create upload service with authentication
        final uploadService = DirectUploadService(authService: nip98Service);
        
        // 3. Track upload progress
        final progressEvents = <double>[];
        
        // 4. Perform the upload
        print('📤 Starting upload of test video...');
        final result = await uploadService.uploadVideo(
          videoFile: testVideoFile,
          nostrPubkey: keyPair.publicKeyHex,
          title: 'Test Video Upload',
          description: 'End-to-end integration test video',
          hashtags: ['test', 'e2e', 'nostrvine'],
          onProgress: (progress) {
            progressEvents.add(progress);
            print('📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
          },
        );
        
        // 5. Verify upload result
        print('📋 Upload result: success=${result.success}');
        if (result.success) {
          print('✅ Upload successful!');
          print('🆔 Video ID: ${result.videoId}');
          print('🔗 CDN URL: ${result.cdnUrl}');
          print('📊 Metadata: ${result.metadata}');
          
          expect(result.success, isTrue);
          expect(result.cdnUrl, isNotNull);
          expect(result.cdnUrl, startsWith('https://'));
          
          // 6. Test file accessibility (if CDN is working)
          if (result.cdnUrl != null) {
            print('🌐 Testing CDN URL accessibility...');
            try {
              final response = await http.head(Uri.parse(result.cdnUrl!));
              print('🌐 CDN response: ${response.statusCode}');
              
              // Note: CDN might return 404 due to the known serving issue,
              // but upload should still be successful
              if (response.statusCode == 200) {
                print('✅ CDN serving is working!');
                expect(response.headers['content-type'], contains('video'));
              } else {
                print('⚠️ CDN serving issue (known): ${response.statusCode}');
                // Don't fail the test for CDN serving issues
              }
            } catch (e) {
              print('⚠️ CDN test failed (acceptable): $e');
              // Don't fail the test for CDN issues
            }
          }
          
          // 7. Verify progress tracking worked
          expect(progressEvents, isNotEmpty);
          expect(progressEvents.first, greaterThanOrEqualTo(0.0));
          expect(progressEvents.last, greaterThanOrEqualTo(0.9)); // Should reach near 100%
          print('📊 Progress events: ${progressEvents.length} updates');
          
        } else {
          print('❌ Upload failed: ${result.errorMessage}');
          fail('Upload should have succeeded, but got error: ${result.errorMessage}');
        }
      }, timeout: const Timeout(Duration(minutes: 2)));
      
      test('should handle upload without authentication', () async {
        print('\n🧪 Testing upload without authentication...');
        
        // Create service without authentication
        final uploadService = DirectUploadService();
        
        // Attempt upload (should fail gracefully)
        final result = await uploadService.uploadVideo(
          videoFile: testVideoFile,
          nostrPubkey: 'test-pubkey',
        );
        
        print('📋 No-auth result: success=${result.success}, error=${result.errorMessage}');
        
        // Should fail but not crash
        expect(result.success, isFalse);
        expect(result.errorMessage, isNotNull);
      });
      
      test('should handle missing file gracefully', () async {
        print('\n🧪 Testing upload with missing file...');
        
        final authService = TestAuthService(keyPair: _generateRealKeyPair());
        final nip98Service = Nip98AuthService(authService: authService);
        final uploadService = DirectUploadService(authService: nip98Service);
        
        // Create reference to non-existent file
        final missingFile = File(path.join(tempDir.path, 'nonexistent.mp4'));
        
        // Attempt upload
        final result = await uploadService.uploadVideo(
          videoFile: missingFile,
          nostrPubkey: 'test-pubkey',
        );
        
        print('📋 Missing file result: success=${result.success}, error=${result.errorMessage}');
        
        // Should fail gracefully
        expect(result.success, isFalse);
        expect(result.errorMessage, isNotNull);
      });
    });
  });
}

/// Generate a real cryptographic key pair using nostr_sdk functions
NostrKeyPair _generateRealKeyPair() {
  // Generate a cryptographically secure private key
  final privateKeyHex = generatePrivateKey();
  
  // Derive the public key using secp256k1
  final publicKeyHex = getPublicKey(privateKeyHex);
  
  // Create bech32 encoded versions
  final npub = NostrEncoding.encodePublicKey(publicKeyHex);
  final nsec = NostrEncoding.encodePrivateKey(privateKeyHex);
  
  return NostrKeyPair(
    privateKeyHex: privateKeyHex,
    publicKeyHex: publicKeyHex,
    npub: npub,
    nsec: nsec,
  );
}

/// Mock AuthService for testing
class TestAuthService extends AuthService {
  final NostrKeyPair keyPair;
  
  TestAuthService({required this.keyPair});
  
  @override
  bool get isAuthenticated => true;
  
  @override
  String? get currentPublicKeyHex => keyPair.publicKeyHex;
  
  @override
  String? get currentNpub => keyPair.npub;
  
  // Return the private key for signing
  @override
  Future<String?> getPrivateKeyForSigning() async => keyPair.privateKeyHex;
  
  // Create and sign events for NIP-98 auth
  @override
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
  }) async {
    if (!isAuthenticated) {
      return null;
    }
    
    try {
      final privateKey = await getPrivateKeyForSigning();
      if (privateKey == null) return null;
      
      // Create event with the public key
      final event = Event(
        keyPair.publicKeyHex,
        kind,
        tags ?? [],
        content,
      );
      
      // Sign the event
      event.sign(privateKey);
      
      return event;
      
    } catch (e) {
      print('❌ TestAuthService failed to create event: $e');
      return null;
    }
  }
}

/// Create a minimal valid MP4 file for testing
Uint8List _createMinimalMp4Data() {
  // Create a minimal MP4 file with basic ftyp and mdat boxes
  final List<int> data = [];
  
  // ftyp box (file type)
  data.addAll([0x00, 0x00, 0x00, 0x20]); // box size (32 bytes)
  data.addAll(utf8.encode('ftyp'));       // box type
  data.addAll(utf8.encode('mp42'));       // major brand
  data.addAll([0x00, 0x00, 0x00, 0x00]); // minor version
  data.addAll(utf8.encode('mp42'));       // compatible brand 1
  data.addAll(utf8.encode('isom'));       // compatible brand 2
  
  // mdat box (media data) - minimal content
  data.addAll([0x00, 0x00, 0x00, 0x10]); // box size (16 bytes)
  data.addAll(utf8.encode('mdat'));       // box type
  data.addAll([0x00, 0x00, 0x00, 0x00]); // placeholder data
  data.addAll([0x00, 0x00, 0x00, 0x00]); // placeholder data
  
  return Uint8List.fromList(data);
}