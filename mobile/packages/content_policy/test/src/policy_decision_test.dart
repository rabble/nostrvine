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

    test('pattern matches exhaustively on Allow', () {
      const PolicyDecision decision = Allow();
      final label = switch (decision) {
        Allow() => 'allow',
        Block() => 'block',
      };
      expect(label, equals('allow'));
    });

    test('pattern matches exhaustively on Block', () {
      const PolicyDecision decision = Block(ruleId: 'r');
      final label = switch (decision) {
        Allow() => 'allow',
        Block() => 'block',
      };
      expect(label, equals('block'));
    });
  });
}
