/// Outcome of evaluating a single policy input against the engine.
///
/// The sealed hierarchy lets callers pattern-match exhaustively without
/// default cases. New decision variants (SoftHide, Warn) can be added
/// later; Phase 1 ships only Allow and Block.
sealed class PolicyDecision {
  /// Const base constructor for the sealed hierarchy.
  const PolicyDecision();
}

/// Content is permitted to be parsed into an in-app model.
final class Allow extends PolicyDecision {
  /// Creates an [Allow] decision.
  const Allow();
}

/// Content must be dropped.
///
/// [ruleId] is for local diagnostics only — it must never appear in
/// user-visible copy, release logs, remote telemetry, Crashlytics
/// breadcrumbs, or analytics events.
final class Block extends PolicyDecision {
  /// Creates a [Block] decision with a diagnostic [ruleId].
  const Block({required this.ruleId});

  /// Identifier of the rule that produced this decision. Debug-only.
  final String ruleId;
}
