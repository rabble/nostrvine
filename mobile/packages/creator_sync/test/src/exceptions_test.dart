// ABOUTME: Tests for the creator_sync package's typed exceptions.
// ABOUTME: Pins the message contract each exception's toString() exposes.

import 'package:creator_sync/creator_sync.dart';
import 'package:test/test.dart';

void main() {
  group(SyncDecryptException, () {
    test('toString includes the message', () {
      final exception = SyncDecryptException('payload failed authentication');

      expect(
        exception.toString(),
        equals('SyncDecryptException: payload failed authentication'),
      );
    });
  });

  group(VaultKeyUnavailableException, () {
    test('toString includes the message', () {
      final exception = VaultKeyUnavailableException('signer unreachable');

      expect(
        exception.toString(),
        equals('VaultKeyUnavailableException: signer unreachable'),
      );
    });
  });

  group(SyncIndexException, () {
    test('toString includes the message', () {
      final exception = SyncIndexException('relay rejected the event');

      expect(
        exception.toString(),
        equals('SyncIndexException: relay rejected the event'),
      );
    });
  });
}
