import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/badges/nip58_badge_models.dart';

class Nip58BadgeParser {
  const Nip58BadgeParser._();

  static Nip58BadgeDefinition? parseDefinition(Event event) {
    if (event.kind != EventKind.badgeDefinition) return null;

    final dTag = _firstTagValue(event, 'd');
    if (dTag == null || dTag.isEmpty) return null;

    return Nip58BadgeDefinition(
      event: event,
      coordinate: '${EventKind.badgeDefinition}:${event.pubkey}:$dTag',
      dTag: dTag,
      name: _firstTagValue(event, 'name'),
      description: _firstTagValue(event, 'description'),
      imageUrl: _firstTagValue(event, 'image'),
      thumbnails: event.tags
          .where((tag) => tag.length > 1 && tag[0] == 'thumb')
          .map((tag) => tag[1])
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
    );
  }

  static Nip58BadgeAward? parseAward(Event event) {
    if (event.kind != EventKind.badgeAward) return null;

    final definitionCoordinate = _firstTagValue(event, 'a');
    if (definitionCoordinate == null || definitionCoordinate.isEmpty) {
      return null;
    }

    final recipients = event.tags
        .where((tag) => tag.length > 1 && tag[0] == 'p')
        .map((tag) => tag[1])
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (recipients.isEmpty) return null;

    return Nip58BadgeAward(
      event: event,
      definitionCoordinate: definitionCoordinate,
      recipientPubkeys: recipients,
    );
  }

  static Nip58ProfileBadges? parseProfileBadges(Event event) {
    if (!isProfileBadgesEvent(event)) return null;

    final badges = <Nip58ProfileBadgeRef>[];
    for (var index = 0; index < event.tags.length - 1; index++) {
      final current = event.tags[index];
      final next = event.tags[index + 1];
      if (current.length < 2 || next.length < 2) continue;
      if (current[0] != 'a' || next[0] != 'e') continue;

      badges.add(
        Nip58ProfileBadgeRef(
          definitionCoordinate: current[1],
          awardEventId: next[1],
          awardRelay: next.length > 2 && next[2].isNotEmpty ? next[2] : null,
        ),
      );
      index++;
    }

    return Nip58ProfileBadges(
      event: event,
      badges: List<Nip58ProfileBadgeRef>.unmodifiable(badges),
      isLegacyProfileBadges: _isLegacyProfileBadgesEvent(event),
    );
  }

  static bool isProfileBadgesEvent(Event event) {
    return event.kind == EventKind.profileBadges ||
        _isLegacyProfileBadgesEvent(event);
  }

  static bool _isLegacyProfileBadgesEvent(Event event) {
    return event.kind == EventKind.badgeSet &&
        _firstTagValue(event, 'd') == 'profile_badges';
  }

  static String? _firstTagValue(Event event, String name) {
    for (final tag in event.tags) {
      if (tag.length > 1 && tag[0] == name) {
        return tag[1];
      }
    }
    return null;
  }
}
