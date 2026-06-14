// ABOUTME: Per-feature Reportable `context:` constants for NotificationFeedBloc.
// ABOUTME: See .claude/rules/error_handling.md — once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [NotificationFeedBloc].
///
/// Per the convention in `.claude/rules/error_handling.md`, when a Bloc
/// has more than one `addError(Reportable(e, context: ...))` site, the
/// `context:` strings are lifted into a per-feature constants class so
/// the Crashlytics dashboard groups them by stable identifier rather
/// than inline string literals.
abstract class NotificationFeedBlocReportableSites {
  /// `_onStarted` generic-catch arm — `Error` types that escape
  /// `NotificationRepository.refresh`'s `on Exception` propagation.
  /// Includes the defensive `StateError('retry exhausted')` from
  /// `_fetchWithRetry` if the analyzer's loop invariant ever breaks.
  static const String onStarted = '_onStarted';

  /// `_markSeenOnOpen` generic-catch arm — `Error` types that escape
  /// `NotificationRepository.markAllAsRead`'s rollback `catch (_)` rethrow
  /// when the notifications surface advances the seen watermark on open.
  /// Realistically a Drift DAO `TypeError` from a row-shape mismatch.
  static const String markSeenOnOpen = '_markSeenOnOpen';

  /// `_onLoadMore` generic-catch arm — `Error` types that escape
  /// `NotificationRepository.getNotifications`'s `on Exception`
  /// propagation. Single-attempt paginate has no retry, so the
  /// realistic source is a Drift schema-mismatch `TypeError`.
  static const String onLoadMore = '_onLoadMore';

  /// `_onRefreshed` generic-catch arm — same coverage as [onStarted],
  /// dispatched from pull-to-refresh. Kept distinct from [onStarted] so
  /// the Crashlytics dashboard distinguishes initial-load failures from
  /// refresh failures (different user actions, different recovery UX).
  static const String onRefreshed = '_onRefreshed';

  /// `_onItemTapped` generic-catch arm — `Error` types that escape
  /// `NotificationRepository.markAsRead`'s rollback `catch (_)` rethrow.
  /// Realistically a Drift DAO `TypeError` from a row-shape mismatch.
  static const String onItemTapped = '_onItemTapped';

  /// `_onFollowBack` generic-catch arm — `Error` types that escape
  /// `FollowRepository.follow`'s Exception-only throws, plus a
  /// hypothetical `TypeError` from the post-await `_applyFollowState`
  /// transform (impossible under the current pure-`copyWith` shape; the
  /// wrap is defence-in-depth).
  static const String onFollowBack = '_onFollowBack';
}
