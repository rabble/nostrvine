import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(PubkeyMuteRule, () {
    const rule = PubkeyMuteRule();

    test('id is stable', () {
      expect(rule.id, equals('PubkeyMuteRule'));
    });

    test('blocks authors present in mutedPubkeys', () {
      const state = ContentPolicyState(
        currentUserPubkey: 'me',
        mutedPubkeys: {'muted'},
        blockedPubkeys: {},
        pubkeysBlockingUs: {},
        pubkeysMutingUs: {},
      );
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'muted'),
        state,
      );
      expect(decision, isA<Block>());
      expect((decision as Block).ruleId, equals('PubkeyMuteRule'));
    });

    test('allows authors not in mutedPubkeys', () {
      const state = ContentPolicyState(
        currentUserPubkey: 'me',
        mutedPubkeys: {'muted'},
        blockedPubkeys: {},
        pubkeysBlockingUs: {},
        pubkeysMutingUs: {},
      );
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'not-muted'),
        state,
      );
      expect(decision, isA<Allow>());
    });
  });
}
