// ABOUTME: Shared NIP-58 badge award fixtures for widget tests that render
// ABOUTME: the badge dashboard or the inbox Badges tab.

import 'package:badge_repository/badge_repository.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Builds a badge award addressed to the test user.
///
/// [isAccepted] drives whether the award still counts as pending.
BadgeAwardViewData badgeAwardFixture({
  required bool isAccepted,
  String name = 'Diviner of the Day',
  String dTag = 'daily-diviner',
  int seed = 1,
}) {
  final issuerPubkey = badgeTestPubkey(2);
  final definitionCoordinate = '30009:$issuerPubkey:$dTag';
  return BadgeAwardViewData(
    award: Nip58BadgeAward(
      event: _event(
        id: badgeTestEventId(seed),
        pubkey: issuerPubkey,
        kind: EventKind.badgeAward,
        tags: [
          ['a', definitionCoordinate],
          ['p', badgeTestPubkey(1)],
        ],
      ),
      definitionCoordinate: definitionCoordinate,
      recipientPubkeys: [badgeTestPubkey(1)],
    ),
    definition: Nip58BadgeDefinition(
      event: _event(
        id: badgeTestEventId(seed + 100),
        pubkey: issuerPubkey,
        kind: EventKind.badgeDefinition,
      ),
      coordinate: definitionCoordinate,
      dTag: dTag,
      name: name,
      description: 'Awarded for showing up with a good eye.',
    ),
    isAccepted: isAccepted,
  );
}

/// Deterministic 64-character event id for [seed].
String badgeTestEventId(int seed) => seed.toRadixString(16).padLeft(64, '0');

/// Deterministic 64-character pubkey for [seed].
String badgeTestPubkey(int seed) =>
    (seed + 100).toRadixString(16).padLeft(64, '0');

Event _event({
  required String id,
  required String pubkey,
  int kind = 1,
  List<List<String>> tags = const [],
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': 1000,
    'kind': kind,
    'tags': tags,
    'content': '',
    'sig': '',
  });
}
