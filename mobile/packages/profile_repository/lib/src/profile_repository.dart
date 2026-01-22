// ABOUTME: Repository for fetching and publishing user profiles (Kind 0).
// ABOUTME: Delegates to NostrClient for relay operations.
// ABOUTME: Throws ProfilePublishFailedException on publish failure.

import 'package:db_client/db_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/src/exceptions.dart';

/// Repository for fetching and publishing user profiles (Kind 0 metadata).
class ProfileRepository {
  /// Creates a new profile repository.
  const ProfileRepository({
    required NostrClient nostrClient,
    required UserProfilesDao userProfilesDao,
  }) : _nostrClient = nostrClient,
       _userProfilesDao = userProfilesDao;

  final NostrClient _nostrClient;
  final UserProfilesDao _userProfilesDao;

  /// Fetches a user profile by pubkey using cache-first strategy.
  ///
  /// First checks the local cache (SQLite). If found, returns immediately.
  /// On cache miss, fetches from Nostr relays, caches the result, and returns.
  ///
  /// Returns `null` if no profile exists for the given pubkey.
  Future<UserProfile?> getProfile({required String pubkey}) async {
    final cachedProfile = await _userProfilesDao.getProfile(pubkey);
    if (cachedProfile != null) return cachedProfile;

    final profileEvent = await _nostrClient.fetchProfile(pubkey);
    if (profileEvent == null) return null;

    final profile = UserProfile.fromNostrEvent(profileEvent);
    await _userProfilesDao.upsertProfile(profile);
    return profile;
  }

  /// Publishes profile metadata to Nostr relays and updates the local cache.
  ///
  /// After successful publish, the profile is cached locally for immediate
  /// subsequent reads.
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

    final profile = UserProfile.fromNostrEvent(profileEvent);
    await _userProfilesDao.upsertProfile(profile);
    return profile;
  }
}
