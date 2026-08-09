// ABOUTME: Configuration for bug report system including support email and limits
// ABOUTME: Defines sensitive data patterns for sanitization and report size constraints

import 'package:unified_logger/unified_logger.dart';

/// Separator between a credential key and its value: `:`, `:=`, `=` or `=>`,
/// with an optional quote before it. Requiring one is what keeps the prose
/// "password reset failed" intact - a bare space is not evidence of a secret.
const _credentialSeparator = r'''["']?\s*(?::=?|=>?)\s*''';

/// A credential value.
///
/// A quoted value is consumed to its closing quote, escaped quotes included,
/// so a multi-word secret is redacted whole. Partial redaction is worse than
/// none: the `[REDACTED]` marker reads as proof the value was handled while
/// the rest of the secret sits next to it.
///
/// Both quoted branches require the closing quote and stop at a newline, so an
/// unbalanced quote (`password: "oops` typed into a bug report) falls through
/// to the unquoted branch and costs one word, rather than swallowing every
/// field printed after it. The optional `bearer`/`basic`/`token` scheme word
/// keeps `Authorization: Bearer <jwt>` from redacting only the word "Bearer".
const _credentialValue =
    r'''(?:"(?:\\.|[^"\\\n])*"'''
    r"""|'(?:''|\\.|[^'\\\n])*'"""
    r'''|["']?(?:(?:bearer|basic|token)\s+)?[^\s"',;}]+)''';

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
    //
    // Credential key/value pairs. Keys are enumerated words, optionally
    // extended by `_`/`-` segments (`AWS_SECRET_ACCESS_KEY`,
    // `password_confirmation`), while a bare lowercase continuation is left
    // alone as an ordinary English word (`tokenization`, `passwordless`,
    // `secretary`). Because there is no leading boundary, an enumerated word
    // is also matched at the end of a longer key - that is what covers
    // `clientSecret` and `signing_key`, and it is why `cancellationToken:
    // active` and `token_count: 5` are redacted too. That over-redaction is
    // deliberate: no key-only rule separates `token_value` from `token_count`,
    // and losing a counter costs less than leaking a credential.
    //
    // `key` is the exception to that: it is a common English word, so it only
    // counts as a credential key in compound form (`api_key`, `sessionKey`).
    // Bare `key` is left alone, which keeps `Failed to import key: <error>`,
    // `Cache key: video_123` and `KeyEvent: KeyDownEvent` readable. The
    // compound forms are further guarded against every spelling of the public
    // key (`pub_key`, `public_key`, `publicKey`), which support needs for
    // triage and which is public by construction.
    //
    // The `[_-]` segment class deliberately excludes `_`: writing it as `\w`
    // would let the same key be parsed 2^n ways, and a 60-character key would
    // then take tens of seconds to fail to match, on the UI thread, over text
    // that can come from a remote profile or an attacker-typed report field.
    RegExp(
      '(?:authorization|passphrase|passcode|password|passwd|pwd'
      '|token|secret|api[_-]?key'
      '|(?<=[_-])(?<!pub[_-])(?<!public[_-])key)'
      '(?:[_-][A-Za-z0-9]+)*'
      '$_credentialSeparator$_credentialValue',
      caseSensitive: false,
    ),
    // camelCase and PascalCase compounds (`tokenValue`, `PasswordHash`).
    // Case-sensitive, so an uppercase continuation is required - that is what
    // separates these from `tokenization`. The continuation class excludes
    // uppercase for the same non-ambiguity reason as above.
    RegExp(
      '(?:[Pp]assphrase|[Pp]asscode|[Pp]assword|[Pp]asswd|[Pp]wd'
      '|[Tt]oken|[Ss]ecret)'
      '(?:[A-Z][a-z0-9]*)+'
      '$_credentialSeparator$_credentialValue',
    ),
    // camelCase `key` (`sessionKey`, `privateKeyHex`, `AESKey`). Kept separate
    // because it needs no continuation, and case-sensitive so `KeyEvent` and
    // `keyLabel` are untouched - only a capital `Key` preceded by another
    // letter counts. The continuation is what covers `privateKeyHex` and
    // `rawKeyHex`; those matter because a 64-char hex value is deliberately
    // not redacted, so the key *name* is the only thing keeping a hex-form
    // private key out of a public ticket. `physical`/`logical` are excluded
    // because Flutter's KeyEvent.toString() prints them and they are never
    // credentials.
    RegExp(
      '(?<=[A-Za-z])(?<![Pp]ub)(?<![Pp]ublic)'
      '(?<![Pp]hysical)(?<![Ll]ogical)Key'
      '(?:[A-Z][a-z0-9]*)*'
      '$_credentialSeparator$_credentialValue',
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
