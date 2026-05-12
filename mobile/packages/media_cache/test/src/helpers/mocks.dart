import 'dart:async';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// A mock [sqflite.Database] for testing.
class MockDatabase extends Mock implements sqflite.Database {}

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
    super.tempDirectoryProvider,
    super.repoOverride,
    super.downloaderOverride,
    this.mockGetFileFromCache,
    this.mockDownloadFile,
    this.mockRemoveFile,
    this.mockEmptyCache,
    this.mockGetFileStream,
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

  /// Mock function for [getFileStream].
  final Stream<FileResponse> Function(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress,
  })?
  mockGetFileStream;

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

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    if (mockGetFileStream != null) {
      return mockGetFileStream!(
        url,
        key: key,
        headers: headers,
        withProgress: withProgress,
      );
    }
    return super.getFileStream(
      url,
      key: key,
      headers: headers,
      withProgress: withProgress,
    );
  }
}

/// A controllable [CancellableDownload] for tests.
///
/// The [file] future stays pending until tests call [completeWith] (with a
/// real file to simulate a successful download), [completeNull] (to simulate
/// a stream that closed without a result), or [cancel] (to simulate the
/// caller aborting). [targetFile] and [headers] expose what the manager
/// passed to the downloader so tests can assert on them.
class FakeCancellableDownload implements CancellableDownload {
  FakeCancellableDownload({
    required this.url,
    required this.targetFile,
    required this.headers,
  });

  final String url;
  final io.File targetFile;
  final Map<String, String>? headers;

  final _completer = Completer<io.File?>();
  bool _isCancelled = false;

  @override
  Future<io.File?> get file => _completer.future;

  @override
  bool get isCancelled => _isCancelled;

  @override
  void cancel() {
    if (_isCancelled || _completer.isCompleted) return;
    _isCancelled = true;
    _completer.complete();
  }

  /// Completes the download with [file] (typically a pre-created test file).
  void completeWith(io.File file) {
    if (_completer.isCompleted) return;
    _completer.complete(file);
  }

  /// Completes the download with `null` (failure / no body).
  void completeNull() {
    if (_completer.isCompleted) return;
    _completer.complete();
  }
}

/// Records every [download] call and returns a controllable
/// [FakeCancellableDownload] that tests drive via the [downloads] list.
class FakeCancellableDownloader implements CancellableDownloader {
  /// All downloads issued via this fake, in order.
  final List<FakeCancellableDownload> downloads = [];

  /// Whether [close] was called.
  bool closed = false;

  @override
  CancellableDownload download({
    required String url,
    required io.File targetFile,
    Map<String, String>? headers,
  }) {
    final dl = FakeCancellableDownload(
      url: url,
      targetFile: targetFile,
      headers: headers,
    );
    downloads.add(dl);
    return dl;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
