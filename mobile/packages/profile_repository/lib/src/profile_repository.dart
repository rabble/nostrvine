// ABOUTME: Repository for publishing user profiles (Kind 0 metadata).
// ABOUTME: Stateless executor that delegates to NostrClient for relay
// ABOUTME: operations.
// ABOUTME: Throws ProfilePublishFailedException on publish failure.

import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/src/exceptions.dart';

/// Repository for publishing user profiles (Kind 0 metadata).
class ProfileRepository {
  /// Creates a new profile repository.
  ///
  /// Parameters:
  /// - [nostrClient]: Client for Nostr relay communication.
  const ProfileRepository({required NostrClient nostrClient})
    : _nostrClient = nostrClient;

  final NostrClient _nostrClient;

  /// Publishes profile metadata to Nostr relays
  ///
  /// Throws `ProfilePublishFailedException` if the operation fails.
  Future<void> saveProfileEvent({
    required String displayName,
    String? about,
    String? nip05,
    String? picture,
  }) async {
    final profileEvent = await _nostrClient.sendProfile(
      displayName: displayName,
      about: about,
      nip05: nip05,
      picture: picture,
    );

    if (profileEvent == null) {
      throw const ProfilePublishFailedException(
        'Failed to publish profile. Please try again.',
      );
    }
  }
}
