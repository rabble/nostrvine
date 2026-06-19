// ABOUTME: Crashlytics triage site identifiers for InlineReelReplyCubit.

/// Reportable-site identifiers for [InlineReelReplyCubit] (per
/// `rules/error_handling.md`). Only programming-invariant failures are
/// wrapped with `Reportable`; network/IO/validation failures are not.
abstract class InlineReelReplyReportableSites {
  /// The reply submit path.
  static const submit = 'submit';
}
