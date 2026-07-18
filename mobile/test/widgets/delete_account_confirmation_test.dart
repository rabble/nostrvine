// ABOUTME: Unit tests for DeleteAccountConfirmation token derivation + matching
// ABOUTME: Covers Divine handle, external handle, and no-handle (DELETE) cases

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';

void main() {
  const pubkeyHex =
      '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

  group(DeleteAccountConfirmation, () {
    group('Divine handle', () {
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'Rabble',
        avatarUrl: null,
        handle: '@rabble.divine.video',
      );

      test('is a username confirmation with the full handle as token', () {
        expect(c.isUsernameConfirmation, isTrue);
        expect(c.requiredToken, equals('@rabble.divine.video'));
        expect(c.identifierLine, equals('@rabble.divine.video'));
      });

      test('matches the exact handle, @-less, and cased forms', () {
        expect(c.matches('@rabble.divine.video'), isTrue);
        expect(c.matches('rabble.divine.video'), isTrue);
        expect(c.matches('  @RABBLE.DIVINE.VIDEO  '), isTrue);
      });

      test('does not match the bare local part or DELETE', () {
        expect(c.matches('rabble'), isFalse);
        expect(c.matches('@rabble'), isFalse);
        expect(c.matches('DELETE'), isFalse);
      });
    });

    group('external handle', () {
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'Alice',
        avatarUrl: null,
        handle: 'alice@example.com',
      );

      test('uses the external handle as token, case-insensitively', () {
        expect(c.isUsernameConfirmation, isTrue);
        expect(c.requiredToken, equals('alice@example.com'));
        expect(c.matches('ALICE@example.com'), isTrue);
        expect(c.matches('alice@example.com '), isTrue);
      });
    });

    group('no handle', () {
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'Wild Otter 7',
        avatarUrl: null,
        handle: null,
      );

      test('falls back to DELETE and shows a truncated npub', () {
        expect(c.isUsernameConfirmation, isFalse);
        expect(c.requiredToken, equals('DELETE'));
        expect(c.identifierLine, startsWith('npub1'));
      });

      test('matches DELETE case-insensitively and trimmed, not a handle', () {
        expect(c.matches('delete'), isTrue);
        expect(c.matches('  DELETE '), isTrue);
        expect(c.matches('rabble.divine.video'), isFalse);
      });
    });

    test('empty handle is treated as no handle', () {
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'X',
        avatarUrl: null,
        handle: '',
      );
      expect(c.isUsernameConfirmation, isFalse);
      expect(c.requiredToken, equals('DELETE'));
    });

    test('a handle that normalizes to empty falls back to DELETE', () {
      // Malformed nip05 like "_@" renders displayNip05 as "@", which strips to
      // empty — must not enable the gate on empty input.
      final c = DeleteAccountConfirmation(
        pubkeyHex: pubkeyHex,
        displayName: 'X',
        avatarUrl: null,
        handle: '@',
      );
      expect(c.isUsernameConfirmation, isFalse);
      expect(c.requiredToken, equals('DELETE'));
      expect(c.matches(''), isFalse);
      expect(c.matches('DELETE'), isTrue);
    });
  });
}
