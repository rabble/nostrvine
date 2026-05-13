// ABOUTME: Per-feature Reportable `context:` constants for VideoInteractionsBloc.
// ABOUTME: See .claude/rules/error_handling.md - once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [VideoInteractionsBloc].
///
/// Per the convention in `.claude/rules/error_handling.md`, when a feature
/// has more than one `addError(Reportable(e, context: ...))` site, the
/// `context:` strings are lifted into a per-feature constants class so the
/// Crashlytics dashboard groups them by stable identifier rather than
/// inline string literals.
abstract class VideoInteractionsReportableSites {
  /// Generic catch in `VideoInteractionsBloc._publishLike`.
  static const String publishLike = '_publishLike';

  /// Generic catch in `VideoInteractionsBloc._publishRepost`.
  static const String publishRepost = '_publishRepost';
}
