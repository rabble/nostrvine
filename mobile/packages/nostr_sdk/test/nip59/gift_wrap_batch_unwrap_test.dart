import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip59/gift_wrap_batch_unwrap.dart';

void main() {
  group(GiftWrapUnwrapSlot, () {
    test('success carries the rumor and authenticated sender', () {
      const sender =
          '0000000000000000000000000000000000000000000000000000000000000001';
      final rumor = {'kind': 14, 'content': 'hi'};

      final slot = GiftWrapUnwrapSlot.success(rumor: rumor, sender: sender);

      expect(slot.isSuccess, isTrue);
      expect(slot.rumor, same(rumor));
      expect(slot.sender, sender);
      expect(slot.error, isNull);
    });

    test('failure carries the error code and is not a success', () {
      const slot = GiftWrapUnwrapSlot.failure('sender_mismatch');

      expect(slot.isSuccess, isFalse);
      expect(slot.error, 'sender_mismatch');
      expect(slot.rumor, isNull);
      expect(slot.sender, isNull);
    });
  });
}
