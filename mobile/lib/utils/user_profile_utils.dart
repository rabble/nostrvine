import 'dart:ui';

import 'package:models/models.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

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
  Color? get profileBackgroundColor {
    if (banner == null || banner!.isEmpty) return null;

    var hexString = banner!;

    // Remove 0x prefix if present
    if (hexString.startsWith('0x')) {
      hexString = hexString.substring(2);
    }
    // Remove # prefix if present
    else if (hexString.startsWith('#')) {
      hexString = hexString.substring(1);
    }
    // If it looks like a URL, it's not a color
    else if (hexString.startsWith('http')) {
      return null;
    }

    // Validate hex string (should be 6 characters for RGB)
    if (hexString.length != 6) return null;

    // Try to parse the hex color
    final colorValue = int.tryParse(hexString, radix: 16);
    if (colorValue == null) return null;
    // Add full opacity (0xFF) to the color
    return Color(0xFF000000 | colorValue);
  }
}
