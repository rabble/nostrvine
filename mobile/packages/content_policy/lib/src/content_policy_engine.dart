import 'package:content_policy/src/content_policy_state.dart';
import 'package:content_policy/src/policy_decision.dart';
import 'package:content_policy/src/policy_input.dart';
import 'package:content_policy/src/policy_rule.dart';
import 'package:content_policy/src/rules/mutual_mute_rule.dart';
import 'package:content_policy/src/rules/pubkey_block_rule.dart';
import 'package:content_policy/src/rules/pubkey_mute_rule.dart';
import 'package:content_policy/src/rules/self_reference_rule.dart';

/// Evaluates content against an ordered pipeline of [PolicyRule]s and
/// answers interaction-gating queries via [canTarget].
///
/// The engine is stateless. [evaluate] takes a fresh [ContentPolicyState]
/// snapshot on every call; rebuild the snapshot upstream, don't mutate.
class ContentPolicyEngine {
  /// Construct with an explicit rule list. [SelfReferenceRule] must be
  /// at position 0 or an [AssertionError] is thrown.
  ContentPolicyEngine(this.rules)
    : assert(
        rules.isNotEmpty && rules.first is SelfReferenceRule,
        'SelfReferenceRule must be first in the pipeline. '
        'It guarantees the user is never filtered by a malformed list.',
      );

  /// The canonical Phase 1 rule set.
  factory ContentPolicyEngine.defaultRules() => ContentPolicyEngine(const [
    SelfReferenceRule(),
    PubkeyMuteRule(),
    PubkeyBlockRule(),
    MutualMuteRule(),
  ]);

  /// Ordered list of rules the engine evaluates on every call.
  final List<PolicyRule> rules;

  /// Runs [input] through the pipeline and returns the first [Block]
  /// decision, or [Allow] if no rule blocks.
  ///
  /// Short-circuits on first [Block]; later rules do not run.
  /// [SelfReferenceRule] (always first) also short-circuits to [Allow]
  /// when the input pubkey matches the current user, preventing any
  /// subsequent rule from filtering the user's own content.
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    for (final rule in rules) {
      final decision = rule.evaluate(input, state);
      if (decision is Block) return decision;
      // SelfReferenceRule is first and returns Allow for the user's own
      // pubkey. When it does, no further rules should run — self-content
      // is unconditionally permitted even if later rules would block it.
      if (rule is SelfReferenceRule &&
          state.currentUserPubkey != null &&
          input.pubkey == state.currentUserPubkey) {
        return const Allow();
      }
    }
    return const Allow();
  }

  /// Answers: should the UI offer an interaction that targets [pubkey]?
  ///
  /// Returns `false` when [pubkey] has a mute/block entry naming the
  /// current user. Callers MUST translate this to *absence* of the
  /// affordance, not a disabled state with explanation.
  ///
  /// This query bypasses the full rule pipeline. It's a specific
  /// question with a specific answer; routing it through [evaluate]
  /// would give the caller a [Block.ruleId] they must not expose.
  bool canTarget(String pubkey, ContentPolicyState state) {
    return !state.isBlockedBy(pubkey);
  }
}
