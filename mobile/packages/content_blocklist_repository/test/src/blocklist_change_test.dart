import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(BlocklistChange, () {
    const change = BlocklistChange(pubkey: 'p1', op: BlocklistOp.blocked);

    test('equality is structural over pubkey + op', () {
      const same = BlocklistChange(pubkey: 'p1', op: BlocklistOp.blocked);
      const diffPubkey = BlocklistChange(
        pubkey: 'p2',
        op: BlocklistOp.blocked,
      );
      const diffOp = BlocklistChange(pubkey: 'p1', op: BlocklistOp.muted);

      expect(change, equals(same));
      expect(change, isNot(equals(diffPubkey)));
      expect(change, isNot(equals(diffOp)));
      expect(change, equals(change));
      expect(change, isNot(equals(Object())));
    });

    test('hashCode is consistent with equality', () {
      const same = BlocklistChange(pubkey: 'p1', op: BlocklistOp.blocked);
      const diff = BlocklistChange(pubkey: 'p1', op: BlocklistOp.muted);

      expect(change.hashCode, equals(same.hashCode));
      expect(change.hashCode, isNot(equals(diff.hashCode)));
    });

    test('toString includes pubkey and op', () {
      expect(
        change.toString(),
        equals('BlocklistChange(pubkey: p1, op: BlocklistOp.blocked)'),
      );
    });
  });
}
