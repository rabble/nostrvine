// ABOUTME: Service for capturing log entries for bug reports — in-memory
// ABOUTME: ring buffer plus opt-in on-disk session files so exports cover
// ABOUTME: previous app sessions.

import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:models/models.dart' show LogEntry, LogLevel;

/// Service for capturing and storing log entries for bug reports.
///
/// Always maintains an in-memory ring buffer (fast path, no I/O). When
/// [enablePersistence] is called with a directory, entries are additionally
/// appended to per-session log files so exports cover previous app
/// sessions — user reports like "this happened yesterday morning" are
/// undiagnosable from a memory-only buffer that dies with the process.
class LogCaptureService {
  /// Returns the singleton [LogCaptureService] instance.
  factory LogCaptureService() => _instance ??= LogCaptureService._();

  LogCaptureService._();

  static LogCaptureService? _instance;

  /// In-memory ring buffer for logs
  final Queue<LogEntry> _memoryBuffer = Queue<LogEntry>();

  /// Maximum memory buffer size (50k entries ~5-10MB).
  static const int _memoryBufferSize = 50000;

  /// Default retention window for persisted session files.
  static const Duration defaultMaxFileAge = Duration(hours: 72);

  /// Default cap on the summed size of all persisted session files.
  static const int defaultMaxTotalBytes = 24 * 1024 * 1024;

  /// Default size at which the current session file rolls to a new part.
  static const int defaultMaxBytesPerFile = 4 * 1024 * 1024;

  /// Default number of pending lines that triggers a disk flush.
  static const int defaultFlushThreshold = 64;

  /// Persistence disables itself after this many consecutive write
  /// failures (e.g. disk full) instead of retrying forever.
  static const int _maxConsecutiveWriteFailures = 3;

  static const String _fileSuffix = '.log';
  static const String _filePrefix = 'divine_logs_';

  /// Total entries captured in current session
  int _totalEntriesWritten = 0;

  Directory? _persistDirectory;
  Duration _maxFileAge = defaultMaxFileAge;
  int _maxTotalBytes = defaultMaxTotalBytes;
  int _maxBytesPerFile = defaultMaxBytesPerFile;
  int _flushThreshold = defaultFlushThreshold;

  int _sessionStartMillis = 0;
  int _sessionFileSeq = 0;
  int _currentFileBytes = 0;
  int _consecutiveWriteFailures = 0;

  final List<String> _pendingLines = <String>[];

  /// Serializes file appends so chunks never interleave.
  Future<void> _writeChain = Future<void>.value();

  /// Whether entries are currently being persisted to disk.
  bool get isPersistenceEnabled => _persistDirectory != null;

  /// Format a log entry as a text line
  String _formatLogEntry(LogEntry entry) {
    final timestamp = entry.timestamp.toIso8601String();
    final level = entry.level.toString().split('.').last.toUpperCase();
    final category = entry.category?.toString().split('.').last ?? 'GENERAL';
    final name = entry.name ?? '';

    final buffer = StringBuffer()..write('[$timestamp] [$level] ');
    if (name.isNotEmpty) {
      buffer.write('[$name] ');
    }
    buffer.write('$category: ${entry.message}');

    if (entry.error != null) {
      buffer.write(' | Error: ${entry.error}');
    }

    if (entry.stackTrace != null) {
      buffer.write(
        ' | Stack: ${entry.stackTrace.toString().split('\n').first}',
      );
    }

    return buffer.toString();
  }

  /// Capture a log entry to memory buffer (ring buffer)
  void captureLog(LogEntry entry) {
    // Add to memory buffer (maintain max size as ring buffer)
    if (_memoryBuffer.length >= _memoryBufferSize) {
      _memoryBuffer.removeFirst();
    }
    _memoryBuffer.add(entry);
    _totalEntriesWritten++;

    if (_persistDirectory != null) {
      _pendingLines.add(_formatLogEntry(entry));
      // Warnings/errors flush immediately: they are rare, they are the
      // lines support actually needs, and an app killed in the background
      // must not lose them to the batch window.
      if (_pendingLines.length >= _flushThreshold ||
          entry.level.value >= LogLevel.warning.value) {
        _scheduleFlush();
      }
    }
  }

  /// Enables cross-session persistence of captured logs.
  ///
  /// Creates [directoryPath] if needed, prunes session files older than
  /// [maxFileAge] and beyond [maxTotalBytes] (oldest first), then starts a
  /// new session file seeded with everything already in the memory buffer,
  /// so startup lines logged before this call are not lost.
  ///
  /// Not supported on web (uses `dart:io`); callers guard with `kIsWeb`.
  Future<void> enablePersistence({
    required String directoryPath,
    Duration maxFileAge = defaultMaxFileAge,
    int maxTotalBytes = defaultMaxTotalBytes,
    int maxBytesPerFile = defaultMaxBytesPerFile,
    int flushThreshold = defaultFlushThreshold,
  }) async {
    await disablePersistence();

    final directory = Directory(directoryPath);
    await directory.create(recursive: true);

    _maxFileAge = maxFileAge;
    _maxTotalBytes = maxTotalBytes;
    _maxBytesPerFile = maxBytesPerFile;
    _flushThreshold = flushThreshold;
    _sessionStartMillis = DateTime.now().millisecondsSinceEpoch;
    _sessionFileSeq = 0;
    _currentFileBytes = 0;
    _consecutiveWriteFailures = 0;

    await _pruneOldFiles(directory);

    _persistDirectory = directory;

    // Seed the session file with lines captured before persistence was
    // wired (startup runs for a while before the deferred phase).
    _pendingLines.insertAll(0, _memoryBuffer.map(_formatLogEntry));
    if (_pendingLines.isNotEmpty) {
      _scheduleFlush();
    }
    await _writeChain;
  }

  /// Stops persisting, after flushing pending lines. Memory capture
  /// continues unchanged. Existing session files stay on disk.
  Future<void> disablePersistence() async {
    if (_persistDirectory == null) return;
    await flush();
    _persistDirectory = null;
    _pendingLines.clear();
  }

  /// Writes all pending lines to the current session file.
  Future<void> flush() {
    if (_persistDirectory != null && _pendingLines.isNotEmpty) {
      _scheduleFlush();
    }
    return _writeChain;
  }

  void _scheduleFlush() {
    final directory = _persistDirectory;
    if (directory == null || _pendingLines.isEmpty) return;
    final chunk = _pendingLines.join('\n');
    _pendingLines.clear();
    _writeChain = _writeChain.then((_) => _appendChunk(directory, chunk));
  }

  Future<void> _appendChunk(Directory directory, String chunk) async {
    // Persistence may have been disabled or retargeted while this chunk
    // waited in the write chain.
    if (_persistDirectory != directory) return;
    final bytes = chunk.length + 1;
    if (_currentFileBytes > 0 && _currentFileBytes + bytes > _maxBytesPerFile) {
      _sessionFileSeq++;
      _currentFileBytes = 0;
    }
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      '$_filePrefix${_sessionStartMillis}_'
      '${_sessionFileSeq.toString().padLeft(3, '0')}$_fileSuffix',
    );
    try {
      await file.writeAsString('$chunk\n', mode: FileMode.append);
      _currentFileBytes += bytes;
      _consecutiveWriteFailures = 0;
    } on FileSystemException {
      _consecutiveWriteFailures++;
      if (_consecutiveWriteFailures >= _maxConsecutiveWriteFailures) {
        _persistDirectory = null;
        _pendingLines.clear();
        captureLog(
          LogEntry(
            timestamp: DateTime.now(),
            level: LogLevel.warning,
            message:
                'Log persistence disabled after '
                '$_consecutiveWriteFailures consecutive write failures',
            name: 'LogCaptureService',
          ),
        );
      }
    }
  }

  Future<List<File>> _sessionFiles(Directory directory) async {
    if (!directory.existsSync()) return const [];
    final files = await directory
        .list()
        .where(
          (e) =>
              e is File &&
              _fileName(e).startsWith(_filePrefix) &&
              _fileName(e).endsWith(_fileSuffix),
        )
        .cast<File>()
        .toList();
    // Names embed a fixed-width millis timestamp + zero-padded part
    // sequence, so a lexicographic sort is chronological.
    files.sort((a, b) => _fileName(a).compareTo(_fileName(b)));
    return files;
  }

  String _fileName(FileSystemEntity entity) =>
      entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;

  int _fileStartMillis(File file) {
    final name = _fileName(file);
    final core = name.substring(
      _filePrefix.length,
      name.length - _fileSuffix.length,
    );
    final millis = int.tryParse(core.split('_').first);
    return millis ?? file.statSync().modified.millisecondsSinceEpoch;
  }

  Future<void> _pruneOldFiles(Directory directory) async {
    final files = await _sessionFiles(directory);
    final cutoff = DateTime.now().subtract(_maxFileAge).millisecondsSinceEpoch;
    final kept = <File>[];
    for (final file in files) {
      if (_fileStartMillis(file) < cutoff) {
        await _deleteIgnoringErrors(file);
      } else {
        kept.add(file);
      }
    }

    var totalBytes = 0;
    for (final file in kept) {
      totalBytes += file.statSync().size;
    }
    // Oldest first until back under the cap.
    for (final file in kept) {
      if (totalBytes <= _maxTotalBytes) break;
      totalBytes -= file.statSync().size;
      await _deleteIgnoringErrors(file);
    }
  }

  Future<void> _deleteIgnoringErrors(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Ignore: an undeletable file must not block logging or clearing.
    }
  }

  /// Get recent logs from memory buffer (fast access)
  ///
  /// [limit] - Max entries to return (most recent).
  /// [minLevel] - Optional minimum log level filter
  List<LogEntry> getRecentLogs({int? limit, LogLevel? minLevel}) {
    // Convert buffer to list and sort by timestamp
    var logs = _memoryBuffer.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Apply level filter if specified
    if (minLevel != null) {
      logs = logs.where((log) => log.level.value >= minLevel.value).toList();
    }

    // Apply limit if specified (return most recent)
    if (limit != null && logs.length > limit) {
      return logs.sublist(logs.length - limit);
    }

    return logs;
  }

  /// Get ALL logs as formatted text lines (for export/bug reports).
  ///
  /// With persistence enabled this spans every retained session file
  /// (previous app sessions first, current session last); otherwise it
  /// falls back to the in-memory buffer of the current session.
  Future<List<String>> getAllLogsAsText() async {
    final directory = _persistDirectory;
    if (directory == null) {
      if (_memoryBuffer.isEmpty) {
        return [];
      }
      return _memoryBuffer.map(_formatLogEntry).toList();
    }

    await flush();
    final lines = <String>[];
    int? previousSessionMillis;
    for (final file in await _sessionFiles(directory)) {
      final startMillis = _fileStartMillis(file);
      // One marker per app session (rotated parts share the timestamp),
      // so support can tell where a report's session actually begins.
      if (startMillis != previousSessionMillis) {
        previousSessionMillis = startMillis;
        final startedAt = DateTime.fromMillisecondsSinceEpoch(
          startMillis,
        ).toIso8601String();
        lines.add('───── app session started $startedAt ─────');
      }
      try {
        lines.addAll(await file.readAsLines());
      } on FileSystemException {
        // Skip unreadable files rather than failing the whole export.
      }
    }
    return lines;
  }

  /// Get statistics about log storage
  Future<Map<String, dynamic>> getLogStatistics() async {
    final directory = _persistDirectory;
    var fileCount = 0;
    if (directory != null) {
      await flush();
      fileCount = (await _sessionFiles(directory)).length;
    }

    final allLogLines = await getAllLogsAsText();
    final totalSize = allLogLines.fold<int>(
      0,
      (sum, line) => sum + line.length,
    );

    return {
      'fileCount': fileCount,
      'totalSizeBytes': totalSize,
      'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      'totalLogLines': allLogLines.length,
      'memoryBufferSize': _memoryBuffer.length,
      'totalEntriesWritten': _totalEntriesWritten,
    };
  }

  /// Clear all logs, including persisted session files.
  Future<void> clearAllLogs() async {
    _memoryBuffer.clear();
    _pendingLines.clear();
    _totalEntriesWritten = 0;
    final directory = _persistDirectory;
    if (directory != null) {
      await _writeChain;
      for (final file in await _sessionFiles(directory)) {
        await _deleteIgnoringErrors(file);
      }
      _currentFileBytes = 0;
      _sessionFileSeq = 0;
    }
  }

  /// Resets the singleton so each test starts from a clean instance.
  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  /// Get current buffer size
  int get bufferSize => _memoryBuffer.length;

  /// Get maximum buffer capacity
  int get maxCapacity => _memoryBufferSize;

  /// Check if buffer is empty
  bool get isEmpty => _memoryBuffer.isEmpty;

  /// Check if buffer is at capacity
  bool get isFull => _memoryBuffer.length >= _memoryBufferSize;
}
