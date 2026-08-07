// ABOUTME: Tests for the sync index payload envelope.
// ABOUTME: Covers item/tombstone round-trips and version rejection.

import 'package:creator_sync/creator_sync.dart';
import 'package:test/test.dart';

void main() {
  group(SyncIndexEntry, () {
    test('round-trips an item payload', () {
      final entry = SyncIndexEntry.item(
        body: const {
          'audio': {'id': 'abc'},
          'personalLabel': 'intro',
        },
      );

      final decoded = SyncIndexEntry.fromPayloadJson(entry.toPayloadJson());

      expect(decoded.deleted, isFalse);
      expect(decoded.body, equals(entry.body));
    });

    test('round-trips a tombstone', () {
      final decoded = SyncIndexEntry.fromPayloadJson(
        SyncIndexEntry.tombstone().toPayloadJson(),
      );

      expect(decoded.deleted, isTrue);
      expect(decoded.body, isNull);
    });

    test('stamps the current schema version', () {
      expect(
        SyncIndexEntry.item(body: const {}).toPayloadJson(),
        contains('"v":${SyncIndexEntry.schemaVersion}'),
      );
    });

    test('throws on a newer schema version', () {
      expect(
        () => SyncIndexEntry.fromPayloadJson('{"v":999,"deleted":false}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on malformed json', () {
      expect(
        () => SyncIndexEntry.fromPayloadJson('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when an item payload has no body', () {
      expect(
        () => SyncIndexEntry.fromPayloadJson('{"v":1,"deleted":false}'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
