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
}
