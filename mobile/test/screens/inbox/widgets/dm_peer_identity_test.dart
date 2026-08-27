// ABOUTME: Tests the shared DM peer identity resolution order.
// ABOUTME: Pins vanished, override, moderation, profile, and fallback branches.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Widget buildSubject(String Function(BuildContext context) resolve) {
    return testMaterialApp(
      home: Builder(
        builder: (context) => Text(resolve(context)),
      ),
    );
  }

  group('dmPeerDisplayName', () {
    testWidgets('vanished state wins over every identity branch', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmPeerDisplayName(
            context,
            pubkeyHex: kModerationPubkeyHex,
            isVanished: true,
            displayNameOverride: 'Override',
            profile: _profile(kModerationPubkeyHex, 'Profile'),
          ),
        ),
      );

      expect(find.text('Deleted account'), findsOneWidget);
    });

    testWidgets('override wins over moderation and profile', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmPeerDisplayName(
            context,
            pubkeyHex: kModerationPubkeyHex,
            isVanished: false,
            displayNameOverride: 'Override',
            profile: _profile(kModerationPubkeyHex, 'Profile'),
          ),
        ),
      );

      expect(find.text('Override'), findsOneWidget);
    });

    testWidgets('moderation wins over profile', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmPeerDisplayName(
            context,
            pubkeyHex: kModerationPubkeyHex,
            isVanished: false,
            profile: _profile(kModerationPubkeyHex, 'Profile'),
          ),
        ),
      );

      expect(find.text('Divine Moderation'), findsOneWidget);
    });

    testWidgets('profile wins over generated fallback', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmPeerDisplayName(
            context,
            pubkeyHex: pubkey,
            isVanished: false,
            profile: _profile(pubkey, 'Profile'),
          ),
        ),
      );

      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('generates a name when no identity is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          (context) => dmPeerDisplayName(
            context,
            pubkeyHex: pubkey,
            isVanished: false,
          ),
        ),
      );

      expect(
        find.text(UserProfile.defaultDisplayNameFor(pubkey)),
        findsOneWidget,
      );
    });
  });

  group('dmPeerNameWithoutProfile', () {
    testWidgets('returns null when a profile lookup is still needed', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          (context) =>
              dmPeerNameWithoutProfile(
                context,
                pubkeyHex: pubkey,
                isVanished: false,
              ) ??
              'lookup required',
        ),
      );

      expect(find.text('lookup required'), findsOneWidget);
    });
  });
}

UserProfile _profile(String pubkey, String displayName) => UserProfile(
  pubkey: pubkey,
  displayName: displayName,
  rawData: const {},
  createdAt: DateTime(2026),
  eventId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
);
