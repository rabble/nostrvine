// ABOUTME: Repository for fetching and publishing user profiles (Kind 0).
// ABOUTME: Delegates to NostrClient for relay operations.
// ABOUTME: Throws ProfilePublishFailedException on publish failure.

import 'dart:convert';
import 'dart:developer' as developer;

// Hide Drift table class to avoid collision with ProfileStats domain model.
import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, Filter;
import 'package:profile_repository/profile_repository.dart';

// TODO(e2e): Add divine-name-server to local_stack Docker dependencies
// so username check/claim flows can be tested against it in E2E tests.
const _usernameClaimUrl = 'https://names.divine.video/api/username/claim';
const _usernameCheckUrl = 'https://names.divine.video/api/username/check';
const _keycastNip05Url = 'https://login.divine.video/.well-known/nostr.json';

// TODO(search): Move ProfileSearchFilter to a shared package
// (e.g., search_utils) when we need to reuse search logic across
// multiple repositories.
/// Callback to filter and sort profiles by search relevance.
/// Takes a query and list of profiles, returns filtered/sorted profiles.
typedef ProfileSearchFilter =
    List<UserProfile> Function(String query, List<UserProfile> profiles);

/// Well-known indexer relays that maintain broad coverage of kind 0 events.
/// Used as a last-resort fallback when main relays and REST API don't have
/// a profile.
const _profileIndexerRelays = [
  'wss://purplepag.es',
  'wss://user.kindpag.es',
  'wss://relay.nos.social',
];

/// Repository for fetching and publishing user profiles (Kind 0 metadata).
class ProfileRepository {
  /// Creates a new profile repository.
  ProfileRepository({
    required NostrClient nostrClient,
    required UserProfilesDao userProfilesDao,
    required Client httpClient,
    ProfileStatsDao? profileStatsDao,
    FunnelcakeApiClient? funnelcakeApiClient,
    ProfileSearchFilter? profileSearchFilter,
  }) : _nostrClient = nostrClient,
       _userProfilesDao = userProfilesDao,
       _httpClient = httpClient,
       _profileStatsDao = profileStatsDao,
       _funnelcakeApiClient = funnelcakeApiClient,
       _profileSearchFilter = profileSearchFilter;

  final NostrClient _nostrClient;
  final UserProfilesDao _userProfilesDao;
  final Client _httpClient;
  final ProfileStatsDao? _profileStatsDao;
  final FunnelcakeApiClient? _funnelcakeApiClient;
  final ProfileSearchFilter? _profileSearchFilter;

  /// In-flight relay fetches keyed by pubkey. Concurrent callers for the
  /// same pubkey share the same future instead of firing duplicate requests.
  final _inFlightFetches = <String, Future<UserProfile?>>{};

  /// Pubkeys confirmed to have no Kind 0 profile (FunnelCake returned
  /// the `_noProfile` sentinel or relay + indexer returned nothing).
  /// Session-scoped — cleared on app restart.
  final _confirmedMissing = <String>{};

  /// In-memory set of pubkeys known to have cached profiles.
  /// Enables synchronous [hasProfile] checks for subscription
  /// manager filtering.
  final _knownCached = <String>{};

  /// Searches cached profiles from local storage only.
  ///
  /// This avoids remote work and is suitable for lightweight tab counts
  /// or instant local-first suggestions.
  Future<List<UserProfile>> searchUsersLocally({
    required String query,
    int? limit,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final cachedProfiles = await _userProfilesDao.getAllProfiles();

    final filtered = _profileSearchFilter != null
        ? _profileSearchFilter(trimmed, cachedProfiles)
        : cachedProfiles.where((profile) {
            final queryLower = trimmed.toLowerCase();
            return profile.bestDisplayName.toLowerCase().contains(queryLower) ||
                (profile.about?.toLowerCase().contains(queryLower) ?? false);
          }).toList();

    if (limit != null && filtered.length > limit) {
      return filtered.sublist(0, limit);
    }

    return filtered;
  }

  /// Counts cached profiles matching [query] without performing remote search.
  Future<int> countUsersLocally({required String query}) async {
    final matches = await searchUsersLocally(query: query);
    return matches.length;
  }

  /// Whether the given pubkey is known to have no Kind 0 profile.
  ///
  /// Returns `true` if FunnelCake or relay fetches previously confirmed
  /// this pubkey has no profile. Session-scoped.
  bool isConfirmedMissing(String pubkey) => _confirmedMissing.contains(pubkey);

  /// Synchronous check for whether a profile is cached.
  ///
  /// Returns `true` if the pubkey was previously fetched and cached in
  /// this session. Used by the subscription manager to skip redundant
  /// Kind 0 relay requests.
  ///
  /// Call [loadKnownCachedPubkeys] once at startup to pre-populate.
  bool hasProfile(String pubkey) => _knownCached.contains(pubkey);

  /// Pre-loads the in-memory [_knownCached] set from all profiles
  /// currently in the Drift cache. Call once after construction.
  Future<void> loadKnownCachedPubkeys() async {
    final all = await _userProfilesDao.getAllProfiles();
    _knownCached.addAll(all.map((p) => p.pubkey));
  }

  /// Returns the cached profile from local storage (SQLite) only.
  ///
  /// Does NOT fetch from Nostr relays. Use this for immediate UI display
  /// while [fetchFreshProfile] runs in parallel.
  ///
  /// Returns `null` if no cached profile exists for the given pubkey.
  Future<UserProfile?> getCachedProfile({required String pubkey}) async {
    return _userProfilesDao.getProfile(pubkey);
  }

  /// Persists a profile to local storage (SQLite).
  ///
  /// Use this to cache profiles obtained from relay events or REST APIs.
  /// If a profile with the same pubkey already exists, it is updated.
  /// Also clears the pubkey from the confirmed-missing set and adds
  /// it to the known-cached set.
  Future<void> cacheProfile(UserProfile profile) {
    _confirmedMissing.remove(profile.pubkey);
    _knownCached.add(profile.pubkey);
    return _userProfilesDao.upsertProfile(profile);
  }

  /// Deletes a cached profile from local storage.
  ///
  /// Returns the number of rows deleted (0 or 1).
  Future<int> deleteCachedProfile({required String pubkey}) {
    return _userProfilesDao.deleteProfile(pubkey);
  }

  /// Returns all cached profiles from local storage.
  ///
  /// Used for bulk-loading profiles into memory on startup.
  Future<List<UserProfile>> getAllCachedProfiles() {
    return _userProfilesDao.getAllProfiles();
  }

  /// Watches a profile by pubkey, emitting updates from local storage.
  ///
  /// Returns a stream that emits the current [UserProfile] whenever the
  /// cached profile changes (insert, update, or delete). Emits `null` if
  /// no cached profile exists for the given pubkey.
  ///
  /// Use this for reactive UI updates (e.g., BlocBuilder subscriptions).
  /// Pair with [fetchFreshProfile] to trigger relay fetches that write
  /// back to the cache and automatically flow through this stream.
  Stream<UserProfile?> watchProfile({required String pubkey}) {
    return _userProfilesDao.watchProfile(pubkey);
  }

  /// Watches profile stats by pubkey, emitting updates from local storage.
  ///
  /// Returns a stream that maps [ProfileStatRow] from the database to
  /// [ProfileStats] domain models. Emits `null` if no stats exist.
  ///
  /// Returns an empty stream if [ProfileStatsDao] was not injected.
  Stream<ProfileStats?> watchProfileStats({required String pubkey}) {
    final dao = _profileStatsDao;
    if (dao == null) return const Stream.empty();
    return dao.watchStats(pubkey).map((row) {
      if (row == null) return null;
      return ProfileStats(
        pubkey: row.pubkey,
        videoCount: row.videoCount ?? 0,
        totalLikes: row.totalLikes ?? 0,
        followers: row.followerCount ?? 0,
        following: row.followingCount ?? 0,
        totalViews: row.totalViews ?? 0,
        lastUpdated: row.cachedAt,
      );
    });
  }

  /// Fetches a fresh profile and updates the local cache.
  ///
  /// Uses a layered strategy matching `fetchBatchProfiles`:
  /// 1. Funnelcake REST API (fast, broad coverage)
  /// 2. User's connected relays (WebSocket)
  /// 3. Well-known indexer relays (Purple Pages, Kind Pages)
  ///
  /// Skips all fetches if the pubkey is confirmed missing.
  /// Deduplicates concurrent calls for the same pubkey — only one fetch
  /// pipeline runs, and all callers share the result.
  ///
  /// Returns `null` if no profile exists across all sources.
  /// On success, the profile is automatically cached locally.
  Future<UserProfile?> fetchFreshProfile({required String pubkey}) {
    if (_confirmedMissing.contains(pubkey)) return Future.value();

    // Deduplicate: return existing in-flight future if present.
    final existing = _inFlightFetches[pubkey];
    if (existing != null) return existing;

    final future = _doFetchFreshProfile(pubkey);
    _inFlightFetches[pubkey] = future;

    return future.whenComplete(() => _inFlightFetches.remove(pubkey));
  }

  Future<UserProfile?> _doFetchFreshProfile(String pubkey) async {
    // Step 1: Try Funnelcake REST API (fast, broad coverage).
    if (_funnelcakeApiClient?.isAvailable ?? false) {
      try {
        final data = await _funnelcakeApiClient!.getUserProfile(pubkey);
        if (data != null && data['_noProfile'] != true) {
          final profile = UserProfile.fromFunnelcake(pubkey, data);
          developer.log(
            'Fetched from REST API and caching: '
            '${profile.bestDisplayName}',
            name: 'ProfileRepository.fetchFreshProfile',
          );
          _knownCached.add(pubkey);
          await _userProfilesDao.upsertProfile(profile);
          return profile;
        }
        // _noProfile sentinel — user exists but has no Kind 0.
        // Skip relay/indexer fallback.
        if (data != null && data['_noProfile'] == true) {
          _confirmedMissing.add(pubkey);
          return null;
        }
      } on Exception catch (e) {
        developer.log(
          'REST API fetch failed (falling back to relay): $e',
          name: 'ProfileRepository.fetchFreshProfile',
        );
      }
    }

    // Step 2: Try user's connected relays (WebSocket).
    final profileEvent = await _nostrClient.fetchProfile(pubkey);
    if (profileEvent != null) {
      final profile = UserProfile.fromNostrEvent(profileEvent);
      developer.log(
        'Fetched from relay and caching: ${profile.bestDisplayName}, '
        'picture=${profile.picture ?? "null"}',
        name: 'ProfileRepository.fetchFreshProfile',
      );
      _knownCached.add(pubkey);
      await _userProfilesDao.upsertProfile(profile);
      return profile;
    }

    // Step 3: Try well-known indexer relays (NIP-65 discovery points).
    try {
      final indexerEvents = await _nostrClient
          .queryEvents(
            [
              Filter(kinds: [0], authors: [pubkey], limit: 1),
            ],
            tempRelays: _profileIndexerRelays,
            useCache: false,
          )
          .timeout(const Duration(seconds: 5), onTimeout: () => <Event>[]);

      if (indexerEvents.isNotEmpty && indexerEvents.first.kind == 0) {
        final profile = UserProfile.fromNostrEvent(indexerEvents.first);
        developer.log(
          'Fetched from indexer relay and caching: '
          '${profile.bestDisplayName}',
          name: 'ProfileRepository.fetchFreshProfile',
        );
        _knownCached.add(pubkey);
        await _userProfilesDao.upsertProfile(profile);
        return profile;
      }
    } on Exception catch (e) {
      developer.log(
        'Indexer relay fetch failed: $e',
        name: 'ProfileRepository.fetchFreshProfile',
      );
    }

    // All sources exhausted — mark as confirmed missing.
    _confirmedMissing.add(pubkey);
    developer.log(
      'No profile found for $pubkey across all sources, marked missing',
      name: 'ProfileRepository.fetchFreshProfile',
    );
    return null;
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
  /// NIP-05 value is preserved from `currentProfile.rawData`. Pass
  /// [clearNip05] as `true` to explicitly remove the NIP-05 from the profile
  /// (overriding any value in `currentProfile.rawData`).
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
    bool clearNip05 = false,
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

    // When the user explicitly removes their NIP-05 (no username, no external
    // NIP-05), remove the key so the rawData spread does not preserve the old
    // value.
    if (clearNip05 && resolvedNip05 == null) {
      profileContent.remove('nip05');
    }

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
  Future<UsernameClaimResult> claimUsername({required String username}) async {
    final normalizedUsername = username.toLowerCase();
    final payload = jsonEncode({'name': normalizedUsername});
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
        400 => UsernameClaimError(serverError ?? 'Invalid username format'),
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
    String? currentUserPubkey,
  }) async {
    final normalizedUsername = username.toLowerCase().trim();

    // Client-side format validation: usernames become subdomains, so only
    // lowercase letters, digits, and hyphens are allowed. No dots,
    // underscores, spaces, or special characters.
    if (normalizedUsername.isEmpty) {
      return const UsernameInvalidFormat('Username is required');
    }
    if (normalizedUsername.length > 63) {
      return const UsernameInvalidFormat('Usernames must be 1–63 characters');
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
        Uri.parse('$_usernameCheckUrl/$normalizedUsername'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final available = data['available'] as bool? ?? false;
        final reason = data['reason'] as String?;
        final code = data['code'] as String?;

        if (available) {
          // Also check keycast (login.divine.video) — username must be
          // available on both the name server and the login server.
          try {
            final keycastResponse = await _httpClient.get(
              Uri.parse('$_keycastNip05Url?name=$normalizedUsername'),
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

        // Name is taken, but check if it's assigned to the current user
        // (e.g. admin-reserved name assigned to this pubkey).
        if (currentUserPubkey != null) {
          final ownerPubkey = data['pubkey'] as String?;
          if (ownerPubkey != null && ownerPubkey == currentUserPubkey) {
            return const UsernameAvailable();
          }
        }

        if (code == null) {
          developer.log(
            'Name server response missing required code field '
            '(username: $normalizedUsername, reason: $reason)',
            name: 'ProfileRepository.checkUsernameAvailability',
            level: 1000,
          );
          return const UsernameTaken();
        }
        return switch (code) {
          'reserved' => const UsernameReserved(),
          'burned' => const UsernameBurned(),
          'invalid_format' => UsernameInvalidFormat(
            reason ?? 'Invalid username format',
          ),
          // taken, pending_confirmation, or any unknown code
          _ => const UsernameTaken(),
        };
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
      try {
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
      } on Object catch (e) {
        developer.log(
          'Phase 2 (WebSocket NIP-50) failed: $e',
          name: 'ProfileRepository.searchUsers',
        );
      }
    }

    final profiles = resultMap.values.toList();

    // Enrich profiles from local SQLite cache (fill in missing pictures, etc.)
    final enrichedProfiles = await _enrichFromCache(profiles);

    // Note: blocked users are NOT filtered from search results.
    // Users need to find blocked profiles in search to unblock them.
    // Block filtering is applied in video feeds (VideoEventService) instead.

    // When server-side sorting is active, trust server order
    if (useServerSort) {
      return enrichedProfiles;
    }

    // Use custom search filter if provided, otherwise simple contains match
    if (_profileSearchFilter != null) {
      return _profileSearchFilter(query, enrichedProfiles);
    }

    final queryLower = query.toLowerCase();
    return enrichedProfiles.where((profile) {
      return profile.bestDisplayName.toLowerCase().contains(queryLower);
    }).toList();
  }

  /// Progressively streams user profile search results.
  ///
  /// Yields accumulated results as each source completes:
  /// 1. Local cached profiles (instant)
  /// 2. Funnelcake REST API results merged with local (fast)
  /// 3. NIP-50 WebSocket results merged with all (first page only)
  ///
  /// Each yield contains the full deduplicated list so far — not just the
  /// new batch. This matches the progressive pattern used by
  /// `VideosRepository.searchVideos()`.
  ///
  /// Parameters match [searchUsers]. When [offset] > 0 the local and NIP-50
  /// phases are skipped (only the API phase runs).
  Stream<List<UserProfile>> searchUsersProgressive({
    required String query,
    int limit = 200,
    int offset = 0,
    String? sortBy,
    bool hasVideos = false,
  }) async* {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final resultMap = <String, UserProfile>{};
    final useServerSort = sortBy != null;

    // Phase 1: Local cache (instant, first page only)
    if (offset == 0) {
      final local = await searchUsersLocally(query: trimmed);
      for (final profile in local) {
        resultMap[profile.pubkey] = profile;
      }
      if (resultMap.isNotEmpty) {
        yield _applyFilter(trimmed, resultMap.values.toList(), useServerSort);
      }
    }

    // Phase 2: Funnelcake REST API (fast)
    final prevCount = resultMap.length;
    if (_funnelcakeApiClient?.isAvailable ?? false) {
      try {
        final restResults = await _funnelcakeApiClient!.searchProfiles(
          query: trimmed,
          limit: limit,
          offset: offset,
          sortBy: sortBy,
          hasVideos: hasVideos,
        );
        for (final result in restResults) {
          resultMap[result.pubkey] = result.toUserProfile();
        }
      } on Exception catch (e) {
        developer.log(
          'REST search failed: $e',
          name: 'ProfileRepository.searchUsersProgressive',
        );
      }
    }

    // Yield after Phase 2 if new results were added.
    // Skips enrichment for faster progressive display; the final Phase 3
    // yield enriches all results from cache.
    if (resultMap.length > prevCount) {
      yield _applyFilter(trimmed, resultMap.values.toList(), useServerSort);
    }

    // Phase 3: NIP-50 WebSocket (first page only)
    if (offset == 0) {
      final preWsCount = resultMap.length;
      try {
        final events = await _nostrClient.queryUsers(trimmed, limit: limit);
        for (final event in events) {
          final profile = UserProfile.fromNostrEvent(event);
          resultMap.putIfAbsent(profile.pubkey, () => profile);
        }
      } on Object catch (e) {
        // Intentionally catches Object: WebSocket failures surface as
        // StateError (an Error, not Exception), unlike the REST phase above.
        developer.log(
          'NIP-50 search failed: $e',
          name: 'ProfileRepository.searchUsersProgressive',
        );
      }

      // Only enrich + yield again if WS added new profiles
      if (resultMap.length > preWsCount) {
        final enriched = await _enrichFromCache(resultMap.values.toList());
        yield _applyFilter(trimmed, enriched, useServerSort);
        return;
      }
    }

    // Final yield: enriched + filtered (when WS didn't add anything or
    // was skipped due to offset > 0)
    final enriched = await _enrichFromCache(resultMap.values.toList());
    yield _applyFilter(trimmed, enriched, useServerSort);
  }

  /// Applies the configured search filter or falls back to name matching.
  List<UserProfile> _applyFilter(
    String query,
    List<UserProfile> profiles,
    bool useServerSort,
  ) {
    if (useServerSort) return profiles;

    if (_profileSearchFilter != null) {
      return _profileSearchFilter(query, profiles);
    }

    final queryLower = query.toLowerCase();
    return profiles.where((profile) {
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

  /// Fetches follower/following counts from the Funnelcake REST API.
  ///
  /// Returns [SocialCounts] or null if the API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<SocialCounts?> getSocialCounts(String pubkey) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getSocialCounts(pubkey);
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

  /// Fetches profiles for multiple pubkeys using a layered strategy.
  ///
  /// Pipeline:
  /// 1. Batch-read Drift for cached profiles
  /// 2. [FunnelcakeApiClient.getBulkProfiles] for uncached pubkeys
  /// 3. [NostrClient.queryEvents] with multi-author kind 0 filter for
  ///    any remaining
  /// 4. Batch-write all freshly fetched profiles to Drift
  /// 5. Return combined results as `Map<String, UserProfile>`
  ///
  /// Errors from the API or relay layers are caught and logged — partial
  /// results are returned rather than throwing.
  Future<Map<String, UserProfile>> fetchBatchProfiles({
    required List<String> pubkeys,
  }) async {
    if (pubkeys.isEmpty) return {};

    final results = <String, UserProfile>{};
    final remaining = Set<String>.of(pubkeys);

    // Step 1: Batch-read Drift cache
    final cached = await _userProfilesDao.getProfilesByPubkeys(pubkeys);
    for (final profile in cached) {
      results[profile.pubkey] = profile;
      remaining.remove(profile.pubkey);
    }
    if (remaining.isEmpty) return results;

    developer.log(
      'Batch fetch: ${cached.length} cached, ${remaining.length} uncached',
      name: 'ProfileRepository.fetchBatchProfiles',
    );

    final toCache = <UserProfile>[];

    // Step 2: Funnelcake REST API for uncached
    if (_funnelcakeApiClient?.isAvailable ?? false) {
      try {
        final bulkResponse = await _funnelcakeApiClient!.getBulkProfiles(
          remaining.toList(),
        );
        for (final entry in bulkResponse.profiles.entries) {
          final pubkey = entry.key;
          final data = entry.value;

          // Sentinel: user exists in FunnelCake but has never
          // published a Kind 0 profile. Remove from remaining so
          // we skip the relay/indexer fallback — the profile truly
          // doesn't exist.
          if (data['_noProfile'] == true) {
            remaining.remove(pubkey);
            continue;
          }

          final profile = UserProfile.fromFunnelcake(
            pubkey,
            data,
            eventIdPrefix: 'rest-bulk',
          );
          results[pubkey] = profile;
          toCache.add(profile);
          remaining.remove(pubkey);
        }
      } on Exception catch (e) {
        developer.log(
          'Batch REST fetch failed: $e',
          name: 'ProfileRepository.fetchBatchProfiles',
        );
      }
    }

    // Step 3: Individual relay fetches for anything still missing
    if (remaining.isNotEmpty) {
      final futures = remaining.toList().map((pubkey) async {
        try {
          return await _nostrClient.fetchProfile(pubkey);
        } on Exception {
          return null;
        }
      });
      final events = await Future.wait(futures);
      for (final event in events) {
        if (event == null || event.kind != 0) continue;
        final profile = UserProfile.fromNostrEvent(event);
        results[profile.pubkey] = profile;
        toCache.add(profile);
        remaining.remove(profile.pubkey);
      }
    }

    // Step 4: Indexer relay fallback (Purple Pages, Kind Pages)
    if (remaining.isNotEmpty) {
      try {
        final indexerEvents = await _nostrClient
            .queryEvents(
              [
                Filter(
                  kinds: [0],
                  authors: remaining.toList(),
                  limit: remaining.length,
                ),
              ],
              tempRelays: _profileIndexerRelays,
              useCache: false,
            )
            .timeout(const Duration(seconds: 5), onTimeout: () => <Event>[]);
        for (final event in indexerEvents) {
          if (event.kind != 0) continue;
          final profile = UserProfile.fromNostrEvent(event);
          results[profile.pubkey] = profile;
          toCache.add(profile);
          remaining.remove(profile.pubkey);
        }
        if (indexerEvents.isNotEmpty) {
          developer.log(
            'Indexer fallback: found ${indexerEvents.length} profiles',
            name: 'ProfileRepository.fetchBatchProfiles',
          );
        }
      } on Exception catch (e) {
        developer.log(
          'Indexer fallback failed: $e',
          name: 'ProfileRepository.fetchBatchProfiles',
        );
      }
    }

    // Step 5: Batch-write all freshly fetched to Drift
    if (toCache.isNotEmpty) {
      _knownCached.addAll(toCache.map((p) => p.pubkey));
      await _userProfilesDao.upsertProfiles(toCache);
    }

    // Mark any still-remaining pubkeys as confirmed missing so future
    // single-profile fetches skip the relay/indexer cascade.
    if (remaining.isNotEmpty) {
      _confirmedMissing.addAll(remaining);
    }

    developer.log(
      'Batch complete: ${results.length}/${pubkeys.length} resolved, '
      '${remaining.length} still missing',
      name: 'ProfileRepository.fetchBatchProfiles',
    );

    return results;
  }

  /// Enriches search results from the local SQLite cache.
  ///
  /// For each profile, fills in null fields (picture, about, etc.) from
  /// the cached version without overwriting data from search results.
  Future<List<UserProfile>> _enrichFromCache(List<UserProfile> profiles) async {
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
