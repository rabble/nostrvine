// ABOUTME: Per-feature Reportable `context:` constants for CommentReactionsBloc.
// ABOUTME: See .claude/rules/error_handling.md — once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [CommentReactionsBloc].
abstract class CommentReactionsBlocReportableSites {
  static const String onVoteToggled = '_onVoteToggled';
  static const String onVoteCountsFetchRequested =
      '_onVoteCountsFetchRequested';
  static const String onReportRequested = '_onReportRequested';
  static const String onBlockUserRequested = '_onBlockUserRequested';
  static const String onDeleteRequested = '_onDeleteRequested';
}
