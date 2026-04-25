import 'package:content_policy/src/content_policy_state.dart';
import 'package:content_policy/src/policy_decision.dart';
import 'package:content_policy/src/policy_input.dart';

/// A single, pure, synchronous check in the policy pipeline.
///
/// Rules must be deterministic: same input + same state always produces
/// the same decision. No IO, no async, no mutation.
abstract interface class PolicyRule {
  /// Stable identifier used in [Block.ruleId] and in the engine's
  /// ordering assertion. Must match the class name by convention.
  String get id;

  /// Evaluate the rule. Return [Allow] to let the pipeline continue,
  /// [Block] to short-circuit with a drop decision.
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state);
}
