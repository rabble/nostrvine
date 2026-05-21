// ABOUTME: Per-feature Reportable `context:` constants for DM-area Blocs.
// ABOUTME: See .claude/rules/error_handling.md — once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [ConversationBloc].
///
/// Per the convention in `.claude/rules/error_handling.md`, when a Bloc
/// has more than one `addError(Reportable(e, context: ...))` site, the
/// `context:` strings are lifted into a per-feature constants class so
/// the Crashlytics dashboard groups them by stable identifier rather
/// than inline string literals.
abstract class ConversationBlocReportableSites {
  /// `_onSelfWrapRecoveryRequested`: non-`ArgumentError` throw from
  /// `DmRepository.recoverSelfWrap` (missing DAO wiring is the
  /// invariant-violation example).
  static const String onSelfWrapRecoveryRequested =
      '_onSelfWrapRecoveryRequested';

  /// `_onMessageDeleted`: non-`ArgumentError` throw from
  /// `DmRepository.deleteMessageForEveryone` — typically the
  /// `StateError('Failed to sign kind 5 deletion event')` invariant.
  static const String onMessageDeleted = '_onMessageDeleted';
}
