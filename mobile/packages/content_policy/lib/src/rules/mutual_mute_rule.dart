import 'package:content_policy/src/content_policy_state.dart';
import 'package:content_policy/src/policy_decision.dart';
import 'package:content_policy/src/policy_input.dart';
import 'package:content_policy/src/policy_rule.dart';

/// Blocks content from authors whose own mute/block list names the
/// current user. Enforces the mutual-mute guarantee: if they don't
/// want our content, we don't show theirs.
class MutualMuteRule implements PolicyRule {
  /// Creates a [MutualMuteRule].
  const MutualMuteRule();

  @override
  String get id => 'MutualMuteRule';

  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    if (state.isBlockedBy(input.pubkey)) {
      return Block(ruleId: id);
    }
    return const Allow();
  }
}
