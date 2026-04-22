import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(SelfReferenceRule, () {
    const rule = SelfReferenceRule();
    const me = 'me-pubkey';

    const stateWithMeInEveryList = ContentPolicyState(
      currentUserPubkey: me,
      mutedPubkeys: {me},
      blockedPubkeys: {me},
      pubkeysBlockingUs: {me},
      pubkeysMutingUs: {me},
    );

    test('id matches class name', () {
      expect(rule.id, equals('SelfReferenceRule'));
    });

    test('allows the current user even if every list contains them', () {
      final decision = rule.evaluate(
        const PolicyInput(pubkey: me),
        stateWithMeInEveryList,
      );
      expect(decision, isA<Allow>());
    });

    test('allows any author when no user is authenticated', () {
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'anyone'),
        ContentPolicyState.empty(),
      );
      expect(decision, isA<Allow>());
    });

    test('returns Allow (not short-circuit Block) for a different pubkey', () {
      // Self rule only handles the self case. Other rules decide for others.
      final decision = rule.evaluate(
        const PolicyInput(pubkey: 'someone-else'),
        stateWithMeInEveryList,
      );
      expect(decision, isA<Allow>());
    });
  });
}
