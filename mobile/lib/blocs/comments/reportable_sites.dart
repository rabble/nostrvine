// ABOUTME: Per-feature Reportable `context:` constants for CommentsBloc.
// ABOUTME: See .claude/rules/error_handling.md — once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [CommentsBloc].
abstract class CommentsBlocReportableSites {
  static const String onLoadRequested = '_onLoadRequested';
  static const String onLoadMoreRequested = '_onLoadMoreRequested';
  static const String onSubmitted = '_onSubmitted';
  static const String resolveCommentMentions = '_resolveCommentMentions';
  static const String onDeleteRequested = '_onDeleteRequested';
  static const String onVoteCountsFetchRequested =
      '_onVoteCountsFetchRequested';
  static const String onVoteToggled = '_onVoteToggled';
  static const String onReportRequested = '_onReportRequested';
  static const String onBlockUserRequested = '_onBlockUserRequested';
  static const String onEditSubmitted = '_onEditSubmitted';
  static const String onMentionSearchRequested = '_onMentionSearchRequested';
  static const String startWatchingComments = '_startWatchingComments';
}
