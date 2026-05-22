// ABOUTME: Per-feature Reportable `context:` constants for CommentComposerBloc.
// ABOUTME: See .claude/rules/error_handling.md — once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [CommentComposerBloc].
abstract class CommentComposerBlocReportableSites {
  static const String onSubmitted = '_onSubmitted';
  static const String resolveCommentMentions = '_resolveCommentMentions';
  static const String onEditSubmitted = '_onEditSubmitted';
  static const String onMentionSearchRequested = '_onMentionSearchRequested';
}
