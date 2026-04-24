// ABOUTME: Hashtag discovery filter helper (full grid lives under Popular + search).

import 'package:meta/meta.dart';

/// Returns whether [hashtag] should appear when the user types [query].
@visibleForTesting
bool hashtagDiscoveryMatchesFilter(String hashtag, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return hashtag.toLowerCase().contains(q);
}
