import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sets up the test environment with necessary platform channel mocks.
void setUpTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();
}

/// Creates a temporary directory for testing and returns its path.
Future<Directory> createTestCacheDirectory(String name) async {
  final tempDir = Directory.systemTemp.createTempSync('media_cache_test_');
  final cacheDir = Directory('${tempDir.path}/$name');
  if (!cacheDir.existsSync()) {
    cacheDir.createSync(recursive: true);
  }
  return cacheDir;
}

/// Cleans up a test directory.
Future<void> cleanupTestDirectory(Directory dir) async {
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}

late Directory _testTempDir;
late Directory _testSupportDir;

/// Gets the test temporary directory path.
String get testTempPath => _testTempDir.path;

/// Gets the test support directory path.
String get testSupportPath => _testSupportDir.path;

/// Sets up test directories that will be used by the mocked path_provider.
Future<void> setUpTestDirectories() async {
  _testTempDir = Directory.systemTemp.createTempSync('media_cache_temp_');
  _testSupportDir = Directory.systemTemp.createTempSync('media_cache_support_');
}

/// Cleans up test directories.
Future<void> tearDownTestDirectories() async {
  if (_testTempDir.existsSync()) {
    _testTempDir.deleteSync(recursive: true);
  }
  if (_testSupportDir.existsSync()) {
    _testSupportDir.deleteSync(recursive: true);
  }
}

void _setupPathProviderMock() {
  const pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (
        methodCall,
      ) async {
        switch (methodCall.method) {
          case 'getTemporaryDirectory':
            return _testTempDir.path;
          case 'getApplicationDocumentsDirectory':
            return '${_testTempDir.path}/documents';
          case 'getApplicationSupportDirectory':
            return _testSupportDir.path;
          default:
            return null;
        }
      });
}

/// Creates a test file with the given content.
Future<File> createTestFile(
  Directory dir,
  String filename, {
  String content = 'test content',
}) async {
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);
  return file;
}
