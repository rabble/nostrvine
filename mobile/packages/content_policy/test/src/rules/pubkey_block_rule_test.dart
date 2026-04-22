import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(PubkeyBlockRule, () {
    const rule = PubkeyBlockRule();

    test('id is stable', () {
      expect(rule.id, equals('PubkeyBlockRule'));
    });

    test('blocks authors present in blockedPubkeys', () {
      const state = ContentPolicyState(
        currentUserPubkey: 'me',
        mutedPubkeys: {},
        blockedPubkeys: {'blocked'},
        pubkeysBlockingUs: {},
        pubkeysMutingUs: {},
      );
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'blocked'),
        state,
      );
      expect(decision, isA<Block>());
      expect((decision as Block).ruleId, equals('PubkeyBlockRule'));
    });

    test('allows authors not in blockedPubkeys', () {
      final state = ContentPolicyState.empty();
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'anyone'),
        state,
      );
      expect(decision, isA<Allow>());
    });
  });
}
