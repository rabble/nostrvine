// ABOUTME: Configuration for bug report system including support email and limits
// ABOUTME: Defines sensitive data patterns for sanitization and report size constraints

import 'package:unified_logger/unified_logger.dart';

/// Separator between a credential key and its value: `:`, `:=`, `=` or `=>`,
/// with an optional quote before it. Requiring one is what keeps the prose
/// "password reset failed" intact - a bare space is not evidence of a secret.
///
/// Markdown emphasis around the key is consumed with the separator. The bug
/// report renders device info as `- **sessionKey:** <value>`, and without this
/// the value branch matches the `**` and reports success while the secret sits
/// one character further along.
const _credentialSeparator = r'''\**["']?\s*(?::=?|=>?)\**\s*''';

/// A credential value.
///
/// A quoted value is consumed to its closing quote, escaped quotes included,
/// so a multi-word secret is redacted whole. Partial redaction is worse than
/// none: the `[REDACTED]` marker reads as proof the value was handled while
/// the rest of the secret sits next to it. A bracketed or braced value is
/// consumed for the same reason - without those branches
/// `{"token":["a","b"]}` and `{"token":{"v":"a"}}` redact the opening
/// punctuation and leave the secret in the ticket.
///
/// Collection values are matched to the *last* delimiter in range, not the
/// first. Stopping at the first `}` would leave `{"token":{"h":{},"jwt":"x"}}`
/// half-redacted with the jwt still beside the marker, and no depth-limited
/// pattern fixes that for arbitrary nesting. Redacting a sibling field on the
/// same line is the cheap direction of that trade. The same-line branch is
/// tried first; the branch behind it also crosses newlines, which is what
/// catches a pretty-printed value.
///
/// Both are bounded at 4000 characters, and the bound does two jobs. It caps
/// what an unclosed `{` can consume: 4000 characters of surrounding
/// diagnostics, rather than everything up to `maxLogSummaryLength`. In a short
/// report that cap is still most of it - the bound limits the damage, it does
/// not make a stray brace cheap.
/// It also keeps the scan linear: without it, every `token: {` candidate on a
/// long line rescans to the end of that line, which is quadratic in the size
/// of a pasted field. 4000 is chosen to sit above the things being bounded -
/// a JWT runs 300-800 characters on its own, and `bug_report_service.dart`
/// pretty-prints device info - because below the bound is where redaction is
/// whole and above it is where a secret survives beside the marker.
///
/// Both quoted branches require the closing quote and stop at a newline, so an
/// unbalanced quote (`password: "oops` typed into a bug report) falls through
/// to the unquoted branch and costs one word, rather than swallowing every
/// field printed after it. The optional `bearer`/`basic`/`token` scheme word
/// keeps `Authorization: Bearer <jwt>` from redacting only the word "Bearer".
const _credentialValue =
    r'''(?:\[[^\n]{0,4000}\]|\[[\s\S]{0,4000}\]'''
    r'''|\{[^\n]{0,4000}\}|\{[\s\S]{0,4000}\}'''
    r'''|"(?:\\.|[^"\\\n])*"'''
    r"""|'(?:''|\\.|[^'\\\n])*'"""
    r'''|["']?(?:(?:bearer|basic|token)\s+)?[^\s"',;}]+)''';

/// Configuration for bug report system
class BugReportConfig {
  /// Maximum log entries to include in bug report
  static const int maxLogEntries = 5000;

  /// Max characters per individual log entry in the Zendesk summary.
  /// 500 chars is enough for error type + message context without
  /// including full SQL statements or serialized event payloads.
  static const int maxLogEntryLength = 500;

  /// Max characters accepted in a support form subject field.
  ///
  /// A subject is a one-line summary, and it is written twice - as the Zendesk
  /// subject and as the first line of the assembled description. The form
  /// tells the user when this cap truncates a paste, so the limit is visible
  /// rather than silent.
  static const int maxSubjectLength = 200;

  /// Max characters accepted in each free-text bug report field.
  ///
  /// Sanitization is linear in the size of the field but with a large
  /// constant: every credential-key candidate scans up to the collection
  /// bound. Unbounded, a pasted 1MB field costs ~7.7s on the main isolate,
  /// past Android's ANR threshold. This cap keeps a pasted field bounded and
  /// 10000 characters is far more than a typed description or repro steps.
  static const int maxFreeTextFieldLength = 10000;

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
    // triage and which is public by construction. Plurals count the same as
    // singulars everywhere: `privateKeys` hides a hex-form private key exactly
    // as well as `privateKey` does.
    //
    // The continuation class after `[_-]` deliberately excludes `_`: writing
    // it as `\w` would let the same key be parsed 2^n ways, and a
    // 60-character key would then take tens of seconds to fail to match, on
    // the UI thread, over text that can come from a remote profile or an
    // attacker-typed report field.
    //
    // The segment counts are capped for the same reason the collection value
    // is. Unbounded, a `password_password_password_…` paste costs 18s per
    // 100KB, measured, because every start position walks the whole run before
    // failing for want of a separator; capped, the same input is 94ms. No real
    // credential key has 24 segments.
    RegExp(
      '(?:(?:authorization|passphrase|passcode|password|passwd|pwd'
      '|token|jwt|secret|api[_-]?key)s?'
      '|(?<=[_-])(?<!pub[_-])(?<!public[_-])(?<!(?<![A-Za-z])query[_-])keys?)'
      '(?:[_-][A-Za-z0-9]+){0,24}'
      '$_credentialSeparator$_credentialValue',
      caseSensitive: false,
    ),
    // camelCase and PascalCase compounds (`tokenValue`, `PasswordHash`).
    // Case-sensitive, so an uppercase continuation is required - that is what
    // separates these from `tokenization`. The continuation class excludes
    // uppercase for the same non-ambiguity reason as above.
    RegExp(
      '(?:[Pp]assphrase|[Pp]asscode|[Pp]assword|[Pp]asswd|[Pp]wd'
      '|[Tt]oken|[Jj]wt|JWT|[Ss]ecret)s?'
      '(?:[A-Z][a-z0-9]*){1,24}'
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
    // credentials, and `query` because `_describeUriForLogs` logs a deep
    // link's `queryKeys` precisely to record parameter names *without* their
    // values - redacting it deletes a diagnostic built to be privacy-safe.
    // That guard is anchored to the start of the key, so it exempts `queryKeys`
    // without also exempting `bigQueryKey`.
    RegExp(
      '(?<=[A-Za-z])(?<![Pp]ub)(?<![Pp]ublic)'
      '(?<![Pp]hysical)(?<![Ll]ogical)(?<!(?<![A-Za-z])[Qq]uery)Keys?'
      '(?:[A-Z][a-z0-9]*){0,24}'
      '$_credentialSeparator$_credentialValue',
    ),
    RegExp(
      r'\b[A-Z0-9._%+-]{1,64}@[A-Z0-9.-]{1,255}\.[A-Z]{2,24}\b',
      caseSensitive: false,
    ),
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
