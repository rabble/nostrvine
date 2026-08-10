// ABOUTME: NIP-01 ordering for two versions of the same addressable event.
// ABOUTME: Newest created_at wins; ties break on the lowest event id.

import 'package:nostr_sdk/event.dart';

/// Whether [candidate] should replace [incumbent] as the live version of an
/// addressable event both versions address.
///
/// NIP-01 resolves same-`created_at` collisions by retaining "the event with
/// the lowest id (first in lexical order)". Comparing `created_at` alone
/// would leave the winner decided by relay response order, so two devices
/// handed the same pair of events could each keep a different one and stay
/// disagreeing forever — the exact split this rule exists to prevent.
bool replacesUnderNip01(Event candidate, Event incumbent) {
  if (candidate.createdAt != incumbent.createdAt) {
    return candidate.createdAt > incumbent.createdAt;
  }
  return candidate.id.compareTo(incumbent.id) < 0;
}

/// Sorts [events] so the NIP-01 winner is first: newest `created_at`
/// first, ties broken by the lowest event id.
void sortByNip01Precedence(List<Event> events) {
  events.sort((a, b) {
    final byCreatedAt = b.createdAt.compareTo(a.createdAt);
    if (byCreatedAt != 0) return byCreatedAt;
    return a.id.compareTo(b.id);
  });
}
