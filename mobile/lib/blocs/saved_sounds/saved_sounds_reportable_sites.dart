// ABOUTME: Per-feature Reportable `context:` constants for SavedSoundsBloc.
// ABOUTME: See .claude/rules/error_handling.md - once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [SavedSoundsBloc]'s sync-mirror call sites.
///
/// Per the convention in `.claude/rules/error_handling.md`, when a feature
/// has more than one `addError(Reportable(e, context: ...))` site, the
/// `context:` strings are lifted into a per-feature constants class so the
/// Crashlytics dashboard groups them by stable identifier rather than
/// inline string literals.
abstract class SavedSoundsReportableSites {
  /// Unexpected failure mirroring a new save to the sync repository.
  static const String mirrorSave = '_mirror(_save)';

  /// Unexpected failure mirroring a personal-details edit.
  static const String mirrorEdit = '_mirror(_edit)';

  /// Unexpected failure mirroring a tombstone for a removed sound.
  static const String mirrorRemove = '_mirror(_remove)';

  /// Unexpected failure mirroring waveform-enrichment results.
  static const String mirrorProbe = '_mirror(_applyProbe)';
}
