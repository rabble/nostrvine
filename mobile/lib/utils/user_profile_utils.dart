import 'package:models/models.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

extension UserProfileUtils on UserProfile {
  /// Get the best available display name
  String get bestDisplayName {
    if (displayName?.isNotEmpty == true) return displayName!;
    if (name?.isNotEmpty == true) return name!;
    // Fallback to truncated npub (e.g., "npub1abc...xyz")
    return truncatedNpub;
  }

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
}
