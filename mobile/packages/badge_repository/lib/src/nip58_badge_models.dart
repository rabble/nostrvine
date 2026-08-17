import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

class Nip58BadgeDefinition {
  /// Creates a badge definition, normalizing [name] and [description] to
  /// well-formed UTF-16.
  ///
  /// A kind-30009 definition can be authored by any pubkey, and the badge
  /// dashboard, detail screen and profile badge sheet render both values as
  /// plain `Text`. Flutter's paragraph builder throws `Invalid argument(s):
  /// string is not well-formed UTF-16` on a lone surrogate, so the
  /// constructor is the display boundary — the same shape `UserProfile` and
  /// `VideoEvent` use.
  Nip58BadgeDefinition({
    required this.event,
    required this.coordinate,
    required this.dTag,
    String? name,
    String? description,
    this.imageUrl,
    this.thumbnails = const [],
  }) : name = sanitizeUtf16OrNull(name),
       description = sanitizeUtf16OrNull(description);

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
