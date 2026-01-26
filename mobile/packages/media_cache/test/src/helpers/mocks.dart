import 'package:file/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

/// A mock [FileInfo] for testing.
class MockFileInfo extends Mock implements FileInfo {}

/// A mock [File] for testing.
/// Uses File from the `file` package (used by flutter_cache_manager).
class MockFile extends Mock implements File {}

/// A mock [CacheInfoRepository] for testing [SafeCacheInfoRepository].
class MockCacheInfoRepository extends Mock implements CacheInfoRepository {}

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
