// ABOUTME: Cross-platform IO abstraction to handle web vs native differences
// ABOUTME: Provides stubs for IO operations that aren't available on web platform

import 'package:flutter/foundation.dart';

// Platform stub for web platform
class Platform {
  static String get version => 'web';
  static String get operatingSystem => 'web';
  static String get operatingSystemVersion => 'web';
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isFuchsia => false;
}

// File stub for web platform
class File {
  File(this.path);

  final String path;

  bool existsSync() => false;

  Future<bool> exists() async => false;

  Future<Uint8List> readAsBytes() async => Uint8List(0);

  Uint8List readAsBytesSync() => Uint8List(0);

  Future<String> readAsString() async => '';

  String readAsStringSync() => '';

  Future<File> writeAsBytes(List<int> bytes, {bool flush = false}) async =>
      this;

  Future<File> writeAsString(String contents) async => this;

  Future<File> copy(String newPath) async => File(newPath);

  Future<void> delete({bool recursive = false}) async {}

  void deleteSync({bool recursive = false}) {}

  int lengthSync() => 0;

  Future<int> length() async => 0;

  Uri get uri => Uri.file(path);

  String get absolute => path;

  Future<DateTime> lastModified() async => DateTime.now();
}

// Directory stub for web platform
class Directory {
  Directory(this.path);

  final String path;

  bool existsSync() => false;

  Future<bool> exists() async => false;

  Future<Directory> create({bool recursive = false}) async => this;

  void createSync({bool recursive = false}) {}

  Future<List<FileSystemEntity>> list({
    bool recursive = false,
    bool followLinks = true,
  }) async => [];

  Stream<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) => const Stream.empty();

  // Mirrors `dart:io`'s `Directory.systemTemp`, which is a static getter. This
  // stub has to keep the same shape for the conditional import to line up.
  // ignore: prefer_constructors_over_static_methods
  static Directory get systemTemp => Directory('/tmp');
}

// FileSystemEntity stub for web platform
class FileSystemEntity {
  String get path => '';

  Future<bool> exists() async => false;

  bool existsSync() => false;
}

// FileSystemException stub for web platform
class FileSystemException implements Exception {
  FileSystemException([this.message = '', this.path, this.osError]);

  final String message;
  final String? path;
  final OSError? osError;

  @override
  String toString() => 'FileSystemException: $message, path = $path';
}

// PathNotFoundException stub for web platform
class PathNotFoundException extends FileSystemException {
  PathNotFoundException(super.message, [super.path, super.osError]);
}

// SocketException stub for web platform. Web has no dart:io sockets, so this
// is never thrown or instantiated — it exists so `is SocketException` checks
// compile for web and correctly evaluate to false.
class SocketException implements Exception {
  SocketException(this.message, {this.osError});

  final String message;
  final OSError? osError;

  @override
  String toString() => 'SocketException: $message';
}

// HttpException stub for web platform. Web has no dart:io HTTP client, so this
// is never thrown or instantiated — it exists so `is HttpException` checks
// compile for web and correctly evaluate to false. `toString()` mirrors
// `dart:io`'s, which appends the uri only when one was supplied.
class HttpException implements Exception {
  const HttpException(this.message, {this.uri});

  final String message;
  final Uri? uri;

  @override
  String toString() {
    final buffer = StringBuffer('HttpException: ')..write(message);
    final uri = this.uri;
    if (uri != null) {
      buffer.write(', uri = $uri');
    }
    return buffer.toString();
  }
}

// Process stub for web platform
class Process {
  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  }) async => ProcessResult(0, 1, '', 'Not supported on web');
}

// ProcessResult stub for web platform
class ProcessResult {
  ProcessResult(this.pid, this.exitCode, this.stdout, this.stderr);

  final int pid;
  final int exitCode;
  final dynamic stdout;
  final dynamic stderr;
}

// ProcessInfo stub for web platform
class ProcessInfo {
  static int get currentRss => 0;
  static int get maxRss => 0;
}

// HttpClient stub for web platform
class HttpClient {
  Duration? connectionTimeout;
  Duration? idleTimeout;

  Future<HttpClientRequest> getUrl(Uri url) =>
      throw UnsupportedError('HttpClient not supported on web');

  void close({bool force = false}) {}
}

// HttpClientRequest stub for web platform
abstract class HttpClientRequest {}

// Socket stub for web platform
abstract class Socket {
  static Future<Socket> connect(dynamic host, int port) =>
      throw UnsupportedError('Socket not supported on web');
}

// Link stub for web platform
class Link {
  Link(this.path);

  final String path;

  Future<Link> create(String target, {bool recursive = false}) async => this;

  bool existsSync() => false;
}

// exit stub for web platform
Never exit(int code) => throw UnsupportedError('exit() not supported on web');

// OSError stub (needed by FileSystemException)
class OSError {
  const OSError([this.message = '', this.errorCode = 0]);

  final String message;
  final int errorCode;
}
