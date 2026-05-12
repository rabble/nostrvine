import 'dart:ui';

import 'package:models/models.dart';
import 'package:openvine/utils/banner_color.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

/// Converts a Nostr `kind 0` `banner` value into a [Color] when it
/// represents a hex color, or `null` when it does not.
///
/// Accepts the same input shapes as [normalizeBannerHex]: `0xRRGGBB`,
/// `#RRGGBB`, or bare `RRGGBB`. Returns `null` for URLs and malformed
/// input. Always returns fully opaque (alpha 0xFF) colors.
///
/// Lives at the UI boundary so the bloc layer can store the banner as a
/// pure-Dart hex string (see [normalizeBannerHex]) and only the
/// presentation layer touches `dart:ui`'s [Color].
Color? colorFromBannerHex(String? banner) {
  final hex = normalizeBannerHex(banner);
  if (hex == null) return null;
  final value = int.parse(hex.substring(2), radix: 16);
  return Color(0xFF000000 | value);
}

/// Inverse of [colorFromBannerHex]: encodes [color]'s RGB channels into
/// the canonical `0xRRGGBB` form the rest of the app stores in the
/// `banner` field. The alpha channel is dropped.
String hexFromColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '0x${rgb.toRadixString(16).padLeft(6, '0')}';
}

extension UserProfileUtils on UserProfile {
  /// Get npub encoding of pubkey
  String get npub {
    try {
      return NostrKeyUtils.encodePubKey(pubkey);
    } catch (e) {
      // Fallback to shortened pubkey if encoding fails
      return shortPubkey;
    }
  }

  /// Get truncated npub for display (e.g., "npub1abc...xyz")
  String get truncatedNpub => NostrKeyUtils.truncateNpub(pubkey);

  /// Parse hex color from banner field (Vine import profiles).
  ///
  /// Returns null if banner is not a hex color (e.g., if it's a URL).
  /// Supports formats: "0x33ccbf", "#33ccbf", "33ccbf"
  Color? get profileBackgroundColor => colorFromBannerHex(banner);
}
