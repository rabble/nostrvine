import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(PolicyInput, () {
    test('constructs with only pubkey', () {
      const input = PolicyInput(pubkey: 'abc');
      expect(input.pubkey, equals('abc'));
      expect(input.kind, isNull);
      expect(input.content, isNull);
      expect(input.tags, isNull);
    });

    test('constructs with all fields', () {
      const input = PolicyInput(
        pubkey: 'abc',
        kind: 34236,
        content: 'hello',
        tags: [
          ['d', 'video-1'],
        ],
      );
      expect(input.pubkey, equals('abc'));
      expect(input.kind, equals(34236));
      expect(input.content, equals('hello'));
      expect(input.tags, hasLength(1));
    });
  });
}
