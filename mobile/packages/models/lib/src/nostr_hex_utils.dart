/// Shared validators for 32-byte Nostr hex identifiers.
class NostrHexUtils {
  NostrHexUtils._();

  static final RegExp _hex32Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Returns true when [value] is a valid 32-byte hexadecimal string.
  static bool isValidHex32(String? value) {
    return value != null && _hex32Pattern.hasMatch(value);
  }

  /// Returns true when [eventId] is a valid Nostr event id.
  static bool isValidEventId(String? eventId) => isValidHex32(eventId);

  /// Returns true when [pubkey] is a valid Nostr public key.
  static bool isValidPubkey(String? pubkey) => isValidHex32(pubkey);
}
