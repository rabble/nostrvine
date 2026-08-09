// ABOUTME: Configuration for bug report system including support email and limits
// ABOUTME: Defines sensitive data patterns for sanitization and report size constraints

import 'package:unified_logger/unified_logger.dart';

/// Configuration for bug report system
class BugReportConfig {
  /// API endpoint for submitting bug reports
  /// Worker deployed at: https://bug-reports.protestnet.workers.dev
  /// Will move to reports.divine.video once custom domain is configured
  static const String bugReportApiUrl =
      'https://bug-reports.protestnet.workers.dev/api/bug-reports';

  /// Email address for receiving bug reports (fallback only)
  static const String supportEmail = 'contact@divine.video';

  /// Static fallback DM target for support bug reports when the support
  /// account's advertised NIP-17 inbox relays cannot be resolved.
  static const List<String> supportDmTargetRelays = [
    'wss://relay.divine.video',
  ];

  /// Maximum log entries to include in bug report
  static const int maxLogEntries = 5000;

  /// Maximum bug report size in bytes (~1MB)
  static const int maxReportSizeBytes = 1024 * 1024;

  /// Max characters per individual log entry in the Zendesk summary.
  /// 500 chars is enough for error type + message context without
  /// including full SQL statements or serialized event payloads.
  static const int maxLogEntryLength = 500;

  /// Max total characters for the log summary sent to Zendesk.
  /// Zendesk description limit is 64K; logs share that space with
  /// device info, steps to reproduce, etc. 32KB leaves headroom.
  static const int maxLogSummaryLength = 32 * 1024;

  /// Sensitive data patterns to sanitize
  static final List<RegExp> sensitivePatterns = [
    RegExp(
      'nsec1[a-z0-9]{58}',
      caseSensitive: false,
    ), // nsec private keys (bech32)
    RegExp('ncryptsec1[a-z0-9]+', caseSensitive: false),
    // Note: we do not redact 64-char hex strings because that would also
    // redact public event IDs and pubkeys. Hex-form private keys are an
    // accepted residual risk for diagnostic triage value.
    // NIP-46 bunker secrets are covered by the generic secret pattern below.
    // Credential keys. The separator must be `:` or `=`, with optional quotes
    // on either side, so serialized forms like {"token":"..."} are caught while
    // ordinary prose ("password reset failed") keeps its next word. Matching
    // starts mid-word, so `access_token` and `secret_key` are covered too.
    RegExp(
      r'''(password|token|secret)[\w-]*["']?\s*[:=]\s*["']?[^\s"',;}]+''',
      caseSensitive: false,
    ),
    RegExp(
      r'''authorization["']?\s*[:=]\s*["']?'''
      r'''(?:bearer|basic|token)\s+[^\s"',;}]+''',
      caseSensitive: false,
    ),
    RegExp(r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', caseSensitive: false),
  ];

  /// Log levels to include in bug reports (all by default)
  static const Set<LogLevel> includedLogLevels = {
    LogLevel.verbose,
    LogLevel.debug,
    LogLevel.info,
    LogLevel.warning,
    LogLevel.error,
  };
}

/// Sanitize one user-provided or diagnostic text field before it reaches a
/// public or shareable support payload.
String sanitizeDiagnosticText(String input) {
  var sanitized = input;
  for (final pattern in BugReportConfig.sensitivePatterns) {
    sanitized = sanitized.replaceAll(pattern, '[REDACTED]');
  }
  return sanitized;
}
