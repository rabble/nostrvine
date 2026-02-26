// ABOUTME: Repository for fetching and publishing user profiles (Kind 0).
// ABOUTME: Delegates to NostrClient for relay operations.
// ABOUTME: Throws ProfilePublishFailedException on publish failure.

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:db_client/db_client.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/profile_repository.dart';

/// API endpoint for claiming usernames via NIP-98 auth.
const _usernameClaimUrl = 'https://names.divine.video/api/username/claim';
const _usernameCheckUrl = 'https://names.divine.video/api/username/check';

/// Keycast NIP-05 endpoint for checking username availability on login server.
const _keycastNip05Url = 'https://login.divine.video/.well-known/nostr.json';

/// Callback to check if a user should be filtered from results.
typedef UserBlockFilter = bool Function(String pubkey);

// TODO(search): Move ProfileSearchFilter to a shared package
// (e.g., search_utils) when we need to reuse search logic across
// multiple repositories.
/// Callback to filter and sort profiles by search relevance.
/// Takes a query and list of profiles, returns filtered/sorted profiles.
typedef ProfileSearchFilter =
    List<UserProfile> Function(
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
    FunnelcakeApiClient? funnelcakeApiClient,
    UserBlockFilter? userBlockFilter,
    ProfileSearchFilter? profileSearchFilter,
  }) : _nostrClient = nostrClient,
       _userProfilesDao = userProfilesDao,
       _httpClient = httpClient,
       _funnelcakeApiClient = funnelcakeApiClient,
       _userBlockFilter = userBlockFilter,
       _profileSearchFilter = profileSearchFilter;

  final NostrClient _nostrClient;
  final UserProfilesDao _userProfilesDao;
  final Client _httpClient;
  final FunnelcakeApiClient? _funnelcakeApiClient;
  final UserBlockFilter? _userBlockFilter;
  final ProfileSearchFilter? _profileSearchFilter;

  /// Returns the cached profile from local storage (SQLite) only.
  ///
  /// Does NOT fetch from Nostr relays. Use this for immediate UI display
  /// while [fetchFreshProfile] runs in parallel.
  ///
  /// Returns `null` if no cached profile exists for the given pubkey.
  Future<UserProfile?> getCachedProfile({required String pubkey}) async {
    return _userProfilesDao.getProfile(pubkey);
  }

  /// Fetches a fresh profile from Nostr relays and updates the local cache.
  ///
  /// Always fetches from relay, ignoring any cached data. Use this to ensure
  /// the user sees the latest profile data.
  ///
  /// Returns `null` if no profile exists on relays for the given pubkey.
  /// On success, the profile is automatically cached locally.
  Future<UserProfile?> fetchFreshProfile({required String pubkey}) async {
    final profileEvent = await _nostrClient.fetchProfile(pubkey);
    if (profileEvent == null) {
      developer.log(
        'No profile found for $pubkey (cache miss + relay miss)',
        name: 'ProfileRepository.getProfile',
      );
      return null;
    }

    final profile = UserProfile.fromNostrEvent(profileEvent);
    developer.log(
      'Fetched from relay and caching: ${profile.bestDisplayName}, '
      'picture=${profile.picture ?? "null"}',
      name: 'ProfileRepository.getProfile',
    );
    await _userProfilesDao.upsertProfile(profile);
    return profile;
  }

  /// Publishes profile metadata to Nostr relays and updates the local cache.
  ///
  /// Supports two NIP-05 modes:
  /// - **Divine.video username**: When [username] is provided, constructs the
  ///   NIP-05 identifier as `_@<username>.divine.video`.
  /// - **External NIP-05**: When [nip05] is provided, uses it directly as the
  ///   full NIP-05 identifier (e.g., `alice@example.com`).
  ///
  /// If both [nip05] and [username] are provided, [nip05] takes precedence.
  /// When neither is provided and a [currentProfile] is supplied, the existing
  /// NIP-05 value is preserved from `currentProfile.rawData`.
  ///
  /// After successful publish, the profile is cached locally for immediate
  /// subsequent reads.
  ///
  /// Throws `ProfilePublishFailedException` if the operation fails.
  Future<UserProfile> saveProfileEvent({
    required String displayName,
    String? about,
    String? username,
    String? nip05,
    String? picture,
    String? banner,
    UserProfile? currentProfile,
  }) async {
    // External NIP-05 takes precedence when provided.
    final resolvedNip05 =
        nip05 ??
        (username != null ? '_@${username.toLowerCase()}.divine.video' : null);

    final profileContent = {
      if (currentProfile != null) ...currentProfile.rawData,
      'display_name': displayName,
      'about': ?about,
      'nip05': ?resolvedNip05,
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
    final normalizedUsername = username.toLowerCase();
    final payload = jsonEncode({
      'name': normalizedUsername,
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

      // Parse server error message if available
      String? serverError;
      if (response.statusCode != 200 && response.statusCode != 201) {
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          serverError = errorData['error'] as String?;
        } on Exception {
          // Ignore JSON parse failures
        }
      }

      return switch (response.statusCode) {
        200 || 201 => const UsernameClaimSuccess(),
        400 => UsernameClaimError(
          serverError ?? 'Invalid username format',
        ),
        403 => const UsernameClaimReserved(),
        409 => const UsernameClaimTaken(),
        _ => UsernameClaimError(
          serverError ?? 'Unexpected response: ${response.statusCode}',
        ),
      };
    } on Exception catch (e) {
      return UsernameClaimError('Network error: $e');
    }
  }

  /// Checks if a username is available for registration.
  ///
  /// Queries the NIP-05 endpoint to check if the username is already registered
  /// on the server. This method does NOT validate username format - format
  /// validation is the responsibility of the BLoC layer.
  ///
  /// Returns a [UsernameAvailabilityResult] indicating:
  /// - [UsernameAvailable] if the username is not registered on the server
  /// - [UsernameTaken] if the username is already registered
  /// - [UsernameCheckError] if a network error occurs or the server returns
  ///   an unexpected response
  Future<UsernameAvailabilityResult> checkUsernameAvailability({
    required String username,
  }) async {
    final normalizedUsername = username.toLowerCase().trim();

    // Client-side format validation: usernames become subdomains, so only
    // lowercase letters, digits, and hyphens are allowed. No dots,
    // underscores, spaces, or special characters.
    if (normalizedUsername.isEmpty) {
      return const UsernameInvalidFormat('Username is required');
    }
    if (normalizedUsername.length > 63) {
      return const UsernameInvalidFormat(
        'Usernames must be 1–63 characters',
      );
    }
    if (normalizedUsername.startsWith('-') ||
        normalizedUsername.endsWith('-')) {
      return const UsernameInvalidFormat(
        "Usernames can't start or end with a hyphen",
      );
    }
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(normalizedUsername)) {
      return const UsernameInvalidFormat(
        'Only letters, numbers, and hyphens are allowed '
        '(your username becomes username.divine.video)',
      );
    }

    // Server-side check using the name-server API which validates format
    // and checks availability in one call.
    try {
      final response = await _httpClient.get(
        Uri.parse(
          '$_usernameCheckUrl/$normalizedUsername',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final available = data['available'] as bool? ?? false;
        final reason = data['reason'] as String?;

        if (available) {
          // Also check keycast (login.divine.video) — username must be
          // available on both the name server and the login server.
          try {
            final keycastResponse = await _httpClient.get(
              Uri.parse(
                '$_keycastNip05Url?name=$normalizedUsername',
              ),
            );
            if (keycastResponse.statusCode == 200) {
              final keycastData =
                  jsonDecode(keycastResponse.body) as Map<String, dynamic>;
              final names = keycastData['names'] as Map<String, dynamic>? ?? {};
              if (names.containsKey(normalizedUsername)) {
                return const UsernameTaken();
              }
            }
            // If keycast returns non-200 or no names entry, treat as available
          } on Exception catch (e) {
            // If keycast is unreachable, don't block — name-server said OK
            developer.log(
              'Keycast availability check failed (non-blocking): $e',
              name: 'ProfileRepository.checkUsernameAvailability',
            );
          }
          return const UsernameAvailable();
        }

        // Server told us it's not available — return appropriate type
        if (reason != null) {
          // Validation failures come back with reason but available=false
          if (reason.contains('character') ||
              reason.contains('hyphen') ||
              reason.contains('invalid') ||
              reason.contains('emoji') ||
              reason.contains('DNS')) {
            return UsernameInvalidFormat(reason);
          }
        }
        return const UsernameTaken();
      } else {
        return UsernameCheckError(
          'Server returned status ${response.statusCode}',
        );
      }
    } on Exception catch (e) {
      return UsernameCheckError('Network error: $e');
    }
  }

  /// Searches for user profiles matching the query.
  ///
  /// Uses a hybrid search approach:
  /// 1. First tries Funnelcake REST API (fast, if available)
  /// 2. Then fetches via NIP-50 WebSocket (comprehensive, first page only)
  /// 3. Merges results (REST results take priority by pubkey)
  ///
  /// [offset] skips results for pagination. When offset > 0, the NIP-50
  /// WebSocket fallback is skipped since it doesn't support offset.
  /// [sortBy] requests server-side sorting (e.g., 'followers'). When set,
  /// client-side re-sorting is skipped to preserve server order.
  /// [hasVideos] filters to only users who have published at least one video.
  ///
  /// Filters using [ProfileSearchFilter] if provided (only when no server-side
  /// sort is active), otherwise falls back to simple bestDisplayName matching.
  /// If a [UserBlockFilter] was provided, blocked users are excluded.
  /// Returns list of [UserProfile] matching the search query.
  /// Returns empty list if query is empty or no results found.
  Future<List<UserProfile>> searchUsers({
    required String query,
    int limit = 200,
    int offset = 0,
    String? sortBy,
    bool hasVideos = false,
  }) async {
    if (query.trim().isEmpty) return [];

    final resultMap = <String, UserProfile>{};
    final useServerSort = sortBy != null;

    // Phase 1: Try Funnelcake REST API (fast)
    if (_funnelcakeApiClient?.isAvailable ?? false) {
      try {
        final restResults = await _funnelcakeApiClient!.searchProfiles(
          query: query,
          limit: limit,
          offset: offset,
          sortBy: sortBy,
          hasVideos: hasVideos,
        );
        for (final result in restResults) {
          resultMap[result.pubkey] = result.toUserProfile();
        }
        final withPic = restResults.where((r) => r.picture != null).length;
        developer.log(
          'Phase 1 (REST): ${restResults.length} results, '
          '$withPic with picture',
          name: 'ProfileRepository.searchUsers',
        );
      } on Exception catch (e) {
        developer.log(
          'Phase 1 (REST) failed: $e',
          name: 'ProfileRepository.searchUsers',
        );
      }
    }

    // Phase 2: NIP-50 WebSocket search (comprehensive, first page only)
    // Skip on paginated requests since NIP-50 doesn't support offset.
    if (offset == 0) {
      final events = await _nostrClient.queryUsers(query, limit: limit);
      for (final event in events) {
        final profile = UserProfile.fromNostrEvent(event);
        // Don't overwrite REST results - they may have more complete data
        resultMap.putIfAbsent(profile.pubkey, () => profile);
      }
      final wsProfiles = resultMap.values.toList();
      final wsWithPic = wsProfiles.where((p) => p.picture != null).length;
      developer.log(
        'Phase 2 (WS): ${events.length} events, '
        'merged total: ${wsProfiles.length}, $wsWithPic with picture',
        name: 'ProfileRepository.searchUsers',
      );
    }

    final profiles = resultMap.values.toList();

    // Enrich profiles from local SQLite cache (fill in missing pictures, etc.)
    final enrichedProfiles = await _enrichFromCache(profiles);

    // Filter out blocked users
    final unblockedProfiles = enrichedProfiles.where((profile) {
      return !(_userBlockFilter?.call(profile.pubkey) ?? false);
    }).toList();

    // When server-side sorting is active, trust server order
    if (useServerSort) {
      return unblockedProfiles;
    }

    // Use custom search filter if provided, otherwise simple contains match
    if (_profileSearchFilter != null) {
      return _profileSearchFilter(query, unblockedProfiles);
    }

    final queryLower = query.toLowerCase();
    return unblockedProfiles.where((profile) {
      return profile.bestDisplayName.toLowerCase().contains(queryLower);
    }).toList();
  }

  /// Fetches a user profile from the Funnelcake REST API.
  ///
  /// Returns profile data as a map, or null if not found.
  /// Returns null if Funnelcake API is not available.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<Map<String, dynamic>?> getUserProfileFromApi({
    required String pubkey,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getUserProfile(pubkey);
  }

  /// Fetches multiple user profiles in bulk from the Funnelcake REST API.
  ///
  /// Returns a [BulkProfilesResponse] containing a map of pubkey to profile
  /// data.
  /// Returns null if Funnelcake API is not available.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<BulkProfilesResponse?> getBulkProfilesFromApi(
    List<String> pubkeys,
  ) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getBulkProfiles(pubkeys);
  }

  /// Enriches search results from the local SQLite cache.
  ///
  /// For each profile, fills in null fields (picture, about, etc.) from
  /// the cached version without overwriting data from search results.
  Future<List<UserProfile>> _enrichFromCache(
    List<UserProfile> profiles,
  ) async {
    final enriched = <UserProfile>[];
    var cacheHits = 0;
    var pictureEnriched = 0;
    for (final profile in profiles) {
      final cached = await _userProfilesDao.getProfile(profile.pubkey);
      if (cached == null) {
        enriched.add(profile);
        continue;
      }
      cacheHits++;
      final hadPicture = profile.picture != null;
      final cachedHasPicture = cached.picture != null;
      final willEnrichPicture = !hadPicture && cachedHasPicture;
      if (willEnrichPicture) pictureEnriched++;
      developer.log(
        'Cache hit for ${profile.bestDisplayName}: '
        'search picture=${profile.picture ?? "null"}, '
        'cached picture=${cached.picture ?? "null"}, '
        'will enrich=$willEnrichPicture',
        name: 'ProfileRepository._enrichFromCache',
      );
      enriched.add(
        profile.copyWith(
          name: profile.name ?? cached.name,
          displayName: profile.displayName ?? cached.displayName,
          about: profile.about ?? cached.about,
          picture: profile.picture ?? cached.picture,
          banner: profile.banner ?? cached.banner,
          website: profile.website ?? cached.website,
          nip05: profile.nip05 ?? cached.nip05,
          lud16: profile.lud16 ?? cached.lud16,
          lud06: profile.lud06 ?? cached.lud06,
        ),
      );
    }
    developer.log(
      'Enrichment summary: ${profiles.length} profiles, '
      '$cacheHits cache hits, $pictureEnriched pictures enriched',
      name: 'ProfileRepository._enrichFromCache',
    );
    return enriched;
  }
}
