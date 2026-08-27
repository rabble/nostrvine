// ABOUTME: Tests for dmPeerName - the single naming precedence every DM
// ABOUTME: surface resolves a conversation peer through.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/config/official_accounts.dart';

const _labels = DmPeerLabels(
  deletedAccount: 'Deleted account',
  moderation: 'Divine Moderation',
);

const _ordinaryPubkey =
    'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5';

void main() {
  group(dmPeerName, () {
    group('precedence', () {
      test('vanished outranks every other branch', () {
        expect(
          dmPeerName(
            pubkeyHex: kModerationPubkeyHex,
            isVanished: true,
            labels: _labels,
            profileName: 'Kind Zero Name',
            displayNameOverride: 'Override',
          ),
          equals(_labels.deletedAccount),
        );
      });

      test('the override outranks moderation and the profile', () {
        expect(
          dmPeerName(
            pubkeyHex: kModerationPubkeyHex,
            isVanished: false,
            labels: _labels,
            profileName: 'Kind Zero Name',
            displayNameOverride: 'Override',
          ),
          equals('Override'),
        );
      });

      test('moderation outranks the profile', () {
        expect(
          dmPeerName(
            pubkeyHex: kModerationPubkeyHex,
            isVanished: false,
            labels: _labels,
            profileName: 'Kind Zero Name',
          ),
          equals(_labels.moderation),
        );
      });

      test('the profile outranks the generated fallback', () {
        expect(
          dmPeerName(
            pubkeyHex: _ordinaryPubkey,
            isVanished: false,
            labels: _labels,
            profileName: 'Kind Zero Name',
          ),
          equals('Kind Zero Name'),
        );
      });

      test('the generated fallback answers when nothing else does', () {
        expect(
          dmPeerName(
            pubkeyHex: _ordinaryPubkey,
            isVanished: false,
            labels: _labels,
          ),
          equals(UserProfile.defaultDisplayNameFor(_ordinaryPubkey)),
        );
      });
    });

    group('moderation keys', () {
      // A rotated-away key has no kind 0 at all, so without this branch the
      // row falls through to a generated handle and an enforcement thread
      // reads as a stranger.
      test('answers for a retired key, not only the current one', () {
        final retired = kLegacyModerationPubkeys.first;

        expect(
          dmPeerName(
            pubkeyHex: retired,
            isVanished: false,
            labels: _labels,
          ),
          equals(_labels.moderation),
        );
      });

      test('leaves an ordinary pubkey alone', () {
        expect(
          dmPeerName(
            pubkeyHex: _ordinaryPubkey,
            isVanished: false,
            labels: _labels,
          ),
          isNot(equals(_labels.moderation)),
        );
      });
    });
  });

  group(DmPeerLabels, () {
    test('compares by value, so a redelivery of the same copy is a no-op', () {
      expect(
        const DmPeerLabels(deletedAccount: 'a', moderation: 'b'),
        equals(const DmPeerLabels(deletedAccount: 'a', moderation: 'b')),
      );
    });

    test('differs when the locale changes the copy', () {
      expect(
        const DmPeerLabels(deletedAccount: 'a', moderation: 'b'),
        isNot(equals(const DmPeerLabels(deletedAccount: 'z', moderation: 'b'))),
      );
    });
  });
}
