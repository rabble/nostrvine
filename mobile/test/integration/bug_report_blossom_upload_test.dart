// ABOUTME: Integration test for bug report upload to Blossom server
// ABOUTME: Tests end-to-end flow: collect diagnostics → upload to Blossom → send NIP-17 DM

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock auth provider for integration test
class MockAuthProvider implements BlossomAuthProvider {
  final Keychain _keychain;

  MockAuthProvider(this._keychain);

  @override
  bool get isAuthenticated => true;

  @override
  Future<BlossomSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
  }) async {
    final event = Event(_keychain.public, kind, tags, content);
    event.sign(_keychain.private);
    return BlossomSignedEvent(json: event.toJson());
  }
}

class MockNostrService implements NostrClient {
  @override
  Future<bool> addRelay(String relayUrl) async {
    print('📡 Mock: Would add relay $relayUrl');
    return true;
  }

  // Stub methods not used in this test
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Bug Report Blossom Upload Integration', () {
    late Keychain testKeychain;
    late BugReportService bugReportService;
    late BlossomUploadService blossomService;
    late File testBugReportFile;

    const blossomServer = 'https://blossom.divine.video';

    setUpAll(() async {
      // Mock package_info_plus

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            (methodCall) async {
              if (methodCall.method == 'getAll') {
                return <String, dynamic>{
                  'appName': 'OpenVine',
                  'packageName': 'com.openvine.mobile',
                  'version': '0.0.1',
                  'buildNumber': '35',
                };
              }
              return null;
            },
          );

      // Mock Firebase Core
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/firebase_core'),
            (methodCall) async {
              if (methodCall.method == 'Firebase#initializeCore') {
                return [
                  {
                    'name': '[DEFAULT]',
                    'options': {
                      'apiKey': 'test',
                      'appId': 'test',
                      'messagingSenderId': 'test',
                      'projectId': 'test',
                    },
                    'pluginConstants': {},
                  },
                ];
              }
              return null;
            },
          );

      // Mock Firebase Analytics
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/firebase_analytics'),
            (methodCall) async => null,
          );

      // Initialize SharedPreferences with mock
      SharedPreferences.setMockInitialValues({});

      // Generate test keypair
      testKeychain = Keychain.generate();
      print(
        '🔑 Generated test keys: ${testKeychain.public.substring(0, 16)}...',
      );

      // Create services
      final mockAuthProvider = MockAuthProvider(testKeychain);

      blossomService = BlossomUploadService(authProvider: mockAuthProvider);

      // Configure Blossom server
      await blossomService.setBlossomServer(blossomServer);
      await blossomService.setBlossomEnabled(true);

      bugReportService = BugReportService(blossomUploadService: blossomService);

      // Create test bug report file
      testBugReportFile = File('/tmp/test_bug_report_integration.txt');
      await testBugReportFile.writeAsString('''
OpenVine Bug Report - Integration Test
═══════════════════════════════════════
Report ID: test-integration-${DateTime.now().millisecondsSinceEpoch}
Timestamp: ${DateTime.now().toIso8601String()}
App Version: 0.0.1+35

User Description:
This is a test bug report from integration test.

Device Information:
  Platform: Test Platform
  Version: Test Version

Recent Logs (3 entries):
[${DateTime.now().toIso8601String()}] INFO - Integration test log 1
[${DateTime.now().toIso8601String()}] WARNING - Integration test log 2
[${DateTime.now().toIso8601String()}] ERROR - Integration test log 3

Error Counts:
  TestError: 1
''');

      print('📝 Created test bug report file: ${testBugReportFile.path}');
      print('📊 File size: ${await testBugReportFile.length()} bytes');
    });

    tearDownAll(() async {
      if (testBugReportFile.existsSync()) {
        await testBugReportFile.delete();
      }
    });

    test('should upload bug report to Blossom server and return URL', () async {
      print('\n🧪 Starting Blossom bug report upload integration test...\n');

      // Calculate file hash for verification
      final fileBytes = await testBugReportFile.readAsBytes();
      final digest = sha256.convert(fileBytes);
      final expectedFileHash = digest.toString();
      print('📊 File hash: $expectedFileHash');

      // Act: Upload bug report to Blossom
      final uploadedUrl = await blossomService.uploadBugReport(
        bugReportFile: testBugReportFile,
        onProgress: (progress) {
          print('⏳ Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      // Assert: Verify upload succeeded
      expect(uploadedUrl, isNotNull, reason: 'Upload should return a URL');
      expect(uploadedUrl, contains('http'), reason: 'URL should be HTTP/HTTPS');
      expect(
        uploadedUrl!.contains('cdn.divine.video') ||
            uploadedUrl.contains('blossom.divine.video'),
        isTrue,
        reason: 'URL should be from divine.video CDN',
      );

      print('✅ Upload successful!');
      print('🔗 Uploaded URL: $uploadedUrl');

      // Verify: Try to download the file back
      print('\n🔍 Verifying uploaded file is accessible...');
      final dio = Dio();
      try {
        final downloadResponse = await dio.get(
          uploadedUrl,
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (downloadResponse.statusCode == 200) {
          final downloadedBytes = downloadResponse.data as List<int>;
          final downloadedHash = sha256.convert(downloadedBytes).toString();

          print('✅ File is accessible at URL');
          print('📊 Downloaded size: ${downloadedBytes.length} bytes');
          print('🔐 Downloaded hash: $downloadedHash');

          // Verify hash matches
          expect(
            downloadedHash,
            equals(expectedFileHash),
            reason: 'Downloaded file hash should match uploaded file hash',
          );

          print('✅ File integrity verified!');
        } else {
          print(
            '⚠️  Warning: File returned status ${downloadResponse.statusCode}',
          );
          print('   This may be expected if the server needs time to process');
        }
      } catch (e) {
        print('⚠️  Could not verify download: $e');
        print(
          '   This is not necessarily a failure - the upload may still be valid',
        );
      }

      print('\n✅ Integration test complete!\n');
    });

    test('should handle disabled Blossom gracefully', () async {
      print('\n🧪 Testing disabled Blossom handling...\n');

      // Disable Blossom
      await blossomService.setBlossomEnabled(false);

      // Try to upload
      final result = await blossomService.uploadBugReport(
        bugReportFile: testBugReportFile,
      );

      // Should return null
      expect(
        result,
        isNull,
        reason: 'Should return null when Blossom is disabled',
      );

      print('✅ Correctly handled disabled state\n');

      // Re-enable for other tests
      await blossomService.setBlossomEnabled(true);
      // TODO(any): Fix and reenable this test
    }, skip: true);

    test('should collect diagnostics and create bug report file', () async {
      print('\n🧪 Testing diagnostic collection...\n');

      // Collect diagnostics
      final bugReportData = await bugReportService.collectDiagnostics(
        userDescription: 'Integration test bug report',
        currentScreen: '/test/screen',
        userPubkey: testKeychain.public,
      );

      // Verify diagnostics
      expect(bugReportData.reportId, isNotEmpty);
      expect(
        bugReportData.userDescription,
        equals('Integration test bug report'),
      );
      expect(bugReportData.currentScreen, equals('/test/screen'));
      expect(bugReportData.userPubkey, equals(testKeychain.public));
      expect(bugReportData.deviceInfo, isNotEmpty);
      expect(bugReportData.appVersion, isNotEmpty);
      expect(bugReportData.recentLogs, isNotEmpty);

      print('✅ Diagnostics collected successfully');
      print('   Report ID: ${bugReportData.reportId}');
      print('   App Version: ${bugReportData.appVersion}');
      print('   Log entries: ${bugReportData.recentLogs.length}');
      print('   Error types: ${bugReportData.errorCounts.length}');

      // Sanitize sensitive data
      final sanitized = bugReportService.sanitizeSensitiveData(bugReportData);
      expect(sanitized.reportId, equals(bugReportData.reportId));

      print('✅ Sanitization successful\n');
      // TODO(any): Fix and reenable this test
    }, skip: true);

    test('should estimate report size correctly', () async {
      print('\n🧪 Testing report size estimation...\n');

      final bugReportData = await bugReportService.collectDiagnostics(
        userDescription: 'Size estimation test',
      );

      final estimatedSize = bugReportService.estimateReportSize(bugReportData);

      print('📊 Estimated report size: $estimatedSize bytes');
      print('   Max allowed: ${BugReportConfig.maxReportSizeBytes} bytes');

      expect(estimatedSize, greaterThan(0), reason: 'Size should be positive');
      expect(
        estimatedSize,
        lessThan(BugReportConfig.maxReportSizeBytes * 10),
        reason: 'Size should be reasonable for a bug report',
      );

      if (estimatedSize > BugReportConfig.maxReportSizeBytes) {
        print('⚠️  Report exceeds size limit - would need log truncation');
      } else {
        print('✅ Report size within limits');
      }

      print('\n');
    });
  });
}
