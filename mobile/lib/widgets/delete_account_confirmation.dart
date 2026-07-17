// ABOUTME: Value object for the delete-account confirmation dialog
// ABOUTME: Derives the required confirm token (username or DELETE) and matches input

import 'package:openvine/utils/nostr_key_utils.dart';

const String _deleteToken = 'DELETE';

/// Identity + confirm-token for the account-deletion dialog.
///
/// [handle] is the account's claimed `displayNip05` (full form, e.g.
/// `@name.divine.video` or `name@domain`) or `null`/empty when the account has
/// none. When present it becomes the required token; otherwise the token is
/// `DELETE` and the shown identifier is a truncated npub.
class DeleteAccountConfirmation {
  factory DeleteAccountConfirmation({
    required String pubkeyHex,
    required String displayName,
    required String? avatarUrl,
    required String? handle,
  }) {
    final hasHandle = handle != null && handle.isNotEmpty;
    return DeleteAccountConfirmation._(
      pubkeyHex: pubkeyHex,
      displayName: displayName,
      avatarUrl: avatarUrl,
      identifierLine: hasHandle
          ? handle
          : NostrKeyUtils.truncateNpub(pubkeyHex),
      requiredToken: hasHandle ? handle : _deleteToken,
      isUsernameConfirmation: hasHandle,
    );
  }

  const DeleteAccountConfirmation._({
    required this.pubkeyHex,
    required this.displayName,
    required this.avatarUrl,
    required this.identifierLine,
    required this.requiredToken,
    required this.isUsernameConfirmation,
  });

  final String pubkeyHex;
  final String displayName;
  final String? avatarUrl;

  /// Identifier shown in the identity block (handle, or truncated npub).
  final String identifierLine;

  /// String the user must type. Shown verbatim as the monospace target.
  final String requiredToken;

  /// Whether the token is a username (vs the `DELETE` fallback).
  final bool isUsernameConfirmation;

  /// Whether [input] satisfies the confirmation.
  ///
  /// Username: case-insensitive, trimmed, leading `@` optional.
  /// Fallback: case-insensitive, trimmed, equals `DELETE`.
  bool matches(String input) {
    if (isUsernameConfirmation) {
      return _normalizeHandle(input) == _normalizeHandle(requiredToken);
    }
    return input.trim().toUpperCase() == _deleteToken;
  }

  static String _normalizeHandle(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }
}
