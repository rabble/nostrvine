// ABOUTME: Stores the minimal user profile maintained by AuthService.
// ABOUTME: Builds auth profiles from securely stored identity containers.

import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer;

/// Minimal profile state for the authenticated user.
class UserProfile {
  const UserProfile({
    required this.npub,
    required this.publicKeyHex,
    required this.displayName,
    this.keyCreatedAt,
    this.lastAccessAt,
    this.about,
    this.picture,
    this.nip05,
  });

  factory UserProfile.fromSecureContainer(SecureKeyContainer keyContainer) =>
      UserProfile(
        npub: keyContainer.npub,
        publicKeyHex: keyContainer.publicKeyHex,
        displayName: keyContainer.npub,
      );

  final String npub;
  final String publicKeyHex;
  final DateTime? keyCreatedAt;
  final DateTime? lastAccessAt;
  final String displayName;
  final String? about;
  final String? picture;
  final String? nip05;
}
