import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(ContentPolicyEngine, () {
    const me = 'me';

    group('evaluate', () {
      test('returns Allow when no rule blocks', () {
        final engine = ContentPolicyEngine.defaultRules();
        final decision = engine.evaluate(
          const PolicyInput(pubkey: 'stranger'),
          ContentPolicyState.empty(),
        );
        expect(decision, isA<Allow>());
      });

      test('returns Block when the first applicable rule blocks', () {
        final engine = ContentPolicyEngine.defaultRules();
        const state = ContentPolicyState(
          currentUserPubkey: me,
          mutedPubkeys: {'muted'},
          blockedPubkeys: {},
          pubkeysBlockingUs: {},
          pubkeysMutingUs: {},
        );
        final decision = engine.evaluate(
          const PolicyInput(pubkey: 'muted'),
          state,
        );
        expect(decision, isA<Block>());
        expect((decision as Block).ruleId, equals('PubkeyMuteRule'));
      });

      test('short-circuits on first Block — later rules do not run', () {
        var secondRuleRan = false;
        final engine = ContentPolicyEngine([
          const SelfReferenceRule(),
          const _AlwaysBlockRule('first'),
          _SpyRule(() => secondRuleRan = true),
        ]);
        final decision = engine.evaluate(
          const PolicyInput(pubkey: 'x'),
          ContentPolicyState.empty(),
        );
        expect(decision, isA<Block>());
        expect((decision as Block).ruleId, equals('first'));
        expect(secondRuleRan, isFalse);
      });

      test(
        'SelfReferenceRule short-circuits even when a later rule would block',
        () {
          final engine = ContentPolicyEngine.defaultRules();
          const state = ContentPolicyState(
            currentUserPubkey: me,
            mutedPubkeys: {me},
            blockedPubkeys: {me},
            pubkeysBlockingUs: {me},
            pubkeysMutingUs: {me},
          );
          final decision = engine.evaluate(
            const PolicyInput(pubkey: me),
            state,
          );
          expect(decision, isA<Allow>());
        },
      );
    });

    group('construction invariants', () {
      test('defaultRules places SelfReferenceRule first', () {
        final engine = ContentPolicyEngine.defaultRules();
        expect(engine.rules.first, isA<SelfReferenceRule>());
      });

      test('asserts when SelfReferenceRule is not first', () {
        expect(
          () => ContentPolicyEngine([
            const PubkeyMuteRule(),
            const SelfReferenceRule(),
          ]),
          throwsA(isA<AssertionError>()),
        );
      });

      test('allows custom rule lists so long as SelfReferenceRule leads', () {
        expect(
          () => ContentPolicyEngine([
            const SelfReferenceRule(),
            const _AlwaysBlockRule('custom'),
          ]),
          returnsNormally,
        );
      });
    });

    group('canTarget', () {
      test('returns true when pubkey is not in isBlockedBy', () {
        final engine = ContentPolicyEngine.defaultRules();
        expect(
          engine.canTarget('stranger', ContentPolicyState.empty()),
          isTrue,
        );
      });

      test('returns false when pubkey blocks us', () {
        final engine = ContentPolicyEngine.defaultRules();
        const state = ContentPolicyState(
          currentUserPubkey: me,
          mutedPubkeys: {},
          blockedPubkeys: {},
          pubkeysBlockingUs: {'blocker'},
          pubkeysMutingUs: {},
        );
        expect(engine.canTarget('blocker', state), isFalse);
      });

      test('returns false when pubkey muted us', () {
        final engine = ContentPolicyEngine.defaultRules();
        const state = ContentPolicyState(
          currentUserPubkey: me,
          mutedPubkeys: {},
          blockedPubkeys: {},
          pubkeysBlockingUs: {},
          pubkeysMutingUs: {'muter'},
        );
        expect(engine.canTarget('muter', state), isFalse);
      });

      test('does not run the full rule pipeline', () {
        final engine = ContentPolicyEngine([
          const SelfReferenceRule(),
          _ExplodingRule(),
        ]);
        expect(
          () => engine.canTarget('anyone', ContentPolicyState.empty()),
          returnsNormally,
        );
      });
    });
  });
}

class _AlwaysBlockRule implements PolicyRule {
  const _AlwaysBlockRule(this._id);
  final String _id;

  @override
  String get id => _id;

  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) =>
      Block(ruleId: id);
}

class _SpyRule implements PolicyRule {
  _SpyRule(this.onEvaluate);
  final void Function() onEvaluate;

  @override
  String get id => 'SpyRule';

  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    onEvaluate();
    return const Allow();
  }
}

class _ExplodingRule implements PolicyRule {
  @override
  String get id => 'ExplodingRule';

  @override
  PolicyDecision evaluate(PolicyInput input, ContentPolicyState state) {
    throw StateError('should not run');
  }
}
