// ABOUTME: Marker interface + wrapper + PII sanitizer used to gate Bloc errors
// ABOUTME: forwarded to Crashlytics. See .claude/rules/error_handling.md.

/// Marker interface signalling that an error is worth reporting to Crashlytics.
///
/// Errors that flow through `addError(error, st)` only reach the crash reporter
/// when they implement [ReportableError]. Default for an unmarked error is
/// "log locally, do not forward" — see the decision matrix in
/// `.claude/rules/error_handling.md`.
///
/// To opt an existing exception type in, declare
/// `class FooInvariantException implements ReportableError { … }`. To wrap a
/// foreign exception (e.g. a `StateError` raised by a third-party library) at
/// a specific call site, use [Reportable].
abstract interface class ReportableError implements Exception {}

/// Wraps a foreign error so it can be forwarded to Crashlytics through a
/// `BlocObserver` filter without modifying the underlying exception type.
///
/// Use at the `addError` call site:
///
/// ```dart
/// } catch (e, stackTrace) {
///   addError(Reportable(e, context: '_publishLike'), stackTrace);
/// }
/// ```
///
/// [context] is a short identifier — usually the method name — that becomes
/// part of the Crashlytics report annotation so dashboards can distinguish
/// multiple call sites in the same bloc.
///
/// [toString] runs [sanitizeForCrashReport] over the inner error's
/// stringification so `npub1…` / `nsec1…` identifiers never reach the crash
/// reporter, regardless of which call site produced the error.
final class Reportable<T extends Object> implements ReportableError {
  const Reportable(this.error, {this.context});

  final T error;
  final String? context;

  T unwrap() => error;

  @override
  String toString() {
    final sanitized = sanitizeForCrashReport(error.toString());
    final ctx = context;
    // Use the inner error's runtime type rather than the generic [T] —
    // most call sites live inside `catch (e, st)` blocks where `e` is
    // statically `Object`, so `T` would erase the actual inner type.
    final innerType = error.runtimeType;
    return ctx == null
        ? 'Reportable<$innerType>: $sanitized'
        : 'Reportable<$innerType>($ctx): $sanitized';
  }
}

final RegExp _npubPattern = RegExp('npub1[a-z0-9]+');
final RegExp _nsecPattern = RegExp('nsec1[a-z0-9]+');

/// Strips Nostr `npub1…` and `nsec1…` identifiers from [input] before it is
/// forwarded to a third-party crash reporter.
///
/// Scope is intentionally narrow: only `npub` (public-key bech32) and `nsec`
/// (private-key bech32). Other Nostr-format references (`note1`, `nevent1`,
/// `nprofile1`) encode event/profile pointers, not secrets, and removing them
/// removes triage value. Call sites that need to redact those should do so
/// explicitly before constructing the error message.
String sanitizeForCrashReport(String input) {
  return input
      .replaceAll(_npubPattern, 'npub1<redacted>')
      .replaceAll(_nsecPattern, 'nsec1<redacted>');
}
