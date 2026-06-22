import 'package:content_policy/src/content_policy_state.dart';
import 'package:content_policy/src/policy_decision.dart';
import 'package:content_policy/src/policy_input.dart';
import 'package:content_policy/src/policy_rule.dart';

/// Blocks content from authors the user blocked in-app (published onto
/// their kind 10000 mute list, plus the legacy kind 30000 d=block list).
class PubkeyBlockRule implements PolicyRule {
  /// Creates a [PubkeyBlockRule].
  const PubkeyBlockRule();

  @override
  String get id => 'PubkeyBlockRule';

  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    if (state.blockedPubkeys.contains(input.pubkey)) {
      return Block(ruleId: id);
    }
    return const Allow();
  }
}
