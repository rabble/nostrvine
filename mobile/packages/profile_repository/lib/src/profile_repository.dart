// ABOUTME: Repository for fetching and publishing user profiles (Kind 0).
// ABOUTME: Delegates to NostrClient for relay operations.
// ABOUTME: Throws ProfilePublishFailedException on publish failure.

import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/src/exceptions.dart';

/// Repository for fetching and publishing user profiles (Kind 0 metadata).
class ProfileRepository {
  /// Creates a new profile repository.
  const ProfileRepository({required NostrClient nostrClient})
    : _nostrClient = nostrClient;

  final NostrClient _nostrClient;

  /// Fetches a user profile by pubkey.
  ///
  /// Returns `null` if no profile exists for the given pubkey.
  Future<UserProfile?> getProfile({required String pubkey}) async {
    final profileEvent = await _nostrClient.fetchProfile(pubkey);
    if (profileEvent == null) return null;
    return UserProfile.fromNostrEvent(profileEvent);
  }

  /// Publishes profile metadata to Nostr relays
  ///
  /// Throws `ProfilePublishFailedException` if the operation fails.
  Future<UserProfile> saveProfileEvent({
    required String displayName,
    String? about,
    String? nip05,
    String? picture,
    UserProfile? currentProfile,
  }) async {
    final profileContent = {
      if (currentProfile != null) ...currentProfile.rawData,
      'display_name': displayName,
      'about': ?about,
      'nip05': ?nip05,
      'picture': ?picture,
    };

    final profileEvent = await _nostrClient.sendProfile(
      profileContent: profileContent,
    );

    if (profileEvent == null) {
      throw const ProfilePublishFailedException(
        'Failed to publish profile. Please try again.',
      );
    }

    return UserProfile.fromNostrEvent(profileEvent);
  }
}
