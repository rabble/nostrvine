// ABOUTME: Per-feature Reportable `context:` constants for CommentsListBloc.
// ABOUTME: See .claude/rules/error_handling.md — once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [CommentsListBloc].
abstract class CommentsListBlocReportableSites {
  static const String onLoadRequested = '_onLoadRequested';
  static const String onLoadMoreRequested = '_onLoadMoreRequested';
  static const String startWatchingComments = '_startWatchingComments';
}
