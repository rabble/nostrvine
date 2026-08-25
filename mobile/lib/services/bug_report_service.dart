// ABOUTME: Service for collecting comprehensive bug report diagnostics
// ABOUTME: Gathers device info, logs, errors and sanitizes sensitive data before transmission

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:analytics/analytics.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:models/models.dart' show BugReportData, LogEntry;
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:openvine/utils/app_uptime.dart';
import 'package:openvine/utils/browser_file_download.dart';
import 'package:openvine/utils/device_memory_util.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

/// Service for creating and managing bug reports
class BugReportService {
  BugReportService({
    ErrorAnalyticsTracker? errorTracker,
    StorageManagementService? storageManagementService,
    Future<PackageInfo> Function()? packageInfoLoader,
  }) : _errorTracker = errorTracker ?? ErrorAnalyticsTracker(),
       _storageManagementService = storageManagementService,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform;

  static const _uuid = Uuid();

  /// Byte ceiling for a clipboard copy of the logs.
  ///
  /// Android moves clipboard data across a Binder transaction whose ~1 MB
  /// ceiling covers everything in flight, and Zendesk caps a ticket
  /// description at 64K — so a copy someone can actually paste into a
  /// support ticket is the smaller of the two constraints.
  @visibleForTesting
  static const int logClipboardByteBudget = 64 * 1024;
  final ErrorAnalyticsTracker _errorTracker;
  final StorageManagementService? _storageManagementService;
  final Future<PackageInfo> Function() _packageInfoLoader;

  /// Collect comprehensive diagnostics for bug report
  Future<BugReportData> collectDiagnostics({
    required String userDescription,
    String? currentScreen,
    String? userPubkey,
    Map<String, dynamic>? additionalContext,
  }) async {
    Log.info('Collecting bug report diagnostics', category: LogCategory.system);

    try {
      // Generate unique report ID
      final reportId = _uuid.v4();

      // Get app version from package_info_plus
      final packageInfo = await _packageInfoLoader();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      // Get device info using device_info_plus
      final deviceInfoPlugin = DeviceInfoPlugin();
      Map<String, dynamic> deviceInfo = {};
      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          deviceInfo = {
            'platform': 'android',
            'model': androidInfo.model,
            'manufacturer': androidInfo.manufacturer,
            'version': androidInfo.version.release,
            'sdkInt': androidInfo.version.sdkInt,
            'brand': androidInfo.brand,
          };
        } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          deviceInfo = {
            'platform': 'ios',
            'model': iosInfo.model,
            'systemName': iosInfo.systemName,
            'systemVersion': iosInfo.systemVersion,
            'name': iosInfo.name,
          };
        } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
          final macInfo = await deviceInfoPlugin.macOsInfo;
          deviceInfo = {
            'platform': 'macos',
            'model': macInfo.model,
            'version': macInfo.osRelease,
            'hostName': macInfo.hostName,
          };
        } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
          final windowsInfo = await deviceInfoPlugin.windowsInfo;
          deviceInfo = {
            'platform': 'windows',
            'version': windowsInfo.productName,
            'computerName': windowsInfo.computerName,
          };
        } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
          final linuxInfo = await deviceInfoPlugin.linuxInfo;
          deviceInfo = {
            'platform': 'linux',
            'version': linuxInfo.version ?? 'unknown',
            'name': linuxInfo.name,
          };
        } else {
          // Unknown platform fallback (includes web)
          deviceInfo = {'platform': 'unknown', 'version': 'unknown'};
        }
      } catch (e) {
        Log.warning(
          'Failed to get device info: $e',
          category: LogCategory.system,
        );
        // Must include platform even in error case for Worker API compatibility
        final platform = switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          TargetPlatform.macOS => 'macos',
          TargetPlatform.windows => 'windows',
          TargetPlatform.linux => 'linux',
          _ => 'unknown',
        };
        deviceInfo = {
          'platform': platform,
          'version': 'unknown',
          'error': 'Failed to get device info',
        };
      }

      // Get recent logs from LogCaptureService
      final recentLogs = LogCaptureService().getRecentLogs(
        limit: BugReportConfig.maxLogEntries,
      );

      // Get error counts from the injected ErrorAnalyticsTracker
      final errorCounts = _errorTracker.getAllErrorCounts();

      // Create bug report data
      final reportData = BugReportData(
        reportId: reportId,
        timestamp: DateTime.now(),
        userDescription: userDescription,
        deviceInfo: deviceInfo,
        appVersion: appVersion,
        recentLogs: recentLogs,
        errorCounts: errorCounts,
        currentScreen: currentScreen,
        userPubkey: userPubkey,
        additionalContext: additionalContext,
      );

      Log.info(
        'Diagnostics collected: ${recentLogs.length} logs, ${errorCounts.length} error types',
        category: LogCategory.system,
      );

      return sanitizeSensitiveData(reportData);
    } catch (e) {
      Log.error(
        'Failed to collect diagnostics: $e',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Sanitize sensitive data from bug report
  BugReportData sanitizeSensitiveData(BugReportData data) {
    Log.debug(
      'Sanitizing sensitive data from bug report',
      category: LogCategory.system,
    );

    // Sanitize user description
    final sanitizedDescription = _sanitizeString(data.userDescription);

    // Sanitize logs
    final sanitizedLogs = data.recentLogs.map((log) {
      return LogEntry(
        timestamp: log.timestamp,
        level: log.level,
        message: _sanitizeString(log.message),
        category: log.category,
        name: log.name,
        error: log.error != null ? _sanitizeString(log.error!) : null,
        stackTrace: log.stackTrace != null
            ? _sanitizeString(log.stackTrace!)
            : null,
      );
    }).toList();

    // Sanitize additional context if present
    Map<String, dynamic>? sanitizedContext;
    if (data.additionalContext != null) {
      sanitizedContext = _sanitizeMap(data.additionalContext!);
    }

    return data.copyWith(
      userDescription: sanitizedDescription,
      deviceInfo: _sanitizeDeviceInfo(data.deviceInfo),
      recentLogs: sanitizedLogs,
      additionalContext: sanitizedContext,
      errorCounts: _sanitizeErrorCounts(data.errorCounts),
    );
  }

  /// Sanitize error-count keys, which are `'<location>:<errorType>'` strings
  /// and so can carry a credential-shaped name.
  ///
  /// Done here rather than only where the counts are rendered, so every
  /// consumer of the sanitized report inherits it.
  Map<String, int> _sanitizeErrorCounts(Map<String, int> input) {
    final sanitized = <String, int>{};
    input.forEach((key, value) {
      final composed = '$key: $value';
      final safeKey = sanitizeDiagnosticText(composed) == composed
          ? key
          : '[REDACTED]';
      // Summed rather than overwritten: two credential-shaped keys both
      // collapse to the same placeholder, and silently dropping one of the
      // counts is the kind of quiet loss this sanitizer exists to avoid.
      sanitized[safeKey] = (sanitized[safeKey] ?? 0) + value;
    });
    return sanitized;
  }

  /// Export logs to a file.
  ///
  /// Behavior depends on the platform:
  ///
  /// * **Web** — triggers a browser download.
  /// * **iOS / Android** — writes to the temp directory and presents the
  ///   system share sheet so the user can email or upload the file.
  /// * **macOS / Windows / Linux** — writes directly to the user's
  ///   Downloads folder. Desktop share popovers require an anchor frame
  ///   the support screen can't supply, so a Save-to-Downloads UX matches
  ///   desktop conventions and avoids share_plus failure modes.
  ///
  /// On success, [LogExportResult.filePath] is populated when the caller
  /// can show the user where the file landed (currently desktop only).
  ///
  /// [sharePositionOrigin] anchors the iOS share sheet popover. It is
  /// required on iPad idiom (real iPads and iOS builds running on
  /// Apple Silicon Macs) — share_plus rejects the share with
  /// "sharePositionOrigin: argument must be set" when it is missing
  /// there.
  Future<LogExportResult> exportLogsToFile({
    String? currentScreen,
    String? userPubkey,
    ui.Rect? sharePositionOrigin,
  }) async {
    try {
      Log.info(
        'Exporting comprehensive logs to file',
        category: LogCategory.system,
      );

      // Get comprehensive statistics about logs
      final stats = await LogCaptureService().getLogStatistics();
      Log.info(
        'Log stats: ${stats['totalLogLines']} lines, ${stats['totalSizeMB']} MB across ${stats['fileCount']} files',
        category: LogCategory.system,
      );

      // Get ALL logs from persistent storage (hundreds of thousands of entries)
      final allLogLines = await LogCaptureService().getAllLogsAsText();

      if (allLogLines.isEmpty) {
        Log.warning(
          'No logs available for export',
          category: LogCategory.system,
        );
        return const LogExportResult.noLogs();
      }

      final buffer = StringBuffer()
        ..write(
          await _buildLogHeader(
            stats: stats,
            lineCount: allLogLines.length,
            currentScreen: currentScreen,
            userPubkey: userPubkey,
          ),
        );

      // Add all log lines (already formatted by LogCaptureService)
      for (final line in allLogLines) {
        // Sanitize each line for sensitive data
        buffer.writeln(_sanitizeString(line));
      }

      final content = buffer.toString();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'openvine_full_logs_$timestamp.txt';

      if (kIsWeb) {
        return _exportLogsWeb(content, fileName, allLogLines.length);
      }
      if (_isDesktop) {
        return _exportLogsDesktop(content, fileName, allLogLines.length);
      }
      return _exportLogsNative(
        content,
        fileName,
        allLogLines.length,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Failed to export logs: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return const LogExportResult.failed();
    }
  }

  /// Environment diagnostics for the export header: network connectivity,
  /// text scale, active accessibility features, app uptime, device memory
  /// tier, and cache usage.
  ///
  /// Every probe is best-effort — a failing or unavailable source omits its
  /// line instead of failing the export. Returns an empty string on web.
  @visibleForTesting
  Future<String> buildEnvironmentDiagnostics() async {
    if (kIsWeb) return '';
    final buffer = StringBuffer();
    try {
      final results = await Connectivity().checkConnectivity();
      buffer.writeln('Network: ${results.map((r) => r.name).join(', ')}');
    } on Object catch (_) {
      // Connectivity plugin unavailable (e.g. tests); omit the line.
    }
    final dispatcher = ui.PlatformDispatcher.instance;
    buffer.writeln(
      'Text Scale: ${dispatcher.textScaleFactor.toStringAsFixed(2)}',
    );
    final accessibility = _activeAccessibilityFeatures(
      dispatcher.accessibilityFeatures,
    );
    if (accessibility.isNotEmpty) {
      buffer.writeln('Accessibility: ${accessibility.join(', ')}');
    }
    final uptime = AppUptime.uptime;
    if (uptime != null) {
      buffer.writeln('App Uptime: ${_formatDuration(uptime)}');
    }
    final tier = await DeviceMemoryUtil.getMemoryTier();
    buffer.writeln('Memory Tier: ${tier.name}');
    final storage = _storageManagementService;
    if (storage != null) {
      try {
        final usage = await storage.cacheUsage();
        buffer.writeln(
          'Cache: '
          'video ${_formatCacheUsageCategory(usage.video)} · '
          'images ${_formatCacheUsageCategory(usage.images)} · '
          'seams ${_formatCacheUsageCategory(usage.transitionSeams)} · '
          'temp ${_formatCacheUsageCategory(usage.tempRenders)}',
        );
      } on Object catch (_) {
        // Cache probe failed; omit the line.
      }
    }
    return buffer.toString();
  }

  static List<String> _activeAccessibilityFeatures(
    ui.AccessibilityFeatures features,
  ) {
    return [
      if (features.boldText) 'bold text',
      if (features.reduceMotion) 'reduce motion',
      if (features.disableAnimations) 'disable animations',
      if (features.highContrast) 'high contrast',
      if (features.invertColors) 'invert colors',
      if (features.accessibleNavigation) 'screen reader',
    ];
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  static String _formatBytesShort(int bytes) {
    const bytesPerMb = 1024 * 1024;
    final mb = bytes / bytesPerMb;
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  static String _formatCacheUsageCategory(CacheUsageCategory usage) {
    final limitBytes = usage.limitBytes;
    final used = _formatBytesShort(usage.usedBytes);
    if (limitBytes == null) return used;
    final ratio = limitBytes == 0 ? 0 : usage.usedBytes / limitBytes;
    final percent = (ratio * 100).toStringAsFixed(1);
    final status = _cacheBudgetStatus(usage.usedBytes, limitBytes);
    return '$used/${_formatBytesShort(limitBytes)} '
        '($percent%, $status, ${usage.usedBytes}/$limitBytes bytes)';
  }

  static String _cacheBudgetStatus(int usedBytes, int limitBytes) {
    if (usedBytes < limitBytes) return 'within limit';
    if (usedBytes == limitBytes) return 'at limit';
    return 'over limit by ${_formatBytesShort(usedBytes - limitBytes)}';
  }

  /// Human-readable device identifier for the export header, e.g.
  /// `iPhone17,2` on iOS or `Google Pixel 8` on Android.
  ///
  /// Returns `null` on web and on platforms without a meaningful device
  /// model, or when the device info probe fails — the header then simply
  /// omits the line instead of failing the whole export.
  @visibleForTesting
  static Future<String?> buildDeviceDescription() async {
    if (kIsWeb) return null;
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await deviceInfoPlugin.androidInfo;
          final name = '${info.manufacturer} ${info.model}';
          return info.isPhysicalDevice ? name : '$name (Emulator)';
        case TargetPlatform.iOS:
          final info = await deviceInfoPlugin.iosInfo;
          return info.isPhysicalDevice
              ? info.utsname.machine
              : '${info.utsname.machine} (Simulator)';
        case TargetPlatform.macOS:
          final info = await deviceInfoPlugin.macOsInfo;
          return info.model;
        // Windows exposes no hardware model, only the user-assigned
        // computerName — personal info that doesn't belong in a shareable
        // export. Linux likewise only reports the distro.
        case TargetPlatform.windows:
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          return null;
      }
    } on Object catch (e) {
      Log.warning(
        'Failed to get device description for log export: $e',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Device/runtime diagnostics for the export header: OS and version,
  /// CPU core count, build mode, and this process's memory footprint.
  ///
  /// Returns an empty string on web, where `dart:io` `Platform` and
  /// `ProcessInfo` are unavailable.
  @visibleForTesting
  static String buildRuntimeDiagnostics() {
    if (kIsWeb) return '';
    final buffer = StringBuffer()
      ..writeln(
        'Platform: ${Platform.operatingSystem} '
        '${Platform.operatingSystemVersion}',
      )
      ..writeln('CPU Cores: ${Platform.numberOfProcessors}')
      ..writeln('Build Mode: $_buildModeName');
    try {
      const bytesPerMb = 1024 * 1024;
      final rssMb = (ProcessInfo.currentRss / bytesPerMb).toStringAsFixed(1);
      final peakMb = (ProcessInfo.maxRss / bytesPerMb).toStringAsFixed(1);
      buffer.writeln('Process Memory: RSS $rssMb MB (peak $peakMb MB)');
    } on Object catch (_) {
      // ProcessInfo memory probes throw on unsupported platforms; omit
      // the line rather than failing the whole export.
    }
    return buffer.toString();
  }

  static String get _buildModeName {
    if (kDebugMode) return 'debug';
    if (kProfileMode) return 'profile';
    return 'release';
  }

  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  /// Opens the folder containing the exported log file in the OS file
  /// browser. Used by the desktop "Show in folder" snackbar action so the
  /// user can immediately attach the file they just saved.
  Future<void> revealExportedFile(String filePath) async {
    if (kIsWeb) return;
    try {
      final folder = File(filePath).parent.path;
      final uri = Uri.file(folder);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e, stackTrace) {
      Log.warning(
        'Failed to reveal exported log file: $e',
        category: LogCategory.system,
      );
      Log.error(
        'Reveal exported file stack',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Export logs on web platform using browser download
  LogExportResult _exportLogsWeb(
    String content,
    String fileName,
    int lineCount,
  ) {
    try {
      final bytes = utf8.encode(content);
      downloadBytesAsFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'text/plain',
      );

      final sizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
      Log.info(
        'Logs downloaded via browser: $fileName ($sizeMB MB, $lineCount lines)',
        category: LogCategory.system,
      );
      return const LogExportResult.shared();
    } catch (e, stackTrace) {
      Log.error(
        'Failed to download logs on web: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return const LogExportResult.failed();
    }
  }

  /// Export logs on desktop (macOS / Windows / Linux) by prompting the user
  /// for a save location and writing the log file there.
  ///
  /// `share_plus` on desktop requires a `sharePositionOrigin` anchor frame
  /// the support screen can't supply, so the share popover fails silently
  /// and the user sees "Failed to export logs". A native Save As dialog
  /// matches desktop conventions and lets the user pick where the file
  /// goes.
  ///
  /// If the user cancels the dialog, returns
  /// [LogExportResult.cancelled] so the caller can stay silent rather than
  /// showing a failure toast.
  Future<LogExportResult> _exportLogsDesktop(
    String content,
    String fileName,
    int lineCount,
  ) async {
    try {
      final downloadsDir = await getDownloadsDirectory();
      final initialDirectory =
          downloadsDir?.path ?? (await getApplicationDocumentsDirectory()).path;

      final location = await getSaveLocation(
        suggestedName: fileName,
        initialDirectory: initialDirectory,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Text', extensions: ['txt']),
        ],
      );

      if (location == null) {
        Log.info('Log export cancelled by user', category: LogCategory.system);
        return const LogExportResult.cancelled();
      }

      final file = File(location.path);
      await file.writeAsString(content);

      final fileSizeMB = (await file.length() / (1024 * 1024)).toStringAsFixed(
        2,
      );
      Log.info(
        'Comprehensive logs saved to desktop: ${location.path} '
        '($fileSizeMB MB, $lineCount lines)',
        category: LogCategory.system,
      );
      return LogExportResult.saved(location.path);
    } catch (e, stackTrace) {
      Log.error(
        'Failed to save logs on desktop: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return const LogExportResult.failed();
    }
  }

  /// The diagnostic preamble both the exported file and the clipboard
  /// copy start with, terminated by a blank line.
  Future<String> _buildLogHeader({
    required Map<String, dynamic> stats,
    required int lineCount,
    String? currentScreen,
    String? userPubkey,
  }) async {
    final packageInfo = await _packageInfoLoader();
    final buffer = StringBuffer()
      ..writeln('OpenVine Comprehensive Log Export')
      ..writeln('═' * 80)
      ..writeln('Export Time: ${DateTime.now().toIso8601String()}')
      ..writeln(
        'App Version: ${packageInfo.version}+${packageInfo.buildNumber}',
      )
      ..writeln('Total Log Lines: $lineCount')
      ..writeln('Log Files: ${stats['fileCount']}')
      ..writeln('Total Size: ${stats['totalSizeMB']} MB');
    final deviceDescription = await buildDeviceDescription();
    if (deviceDescription != null) {
      buffer.writeln('Device: $deviceDescription');
    }
    buffer
      ..write(buildRuntimeDiagnostics())
      ..write(await buildEnvironmentDiagnostics());
    if (currentScreen != null) {
      buffer.writeln('Current Screen: $currentScreen');
    }
    if (userPubkey != null) {
      buffer.writeln('User Pubkey: ${pubkeyForLogs(userPubkey)}');
    }
    return (buffer
          ..writeln('═' * 80)
          ..writeln())
        .toString();
  }

  /// Build the diagnostic header plus the most recent log lines that fit
  /// under [logClipboardByteBudget], for copying to the clipboard.
  ///
  /// This exists because the share sheet cannot serve a copy on Android: its
  /// "Copy" chip copies `Intent.EXTRA_TEXT`, never the attached file. A
  /// separate path is the only way that gesture yields logs, and it has to
  /// be capped — the full buffer runs to 5-10 MB and the clipboard crosses a
  /// Binder transaction with roughly a 1 MB ceiling for everything in it.
  Future<LogClipboardResult> buildLogClipboardText({
    String? currentScreen,
    String? userPubkey,
  }) async {
    try {
      final allLogLines = await LogCaptureService().getAllLogsAsText();
      if (allLogLines.isEmpty) return const LogClipboardResult.noLogs();

      final stats = await LogCaptureService().getLogStatistics();
      final header = await _buildLogHeader(
        stats: stats,
        lineCount: allLogLines.length,
        currentScreen: currentScreen,
        userPubkey: userPubkey,
      );

      // Walk backwards so the tail — the part nearest whatever just went
      // wrong — is what survives the budget.
      final sanitizedLines = allLogLines.map(_sanitizeString).toList();
      final tail = <String>[];
      final headerBytes = utf8.encode(header).length;
      var tailBytes = 0;
      for (final line in sanitizedLines.reversed) {
        final lineBytes = utf8.encode(line).length + 1;
        final omitted = sanitizedLines.length - tail.length - 1;
        final markerBytes = utf8.encode(_omittedMarker(omitted)).length;
        if (headerBytes + markerBytes + tailBytes + lineBytes >
            logClipboardByteBudget) {
          break;
        }
        tail.add(line);
        tailBytes += lineBytes;
      }

      if (tail.isEmpty) {
        final omitted = sanitizedLines.length - 1;
        final marker = _omittedMarker(omitted);
        final fixedText = '$header$marker';
        final remaining =
            logClipboardByteBudget - utf8.encode(fixedText).length;
        final newest = _truncateUtf8(sanitizedLines.last, remaining - 1);
        final text = '$fixedText$newest\n';
        return LogClipboardResult.success(
          _truncateUtf8(text, logClipboardByteBudget),
        );
      }

      return LogClipboardResult.success(
        _buildClipboardPayload(
          header: header,
          reversedTail: tail,
          totalLineCount: sanitizedLines.length,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        'Failed to build clipboard log text: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return const LogClipboardResult.failed();
    }
  }

  static String _buildClipboardPayload({
    required String header,
    required List<String> reversedTail,
    required int totalLineCount,
  }) {
    final buffer = StringBuffer(header);
    final omitted = totalLineCount - reversedTail.length;
    if (omitted > 0) buffer.write(_omittedMarker(omitted));
    reversedTail.reversed.forEach(buffer.writeln);
    return buffer.toString();
  }

  static String _omittedMarker(int omitted) =>
      omitted > 0 ? '... [$omitted earlier entries omitted]\n' : '';

  static String _truncateUtf8(String value, int maxBytes) {
    if (maxBytes <= 0) return '';
    final bytes = utf8.encode(value);
    if (bytes.length <= maxBytes) return value;
    var end = maxBytes;
    while (end > 0) {
      try {
        return utf8.decode(bytes.sublist(0, end));
      } on FormatException {
        end--;
      }
    }
    return '';
  }

  /// Export logs on mobile platforms using the system share sheet.
  Future<LogExportResult> _exportLogsNative(
    String content,
    String fileName,
    int lineCount, {
    ui.Rect? sharePositionOrigin,
  }) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(content);

      final fileSizeMB = (await file.length() / (1024 * 1024)).toStringAsFixed(
        2,
      );
      Log.info(
        'Comprehensive logs written to file: $filePath ($fileSizeMB MB, $lineCount lines)',
        category: LogCategory.system,
      );

      // `text` stays short because it is the body every share target
      // prefills — a log dump here would land in the email or message
      // alongside the attachment. On Android it is also what the share
      // sheet's own "Copy" chip copies, which copies EXTRA_TEXT and never
      // the attachment, so that chip cannot deliver logs however it is
      // worded. Copying is served by [buildLogClipboardText] instead.
      final result = await showShareSheetAtOrigin(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'OpenVine Full Logs',
          text: 'OpenVine Full Logs',
        ),
        sharePositionOrigin: sharePositionOrigin,
      );

      switch (result.status) {
        case ShareResultStatus.success:
          Log.info('Logs shared successfully', category: LogCategory.system);
          return const LogExportResult.shared();
        case ShareResultStatus.dismissed:
          Log.info(
            'Log sharing dismissed by user',
            category: LogCategory.system,
          );
          return const LogExportResult.cancelled();
        case ShareResultStatus.unavailable:
          Log.warning(
            'Log sharing outcome unavailable; the sheet may still have '
            'completed the share',
            category: LogCategory.system,
          );
          return const LogExportResult.unconfirmed();
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to export logs on native platform: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return const LogExportResult.failed();
    }
  }

  // Private helper methods

  /// Sanitize a string by removing sensitive patterns
  String _sanitizeString(String input) {
    return sanitizeDiagnosticText(input);
  }

  /// Sanitize a map by removing sensitive values.
  ///
  /// Sensitivity is decided on the `key: value` pair, not on the value alone.
  /// The rules match a credential *key* next to its value, so a value handed
  /// over on its own arrives with no key attached and survives:
  /// `{'sessionKey': '<secret>'}` came back unchanged before this, into an
  /// export the user can share anywhere.
  ///
  /// A credential-shaped key redacts its whole value regardless of type. A
  /// secret is just as exposed as `{'sessionKey': ['<secret>']}` or
  /// `{'apiKey': {'value': '<secret>'}}`, and recursing into those loses the
  /// key that identifies them.
  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> input) {
    final Map<String, dynamic> sanitized = {};

    input.forEach((key, value) {
      if (_isCredentialKey(key)) {
        // The whole subtree, whatever shape it is. Recursing would hand the
        // rules a bare value with no key attached, which is how
        // `{'apiKey': ['<secret>']}` used to survive.
        sanitized[key] = '[REDACTED]';
      } else if (value is String) {
        sanitized[key] = _sanitizeString(value);
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = _sanitizeMap(value);
      } else if (value is List) {
        sanitized[key] = _sanitizeList(value);
      } else {
        sanitized[key] = value;
      }
    });

    return sanitized;
  }

  /// Whether [key] alone reads as a credential key.
  ///
  /// Tested with a placeholder value rather than the real one, so the answer
  /// does not depend on what the value happens to contain: the point is that
  /// `sessionKey` identifies a credential no matter whether its value is a
  /// string, a list or a nested map.
  bool _isCredentialKey(String key) {
    const probe = 'x';
    final composed = '$key: $probe';
    return sanitizeDiagnosticText(composed) != composed;
  }

  Map<String, dynamic> _sanitizeDeviceInfo(Map<String, dynamic> input) {
    final sanitized = _sanitizeMap(input);
    for (final key in const ['name', 'hostName', 'computerName']) {
      if (sanitized.containsKey(key)) {
        sanitized[key] = '[REDACTED]';
      }
    }
    return sanitized;
  }

  /// Sanitize a list by removing sensitive values
  List<dynamic> _sanitizeList(List<dynamic> input) {
    return input.map((item) {
      if (item is String) {
        return _sanitizeString(item);
      } else if (item is Map<String, dynamic>) {
        return _sanitizeMap(item);
      } else if (item is List) {
        return _sanitizeList(item);
      } else {
        return item;
      }
    }).toList();
  }
}

/// Result of preparing captured logs for the clipboard.
class LogClipboardResult {
  const LogClipboardResult._(this.status, {this.text});

  const LogClipboardResult.success(String text)
    : this._(LogClipboardStatus.success, text: text);

  const LogClipboardResult.noLogs() : this._(LogClipboardStatus.noLogs);

  const LogClipboardResult.failed() : this._(LogClipboardStatus.failed);

  final LogClipboardStatus status;
  final String? text;
}

enum LogClipboardStatus { success, noLogs, failed }

/// Outcome of [BugReportService.exportLogsToFile].
///
/// On desktop, [filePath] points at the path the user picked in the
/// Save As dialog so the UI can show them where the file landed. On
/// mobile and web, [filePath] is null because the platform's share /
/// download flow already surfaces the file.
///
/// The UI branches on [status]: four of the six outcomes are not failures,
/// and reporting them as one is what made a working export look broken.
class LogExportResult {
  const LogExportResult(this.status, {this.filePath});

  const LogExportResult.shared() : this(LogExportStatus.shared);

  const LogExportResult.saved(String path)
    : this(LogExportStatus.saved, filePath: path);

  const LogExportResult.cancelled() : this(LogExportStatus.cancelled);

  const LogExportResult.noLogs() : this(LogExportStatus.noLogs);

  const LogExportResult.unconfirmed() : this(LogExportStatus.unconfirmed);

  const LogExportResult.failed() : this(LogExportStatus.failed);

  final LogExportStatus status;
  final String? filePath;
}

/// How an export ended.
enum LogExportStatus {
  /// The share sheet or browser download completed.
  shared,

  /// Written to a path the user picked in a desktop Save As dialog.
  saved,

  /// The user backed out of the share sheet or Save As dialog.
  cancelled,

  /// The capture buffer held nothing to export.
  ///
  /// Distinct from [failed] because the fix is the user's, not ours: the
  /// buffer is in memory only, so a restart empties it and they need to
  /// reproduce the problem before exporting.
  noLogs,

  /// The share sheet was presented but the platform reported no outcome.
  ///
  /// `share_plus` returns `ShareResultStatus.unavailable` on Android when it
  /// cannot attach to an Activity and falls back to `context.startActivity`.
  /// The sheet still opens and the share can still complete; the callback is
  /// simply cancelled up front, so there is nothing to observe.
  unconfirmed,

  /// A real failure — the write threw, or the platform reported an error.
  failed,
}
