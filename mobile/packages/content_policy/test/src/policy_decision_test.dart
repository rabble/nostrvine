// The exhaustiveness test intentionally switches on a narrowed Block value to
// verify both arms compile. The Allow arm is unreachable by design.
// ignore_for_file: pattern_never_matches_value_type
import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(PolicyDecision, () {
    test('Allow is a PolicyDecision', () {
      const decision = Allow();
      expect(decision, isA<PolicyDecision>());
    });

    test('Block carries a ruleId', () {
      const decision = Block(ruleId: 'PubkeyMuteRule');
      expect(decision.ruleId, equals('PubkeyMuteRule'));
      expect(decision, isA<PolicyDecision>());
    });

    test('pattern matches exhaustively', () {
      PolicyDecision decision = const Allow();
      final label = switch (decision) {
        Allow() => 'allow',
        Block() => 'block',
      };
      expect(label, equals('allow'));

      decision = const Block(ruleId: 'r');
      final label2 = switch (decision) {
        Allow() => 'allow',
        Block() => 'block',
      };
      expect(label2, equals('block'));
    });
  });
}
