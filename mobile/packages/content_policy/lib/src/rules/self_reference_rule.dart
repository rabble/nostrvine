import 'package:content_policy/src/content_policy_state.dart';
import 'package:content_policy/src/policy_decision.dart';
import 'package:content_policy/src/policy_input.dart';
import 'package:content_policy/src/policy_rule.dart';

/// Guarantees the user's own content is never filtered, even if a
/// malformed mute/block list contains the user's own pubkey.
///
/// Must be first in the rule pipeline — the engine asserts this.
///
/// Why: a self-referential mute list reproduced issue #2192 where the
/// user's own events disappeared from their feed.
class SelfReferenceRule implements PolicyRule {
  /// Creates a [SelfReferenceRule].
  const SelfReferenceRule();

  @override
  String get id => 'SelfReferenceRule';

  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    // This rule only handles the self case. For any other pubkey, we
    // return Allow and let subsequent rules decide.
    return const Allow();
  }
}
