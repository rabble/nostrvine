import 'package:nostr_sdk/event.dart';

class NIP58 {
  static List<String> parseProfileBadge(Event event) {
    List<String> badgeIds = [];

    for (var tag in event.tags) {
      if (tag[0] == "a") {
        var badgeId = tag[1];

        badgeIds.add(badgeId);
      }
    }

    return badgeIds;
  }
}
