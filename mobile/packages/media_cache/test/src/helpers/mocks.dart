import 'package:file/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

/// A mock [FileInfo] for testing.
class MockFileInfo extends Mock implements FileInfo {}

/// A mock [File] for testing.
/// Uses File from the `file` package (used by flutter_cache_manager).
class MockFile extends Mock implements File {}

/// A testable version of [MediaCacheManager] that allows overriding
/// parent class methods for testing.
class TestableMediaCacheManager extends MediaCacheManager {
  TestableMediaCacheManager({
    required super.config,
    this.mockGetFileFromCache,
    this.mockDownloadFile,
    this.mockRemoveFile,
    this.mockEmptyCache,
  });

  /// Mock function for [getFileFromCache].
  final Future<FileInfo?> Function(String key)? mockGetFileFromCache;

  /// Mock function for [downloadFile].
  final Future<FileInfo> Function(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
  })?
  mockDownloadFile;

  /// Mock function for [removeFile].
  final Future<void> Function(String key)? mockRemoveFile;

  /// Mock function for [emptyCache].
  final Future<void> Function()? mockEmptyCache;

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) {
    if (mockGetFileFromCache != null) {
      return mockGetFileFromCache!(key);
    }
    return super.getFileFromCache(key, ignoreMemCache: ignoreMemCache);
  }

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) {
    if (mockDownloadFile != null) {
      return mockDownloadFile!(url, key: key, authHeaders: authHeaders);
    }
    return super.downloadFile(url, key: key, authHeaders: authHeaders ?? {});
  }

  @override
  Future<void> removeFile(String key) {
    if (mockRemoveFile != null) {
      return mockRemoveFile!(key);
    }
    return super.removeFile(key);
  }

  @override
  Future<void> emptyCache() {
    if (mockEmptyCache != null) {
      return mockEmptyCache!();
    }
    return super.emptyCache();
  }
}

/// A testable version of [SafeCacheInfoRepository] that can simulate
/// exceptions from the parent class.
class TestableSafeCacheInfoRepository extends SafeCacheInfoRepository {
  TestableSafeCacheInfoRepository({
    required super.databaseName,
    this.shouldThrowFormatException = false,
    this.shouldThrowGenericException = false,
    this.genericExceptionMessage,
  });

  /// If true, simulates [FormatException] from parent.
  final bool shouldThrowFormatException;

  /// If true, simulates a generic [Exception] from parent.
  final bool shouldThrowGenericException;

  /// Custom message for generic exception.
  final String? genericExceptionMessage;

  bool _hasThrown = false;

  @override
  Future<bool> open() async {
    // Only throw once to allow recovery
    if (!_hasThrown) {
      if (shouldThrowFormatException) {
        _hasThrown = true;
        // Simulate recovery from FormatException
        return true;
      }
      if (shouldThrowGenericException) {
        _hasThrown = true;
        final message = genericExceptionMessage ?? 'Unexpected end of input';
        // Simulate recovery from recoverable exceptions
        if (message.contains('Unexpected end of input') ||
            message.contains("type 'Null'")) {
          return true;
        }
        throw Exception(message);
      }
    }
    return super.open();
  }
}
