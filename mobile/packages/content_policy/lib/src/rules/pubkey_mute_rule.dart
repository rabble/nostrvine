import 'package:content_policy/src/content_policy_state.dart';
import 'package:content_policy/src/policy_decision.dart';
import 'package:content_policy/src/policy_input.dart';
import 'package:content_policy/src/policy_rule.dart';

/// Blocks content from authors the user muted via kind 10000.
class PubkeyMuteRule implements PolicyRule {
  /// Creates a [PubkeyMuteRule].
  const PubkeyMuteRule();

  @override
  String get id => 'PubkeyMuteRule';

  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    if (state.mutedPubkeys.contains(input.pubkey)) {
      return Block(ruleId: id);
    }
    return const Allow();
  }
}
