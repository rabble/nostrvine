// ABOUTME: Utility for converting any public identifier format to hex pubkey
// ABOUTME: Returns null on invalid input instead of throwing (handles npub/nprofile/hex)

import 'package:openvine/utils/public_identifier_normalizer.dart';

/// Convert any public identifier (npub/nprofile/hex) to hex pubkey
/// Returns null if invalid
String? npubToHexOrNull(String? identifier) {
  if (identifier == null || identifier.isEmpty) return null;
  return normalizeToHex(identifier);
}

/// Whether [routeIdentifier] — a `:npub` route segment — names the signed-in
/// user identified by [currentUserHex].
///
/// A route segment has three valid encodings (npub, nprofile, bare hex) plus
/// the relative `me`, so a raw string compare against the signed-in npub
/// reports "not you" for your own account whenever the URL carries a different
/// encoding — e.g. a deep link to `/profile/<hex>`, which renders you as a
/// stranger with Message and Follow buttons.
///
/// Normalize both sides to hex instead. The profile *body* already does this
/// (`userIdHex == currentUserHex`); this keeps the scaffold and the shell
/// chrome in agreement with it, rather than letting one say "own" while the
/// other says "other" in the same frame.
bool routeIdentifiesUser(String? routeIdentifier, String? currentUserHex) {
  if (routeIdentifier == null || routeIdentifier.isEmpty) return false;
  // `me` is a *relative* reference: it names the own-profile route
  // structurally, so it holds even before auth resolves. Gating it on a
  // signed-in pubkey would report "not you" during the cold-start window and
  // flash an app bar and back button over your own profile before flipping.
  if (routeIdentifier == 'me') return true;
  if (currentUserHex == null || currentUserHex.isEmpty) return false;
  final routeHex = npubToHexOrNull(routeIdentifier);
  if (routeHex == null) return false;
  return routeHex.toLowerCase() == currentUserHex.toLowerCase();
}
