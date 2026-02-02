// ABOUTME: Repository for fetching and publishing user profiles (Kind 0).
// ABOUTME: Delegates to NostrClient for relay operations.
// ABOUTME: Throws ProfilePublishFailedException on publish failure.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:http/http.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/profile_repository.dart';

/// API endpoint for claiming usernames via NIP-98 auth.
const _usernameClaimUrl = 'https://names.divine.video/api/username/claim';

/// Callback to check if a user should be filtered from results.
typedef UserBlockFilter = bool Function(String pubkey);

// TODO(search): Move ProfileSearchFilter to a shared package
// (e.g., search_utils) when we need to reuse search logic across
// multiple repositories.
/// Callback to filter and sort profiles by search relevance.
/// Takes a query and list of profiles, returns filtered/sorted profiles.
typedef ProfileSearchFilter = List<UserProfile> Function(
  String query,
  List<UserProfile> profiles,
);

/// Repository for fetching and publishing user profiles (Kind 0 metadata).
class ProfileRepository {
  /// Creates a new profile repository.
  const ProfileRepository({
    required NostrClient nostrClient,
    required UserProfilesDao userProfilesDao,
    required Client httpClient,
    UserBlockFilter? userBlockFilter,
    ProfileSearchFilter? profileSearchFilter,
  }) : _nostrClient = nostrClient,
       _userProfilesDao = userProfilesDao,
       _httpClient = httpClient,
       _userBlockFilter = userBlockFilter,
       _profileSearchFilter = profileSearchFilter;

  final NostrClient _nostrClient;
  final UserProfilesDao _userProfilesDao;
  final Client _httpClient;
  final UserBlockFilter? _userBlockFilter;
  final ProfileSearchFilter? _profileSearchFilter;

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
    String? banner,
    UserProfile? currentProfile,
  }) async {
    final profileContent = {
      if (currentProfile != null) ...currentProfile.rawData,
      'display_name': displayName,
      'about': ?about,
      'nip05': ?nip05,
      'picture': ?picture,
      'banner': ?banner,
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

  /// Claims a username via NIP-98 authenticated request.
  ///
  /// Makes a POST request to `names.divine.video/api/username/claim` with the
  /// username. The pubkey is extracted from the NIP-98 auth header by the
  /// server.
  ///
  /// Returns a [UsernameClaimResult] indicating success or the type of failure.
  Future<UsernameClaimResult> claimUsername({
    required String username,
  }) async {
    final payload = jsonEncode({
      'name': username,
    });
    final authHeader = await _nostrClient.createNip98AuthHeader(
      url: _usernameClaimUrl,
      method: 'POST',
      payload: payload,
    );

    if (authHeader == null) {
      return const UsernameClaimError('Nip98 authorization failed');
    }

    final Response response;
    try {
      response = await _httpClient.post(
        Uri.parse(_usernameClaimUrl),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: payload,
      );

      return switch (response.statusCode) {
        200 || 201 => const UsernameClaimSuccess(),
        403 => const UsernameClaimReserved(),
        409 => const UsernameClaimTaken(),
        _ => UsernameClaimError('Unexpected response: ${response.statusCode}'),
      };
    } on Exception catch (e) {
      return UsernameClaimError('Network error: $e');
    }
  }

  /// Searches for user profiles matching the query.
  ///
  /// Fetches profiles via NIP-50 and filters using [ProfileSearchFilter] if
  /// provided, otherwise falls back to simple bestDisplayName matching.
  /// If a [UserBlockFilter] was provided, blocked users are excluded.
  /// Returns list of [UserProfile] matching the search query.
  /// Returns empty list if query is empty or no results found.
  Future<List<UserProfile>> searchUsers({
    required String query,
    int limit = 200,
  }) async {
    if (query.trim().isEmpty) return [];

    final events = await _nostrClient.queryUsers(query, limit: limit);
    final profiles = events.map(UserProfile.fromNostrEvent).toList();

    // Filter out blocked users first
    final unblockedProfiles = profiles.where((profile) {
      return !(_userBlockFilter?.call(profile.pubkey) ?? false);
    }).toList();

    // Use custom search filter if provided, otherwise simple contains match
    if (_profileSearchFilter != null) {
      return _profileSearchFilter(query, unblockedProfiles);
    }

    final queryLower = query.toLowerCase();
    return unblockedProfiles.where((profile) {
      return profile.bestDisplayName.toLowerCase().contains(queryLower);
    }).toList();
  }
}
