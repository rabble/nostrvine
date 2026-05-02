import 'package:nostr_sdk/nostr_sdk.dart';

class Nip58BadgeDefinition {
  const Nip58BadgeDefinition({
    required this.event,
    required this.coordinate,
    required this.dTag,
    this.name,
    this.description,
    this.imageUrl,
    this.thumbnails = const [],
  });

  final Event event;
  final String coordinate;
  final String dTag;
  final String? name;
  final String? description;
  final String? imageUrl;
  final List<String> thumbnails;
}

class Nip58BadgeAward {
  const Nip58BadgeAward({
    required this.event,
    required this.definitionCoordinate,
    required this.recipientPubkeys,
  });

  final Event event;
  final String definitionCoordinate;
  final List<String> recipientPubkeys;
}

class Nip58ProfileBadgeRef {
  const Nip58ProfileBadgeRef({
    required this.definitionCoordinate,
    required this.awardEventId,
    this.awardRelay,
  });

  final String definitionCoordinate;
  final String awardEventId;
  final String? awardRelay;
}

class Nip58ProfileBadges {
  const Nip58ProfileBadges({
    required this.event,
    required this.badges,
    required this.isLegacyProfileBadges,
  });

  final Event event;
  final List<Nip58ProfileBadgeRef> badges;
  final bool isLegacyProfileBadges;
}
