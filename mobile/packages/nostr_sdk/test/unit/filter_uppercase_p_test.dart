// ABOUTME: Unit tests for NIP-22 uppercase P tag filtering.
// ABOUTME: Covers serialization, deserialization, and local matching.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('Filter uppercase P tag', () {
    test('serializes uppercase P to #P', () {
      final filter = Filter(kinds: [EventKind.comment], uppercaseP: ['alice']);

      expect(filter.toJson(), containsPair('#P', ['alice']));
    });

    test('deserializes uppercase P from #P', () {
      final filter = Filter.fromJson({
        'kinds': [EventKind.comment],
        '#P': ['alice'],
      });

      expect(filter.uppercaseP, equals(['alice']));
    });

    test('matches events with uppercase P tag', () {
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        EventKind.comment,
        [
          ['P', 'alice'],
        ],
        'comment',
      );
      final matching = Filter(
        kinds: [EventKind.comment],
        uppercaseP: ['alice'],
      );
      final nonMatching = Filter(
        kinds: [EventKind.comment],
        uppercaseP: ['bob'],
      );

      expect(matching.checkEvent(event), isTrue);
      expect(nonMatching.checkEvent(event), isFalse);
    });
  });
}
