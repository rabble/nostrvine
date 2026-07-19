// ABOUTME: Verifies EventMemBox collection ownership at query boundaries.
// ABOUTME: Prevents completed result lists from changing with later box writes.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event_mem_box.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group(EventMemBox, () {
    test('all returns a snapshot that is stable after later additions', () {
      const pubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final first = Event(
        pubkey,
        EventKind.textNote,
        [],
        'first',
        createdAt: 1,
      );
      final second = Event(
        pubkey,
        EventKind.textNote,
        [],
        'second',
        createdAt: 2,
      );
      final box = EventMemBox(sortAfterAdd: false)..add(first);

      final completedResult = box.all();
      box.add(second);

      expect(completedResult, equals([first]));
      expect(box.all(), equals([first, second]));
    });
  });
}
