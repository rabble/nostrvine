import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(MutualMuteRule, () {
    const rule = MutualMuteRule();

    test('id is stable', () {
      expect(rule.id, equals('MutualMuteRule'));
    });

    test('blocks authors in pubkeysBlockingUs', () {
      const state = ContentPolicyState(
        currentUserPubkey: 'me',
        mutedPubkeys: {},
        blockedPubkeys: {},
        pubkeysBlockingUs: {'blocker'},
        pubkeysMutingUs: {},
      );
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'blocker'),
        state,
      );
      expect(decision, isA<Block>());
      expect((decision as Block).ruleId, equals('MutualMuteRule'));
    });

    test('blocks authors in pubkeysMutingUs', () {
      const state = ContentPolicyState(
        currentUserPubkey: 'me',
        mutedPubkeys: {},
        blockedPubkeys: {},
        pubkeysBlockingUs: {},
        pubkeysMutingUs: {'muter'},
      );
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'muter'),
        state,
      );
      expect(decision, isA<Block>());
    });

    test('allows authors not in either mutual-mute set', () {
      final state = ContentPolicyState.empty();
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'stranger'),
        state,
      );
      expect(decision, isA<Allow>());
    });
  });
}
