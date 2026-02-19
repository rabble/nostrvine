// ABOUTME: Service for fetching and caching NIP-01 kind 0 user profile events
// ABOUTME: Manages user metadata including display names, avatars, and descriptions

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:models/models.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/signer/pubkey_only_nostr_signer.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:openvine/services/profile_cache_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for managing user profiles from Nostr kind 0 events
/// Reactive service that notifies listeners when profiles are updated
class UserProfileService extends ChangeNotifier {
  /// Well-known indexer relays that maintain broad coverage of kind 0 events
  /// These are specialized relays that aggregate profile metadata from many sources
  static const List<String> _profileIndexerRelays = [
    'wss://purplepag.es', // Purple Pages - primary metadata indexer
    'wss://user.kindpag.es', // Kind Pages - specialized user metadata indexer
  ];
  UserProfileService(
    this._nostrService, {
    required SubscriptionManager subscriptionManager,
    AnalyticsApiService? analyticsApiService,
    bool funnelcakeAvailable = false,

    /// When true, skips indexer fallback (avoids real WebSocket connections).
    /// Use in tests that mock NostrClient.
    bool skipIndexerFallback = false,
  }) : _subscriptionManager = subscriptionManager,
       _analyticsApiService = analyticsApiService,
       _funnelcakeAvailable = funnelcakeAvailable,
       _skipIndexerFallback = skipIndexerFallback;
  final NostrClient _nostrService;
  final AnalyticsApiService? _analyticsApiService;
  bool _funnelcakeAvailable;
  final bool _skipIndexerFallback;

  /// Update funnelcake availability status (called from provider when it changes)
  void setFunnelcakeAvailable(bool available) {
    _funnelcakeAvailable = available;
  }

  final ConnectionStatusService _connectionService = ConnectionStatusService();

  final Map<String, UserProfile> _profileCache =
      {}; // In-memory cache for fast access
  final Map<String, String> _activeSubscriptionIds =
      {}; // pubkey -> subscription ID
  final Set<String> _pendingRequests = {};
  bool _isInitialized = false;
  bool _isDisposed = false;

  // Batch fetching management
  String? _batchSubscriptionId;
  Timer? _batchDebounceTimer;
  Timer? _batchTimeoutTimer;
  Set<String>? _currentBatchPubkeys;
  final Set<String> _pendingBatchPubkeys = {};

  // Confirmed no profile (API said so) - skip for entire app session
  final Set<String> _knownMissingProfiles = {};

  // Gave up after failed fetches - skip this session but might retry on restart
  final Set<String> _gaveUpProfiles = {};

  // Track failed fetch attempts
  final Map<String, int> _fetchAttempts = {};

  // Completers to track when profile fetches complete
  final Map<String, Completer<UserProfile?>> _profileFetchCompleters = {};

  // Prefetch tracking
  bool _prefetchActive = false;
  DateTime? _lastPrefetchAt;

  // Background refresh rate limiting
  DateTime? _lastBackgroundRefresh;

  final SubscriptionManager _subscriptionManager;
  ProfileCacheService? _persistentCache;

  /// Set persistent cache service for profile storage
  void setPersistentCache(ProfileCacheService cacheService) {
    _persistentCache = cacheService;
    Log.debug(
      '📱 ProfileCacheService attached to UserProfileService',
      name: 'UserProfileService',
      category: LogCategory.system,
    );
  }

  /// Get cached profile for a user
  UserProfile? getCachedProfile(String pubkey) {
    // First check in-memory cache
    var profile = _profileCache[pubkey];
    if (profile != null) {
      return profile;
    }

    // If not in memory, check persistent cache
    if (_persistentCache?.isInitialized == true) {
      profile = _persistentCache!.getCachedProfile(pubkey);
      if (profile != null) {
        // Load into memory cache for faster access
        _profileCache[pubkey] = profile;
        // Notify listeners that profile is now available
        notifyListeners();
        return profile;
      }
    }

    return null;
  }

  /// Check if profile is cached
  bool hasProfile(String? pubkey) {
    if (pubkey == null || pubkey.isEmpty) return false;
    if (_profileCache.containsKey(pubkey)) return true;

    // Also check persistent cache
    if (_persistentCache?.isInitialized == true) {
      return _persistentCache!.getCachedProfile(pubkey) != null;
    }

    return false;
  }

  /// Check if we should skip fetching this profile
  /// Skip if: confirmed no profile OR gave up after failed attempts
  bool shouldSkipProfileFetch(String? pubkey) {
    if (pubkey == null || pubkey.isEmpty) return false;
    return _knownMissingProfiles.contains(pubkey) ||
        _gaveUpProfiles.contains(pubkey);
  }

  /// Mark a pubkey as having no profile - skip for entire app session
  void markProfileAsMissing(String? pubkey) {
    if (pubkey == null || pubkey.isEmpty) return;
    _knownMissingProfiles.add(pubkey);
  }

  /// Get all cached profiles
  Map<String, UserProfile> get allProfiles => Map.unmodifiable(_profileCache);

  /// Update a cached profile (e.g., after editing)
  Future<void> updateCachedProfile(UserProfile profile) async {
    // Update in-memory cache
    _profileCache[profile.pubkey] = profile;

    // Clear "missing" state since the profile clearly exists now
    _knownMissingProfiles.remove(profile.pubkey);
    _gaveUpProfiles.remove(profile.pubkey);
    _fetchAttempts.remove(profile.pubkey);

    // Update persistent cache
    if (_persistentCache?.isInitialized == true) {
      await _persistentCache!.updateCachedProfile(profile);
    }

    // Notify listeners that profile was updated
    notifyListeners();

    Log.debug(
      'Updated cached profile for ${profile.pubkey}: ${profile.bestDisplayName}',
      name: 'UserProfileService',
      category: LogCategory.system,
    );
  }

  /// Initialize the profile service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Log.verbose(
        'Initializing user profile service...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );

      if (!_nostrService.isInitialized) {
        Log.warning(
          'Nostr service not initialized, profile service will wait',
          name: 'UserProfileService',
          category: LogCategory.system,
        );
        return;
      }

      _isInitialized = true;
      Log.info(
        'User profile service initialized',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize user profile service: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Fetch profile for a specific user
  Future<UserProfile?> fetchProfile(
    String pubkey, {
    bool forceRefresh = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // If forcing refresh, clean up existing state first
    if (forceRefresh) {
      Log.debug(
        '🔄 Force refresh requested for ${pubkey}... - clearing cache and subscriptions',
        name: 'UserProfileService',
        category: LogCategory.system,
      );

      // Clear cached profile
      _profileCache.remove(pubkey);
      if (_persistentCache?.isInitialized == true) {
        _persistentCache!.removeCachedProfile(pubkey);
      }

      // Notify listeners that profile was removed for refresh
      notifyListeners();

      // Cancel any existing subscriptions for this pubkey
      _cleanupProfileRequest(pubkey);

      // Cancel and remove any pending completers for this pubkey
      final completer = _profileFetchCompleters.remove(pubkey);
      if (completer != null && !completer.isCompleted) {
        completer.complete(null); // Complete with null to unblock any waiters
      }
    }

    // Return cached profile if available and not forcing refresh
    if (!forceRefresh && hasProfile(pubkey)) {
      final cachedProfile = getCachedProfile(pubkey);

      // Check if we should do a soft refresh (background update)
      if (cachedProfile != null &&
          _persistentCache?.shouldRefreshProfile(pubkey) == true) {
        Log.debug(
          'Profile cached but stale for ${pubkey}... - will refresh in background',
          name: 'UserProfileService',
          category: LogCategory.system,
        );
        // Do a background refresh without blocking the UI
        Future.microtask(() => _backgroundRefreshProfile(pubkey));
      }

      return cachedProfile;
    }

    // Check if already requesting this profile - return existing completer's future
    // (Note: forceRefresh already cleaned up existing requests above)
    if (_pendingRequests.contains(pubkey)) {
      // Return existing completer's future if available
      if (_profileFetchCompleters.containsKey(pubkey)) {
        Log.debug(
          'Reusing existing fetch request for ${pubkey}...',
          name: 'UserProfileService',
          category: LogCategory.system,
        );
        return _profileFetchCompleters[pubkey]!.future;
      }
      return null;
    }

    // Check if we already have an active subscription for this pubkey
    // (Note: forceRefresh already cleaned up existing subscriptions above)
    if (_activeSubscriptionIds.containsKey(pubkey)) {
      Log.warning(
        'Active subscription already exists for ${pubkey}... (skipping duplicate)',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return null;
    }

    // Check connection
    if (!_connectionService.isOnline) {
      Log.debug(
        'Offline - cannot fetch profile for ${pubkey}...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return null;
    }

    try {
      _pendingRequests.add(pubkey);

      // Try REST API first (faster, no WebSocket overhead)
      // Use centralized funnelcake availability check (probes API for capability)
      if (_analyticsApiService != null && _funnelcakeAvailable) {
        final restProfile = await _analyticsApiService.getUserProfile(pubkey);
        if (restProfile != null) {
          // Create UserProfile from REST response
          final profile = UserProfile(
            pubkey: pubkey,
            name: restProfile['name'] as String?,
            displayName: restProfile['display_name'] as String?,
            about: restProfile['about'] as String?,
            picture: restProfile['picture'] as String?,
            banner: restProfile['banner'] as String?,
            nip05: restProfile['nip05'] as String?,
            lud16: restProfile['lud16'] as String?,
            rawData: restProfile,
            createdAt: DateTime.now(), // REST API doesn't return timestamp
            eventId: 'rest-api-$pubkey', // Synthetic event ID
          );

          // Cache the profile
          _profileCache[pubkey] = profile;
          if (_persistentCache?.isInitialized == true) {
            _persistentCache!.cacheProfile(profile);
          }

          _pendingRequests.remove(pubkey);
          notifyListeners();

          Log.info(
            '✅ Got profile via REST API: ${profile.bestDisplayName}',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
          return profile;
        }
        // REST API didn't have the profile, fall through to WebSocket
      }

      // Fall back to WebSocket relay batch fetch
      // Create a completer to track this fetch request
      final completer = Completer<UserProfile?>();
      _profileFetchCompleters[pubkey] = completer;

      // Add to batch instead of creating individual subscription
      _pendingBatchPubkeys.add(pubkey);

      // DEBUG: Log stack trace to find caller
      final stackTrace = StackTrace.current;
      Log.warning(
        '🔍 DEBUG: Adding pubkey to batch fetch: $pubkey\n'
        'Stack trace:\n$stackTrace',
        name: 'UserProfileService',
        category: LogCategory.system,
      );

      // Cancel existing debounce timer and create new one
      _batchDebounceTimer?.cancel();
      _batchDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        _executeBatchFetch();
      });

      // Return the completer's future - it will complete when batch fetch finishes
      return completer.future;
    } catch (e) {
      Log.error(
        'Failed to fetch profile for ${pubkey}: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      _pendingRequests.remove(pubkey);
      _pendingBatchPubkeys.remove(pubkey);

      // Complete completer with error if it exists
      final completer = _profileFetchCompleters.remove(pubkey);
      if (completer != null && !completer.isCompleted) {
        completer.completeError(e);
      }

      return null;
    }
  }

  /// Handle incoming profile event
  void _handleProfileEvent(Event event) {
    try {
      if (event.kind != 0) return;

      // Reset timeout timer on each event received - wait 10s after last event
      _resetBatchTimeout();

      // Parse profile data from event content
      final profile = UserProfile.fromNostrEvent(event);

      // Check if this is newer than existing cached profile
      final existingProfile = _profileCache[event.pubkey];
      if (existingProfile != null) {
        // Accept the new profile if:
        // 1. It has a different event ID (definitely a new event)
        // 2. OR it has a newer or equal timestamp (allow same-second updates)
        final isDifferentEvent = existingProfile.eventId != profile.eventId;
        final isNewerOrSame = !existingProfile.createdAt.isAfter(
          profile.createdAt,
        );

        if (!isDifferentEvent && !isNewerOrSame) {
          Log.debug(
            '⚠️ Received older profile event, ignoring',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
          _cleanupProfileRequest(event.pubkey);
          return;
        }
      }

      // Cache the profile in memory
      _profileCache[event.pubkey] = profile;

      // Also save to persistent cache
      if (_persistentCache?.isInitialized == true) {
        _persistentCache!.cacheProfile(profile);
      }

      // Notify listeners that profile is now available
      notifyListeners();

      // Complete any pending fetch requests for this profile
      final completer = _profileFetchCompleters.remove(event.pubkey);
      if (completer != null && !completer.isCompleted) {
        completer.complete(profile);
        Log.debug(
          '✅ Completed fetch request for ${event.pubkey}',
          name: 'UserProfileService',
          category: LogCategory.system,
        );
      }

      _cleanupProfileRequest(event.pubkey);
    } catch (e) {
      Log.error(
        'Error parsing profile event: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    }
  }

  /// Reset the batch timeout timer (called on each event received)
  void _resetBatchTimeout() {
    if (_currentBatchPubkeys == null || _currentBatchPubkeys!.isEmpty) return;

    _batchTimeoutTimer?.cancel();
    _batchTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (_currentBatchPubkeys != null && _currentBatchPubkeys!.isNotEmpty) {
        Log.warning(
          '⏰ Batch fetch timeout - completing after 10s idle (${_currentBatchPubkeys!.length} profiles pending)',
          name: 'UserProfileService',
          category: LogCategory.system,
        );
        _completeBatchFetch(_currentBatchPubkeys!);
      }
    });
  }

  /// Cleanup profile request
  void _cleanupProfileRequest(String pubkey) {
    _pendingRequests.remove(pubkey);

    // Clean up managed subscription
    final subscriptionId = _activeSubscriptionIds.remove(pubkey);
    if (subscriptionId != null) {
      _subscriptionManager.cancelSubscription(subscriptionId);
    }
  }

  /// Aggressively pre-fetch profiles for immediate display (no debouncing)
  Future<void> prefetchProfilesImmediately(List<String> pubkeys) async {
    if (pubkeys.isEmpty) return;

    // Filter out already cached profiles and pending requests
    final pubkeysToFetch = pubkeys
        .where(
          (pubkey) =>
              !_profileCache.containsKey(pubkey) &&
              !_pendingRequests.contains(pubkey) &&
              !shouldSkipProfileFetch(pubkey),
        )
        .toList();

    if (pubkeysToFetch.isEmpty) return;

    Log.debug(
      '⚡ Immediate pre-fetch for ${pubkeysToFetch.length} profiles',
      name: 'UserProfileService',
      category: LogCategory.system,
    );

    // Prevent flooding: if a prefetch is currently active, skip co-incident calls
    if (_prefetchActive) {
      Log.debug(
        'Prefetch suppressed: another prefetch is active',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return;
    }

    // Simple rate-limit: ignore if last prefetch finished very recently (< 1s)
    if (_lastPrefetchAt != null &&
        DateTime.now().difference(_lastPrefetchAt!) <
            const Duration(seconds: 1)) {
      Log.debug(
        'Prefetch suppressed: rate limit within 1s',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return;
    }

    // Add to pending requests
    _pendingRequests.addAll(pubkeysToFetch);

    try {
      _prefetchActive = true;

      // Try REST bulk fetch first (much faster than WebSocket)
      if (_analyticsApiService != null && _funnelcakeAvailable) {
        try {
          final bulkProfiles = await _analyticsApiService.getBulkProfiles(
            pubkeysToFetch,
          );
          if (bulkProfiles.isNotEmpty) {
            var realProfiles = 0;
            var noProfileUsers = 0;

            // Process profiles from REST
            for (final entry in bulkProfiles.entries) {
              final pubkey = entry.key;
              final profileData = entry.value;

              // Check for sentinel value indicating user exists but has no profile
              if (profileData['_noProfile'] == true) {
                // User exists but never created a Kind 0 profile
                // Mark as missing so we don't waste time trying relays
                markProfileAsMissing(pubkey);
                _pendingRequests.remove(pubkey);
                noProfileUsers++;
                continue;
              }

              // Real profile data - cache it
              final profile = UserProfile(
                pubkey: pubkey,
                name: profileData['name'] as String?,
                displayName: profileData['display_name'] as String?,
                about: profileData['about'] as String?,
                picture: profileData['picture'] as String?,
                banner: profileData['banner'] as String?,
                nip05: profileData['nip05'] as String?,
                lud16: profileData['lud16'] as String?,
                rawData: profileData,
                createdAt: DateTime.now(),
                eventId: 'rest-bulk-$pubkey',
              );
              _profileCache[pubkey] = profile;
              if (_persistentCache?.isInitialized == true) {
                _persistentCache!.cacheProfile(profile);
              }
              _pendingRequests.remove(pubkey);
              realProfiles++;
            }

            if (realProfiles > 0 || noProfileUsers > 0) {
              Log.debug(
                '✅ REST bulk: $realProfiles profiles cached, $noProfileUsers users have no profile',
                name: 'UserProfileService',
                category: LogCategory.system,
              );
            }

            notifyListeners();

            // Remove all handled pubkeys from list (both real profiles AND no-profile users)
            final remaining = pubkeysToFetch
                .where((pk) => !bulkProfiles.containsKey(pk))
                .toList();
            if (remaining.isEmpty) {
              _prefetchActive = false;
              _lastPrefetchAt = DateTime.now();
              return;
            }
            // Continue with WebSocket for remaining profiles (those not in API at all)
            pubkeysToFetch
              ..clear()
              ..addAll(remaining);
          }
        } catch (e) {
          Log.debug(
            'REST bulk fetch failed, falling back to WebSocket: $e',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
        }
      }

      // Fall back to WebSocket for remaining profiles
      if (pubkeysToFetch.isEmpty) {
        _prefetchActive = false;
        _lastPrefetchAt = DateTime.now();
        return;
      }

      // Create filter for kind 0 events from these users
      final filter = Filter(
        kinds: [0],
        authors: pubkeysToFetch,
        limit: math.min(
          pubkeysToFetch.length,
          100,
        ), // Smaller batches for immediate fetch
      );

      // Track which profiles we're fetching in this batch
      final thisBatchPubkeys = Set<String>.from(pubkeysToFetch);

      // Subscribe to profile events using SubscriptionManager with highest priority
      await _subscriptionManager.createSubscription(
        name: 'profile_prefetch_${DateTime.now().millisecondsSinceEpoch}',
        filters: [filter],
        onEvent: _handleProfileEvent,
        onError: (error) => Log.error(
          'Prefetch profile error: $error',
          name: 'UserProfileService',
          category: LogCategory.system,
        ),
        onComplete: () => _completePrefetch(thisBatchPubkeys),
        priority: 0, // Highest priority for immediate prefetch
      );

      Log.debug(
        '⚡ Sent WebSocket prefetch request for ${pubkeysToFetch.length} remaining profiles',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to prefetch profiles: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      _pendingRequests.removeAll(pubkeysToFetch);
      _prefetchActive = false;
      _lastPrefetchAt = DateTime.now();
    }
  }

  /// Complete the prefetch and clean up
  void _completePrefetch(Set<String> batchPubkeys) {
    // Mark unfetched profiles as missing
    final unfetchedPubkeys = batchPubkeys
        .where((pubkey) => !_profileCache.containsKey(pubkey))
        .toSet();
    final fetchedCount = batchPubkeys.length - unfetchedPubkeys.length;

    if (unfetchedPubkeys.isNotEmpty) {
      Log.debug(
        '⚡ Prefetch completed - fetched $fetchedCount/${batchPubkeys.length}, ${unfetchedPubkeys.length} not found (will retry)',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      // Don't mark as missing - could be network issue, allow retry
    } else {
      Log.debug(
        '⚡ Prefetch completed - all ${batchPubkeys.length} profiles fetched',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    }

    // Clean up pending requests for this batch
    _pendingRequests.removeAll(batchPubkeys);

    // Mark cycle done and set last timestamp
    _prefetchActive = false;
    _lastPrefetchAt = DateTime.now();
  }

  /// Batch fetch profiles for multiple users
  Future<void> fetchMultipleProfiles(
    List<String> pubkeys, {
    bool forceRefresh = false,
  }) async {
    if (pubkeys.isEmpty) return;

    // DEBUG: Log incoming batch fetch request with caller
    final stackLines = StackTrace.current
        .toString()
        .split('\n')
        .take(6)
        .join('\n');
    Log.info(
      '📋 fetchMultipleProfiles called with ${pubkeys.length} pubkeys: '
      '${pubkeys.take(3).toList()}...\nCaller:\n$stackLines',
      name: 'UserProfileService',
      category: LogCategory.system,
    );

    // Filter out already cached profiles unless forcing refresh
    final filteredPubkeys = forceRefresh
        ? pubkeys
        : pubkeys
              .where(
                (pubkey) =>
                    !_profileCache.containsKey(pubkey) &&
                    !_pendingRequests.contains(pubkey),
              )
              .toList();

    // Further filter out known missing profiles to avoid relay spam
    final pubkeysToFetch = filteredPubkeys
        .where((pubkey) => forceRefresh || !shouldSkipProfileFetch(pubkey))
        .toList();

    final skippedCount = filteredPubkeys.length - pubkeysToFetch.length;
    if (skippedCount > 0) {
      Log.debug(
        'Skipping $skippedCount known missing profiles to avoid relay spam',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    }

    if (pubkeysToFetch.isEmpty) {
      return;
    }

    // Add to pending batch
    _pendingBatchPubkeys.addAll(pubkeysToFetch);
    _pendingRequests.addAll(pubkeysToFetch);

    // Cancel existing debounce timer
    _batchDebounceTimer?.cancel();

    // If we already have an active subscription, let it complete
    if (_batchSubscriptionId != null) {
      Log.debug(
        '📦 Added ${pubkeysToFetch.length} profiles to pending batch (total pending: ${_pendingBatchPubkeys.length})',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return;
    }

    // Debounce: reduced delay for faster profile loading
    _batchDebounceTimer = Timer(
      const Duration(milliseconds: 50),
      _executeBatchFetch,
    );
  }

  /// Execute the actual batch fetch
  Future<void> _executeBatchFetch() async {
    if (_pendingBatchPubkeys.isEmpty) return;

    // Cancel any existing timeout from previous batch
    _batchTimeoutTimer?.cancel();

    // Move pending to current batch
    final batchPubkeys = _pendingBatchPubkeys.toList();
    _pendingBatchPubkeys.clear();

    // Track current batch for timeout handling
    _currentBatchPubkeys = Set<String>.from(batchPubkeys);

    Log.debug(
      '🔄 Executing batch fetch for ${batchPubkeys.length} profiles...',
      name: 'UserProfileService',
      category: LogCategory.system,
    );
    Log.debug(
      '📋 Sample pubkeys: ${batchPubkeys.take(3).map((p) => p).join(", ")}...',
      name: 'UserProfileService',
      category: LogCategory.system,
    );

    try {
      // Create filter for kind 0 events from these users
      final filter = Filter(
        kinds: [0],
        authors: batchPubkeys,
        limit: math.min(
          batchPubkeys.length,
          500,
        ), // Nostr protocol recommended limit
      );

      // Track which profiles we're fetching in this batch
      final thisBatchPubkeys = Set<String>.from(batchPubkeys);

      // Start timeout timer - complete batch after 10 seconds even if EOSE doesn't arrive
      _batchTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (_currentBatchPubkeys != null && _currentBatchPubkeys!.isNotEmpty) {
          Log.warning(
            '⏰ Batch fetch timeout - completing without EOSE (${_currentBatchPubkeys!.length} profiles pending)',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
          _completeBatchFetch(_currentBatchPubkeys!);
        }
      });

      // Subscribe to profile events using SubscriptionManager
      final subscriptionId = await _subscriptionManager.createSubscription(
        name: 'profile_batch_${DateTime.now().millisecondsSinceEpoch}',
        filters: [filter],
        onEvent: _handleProfileEvent,
        onError: (error) => Log.error(
          'Batch profile fetch error: $error',
          name: 'UserProfileService',
          category: LogCategory.system,
        ),
        onComplete: () => _completeBatchFetch(thisBatchPubkeys),
        priority: 1, // High priority for profile fetches
      );

      // Store subscription ID for cleanup
      _batchSubscriptionId = subscriptionId;
    } catch (e) {
      Log.error(
        'Failed to batch fetch profiles: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      _batchTimeoutTimer?.cancel();
      _completeBatchFetch(batchPubkeys.toSet());
    }
  }

  /// Complete the batch fetch and clean up
  void _completeBatchFetch(Set<String> batchPubkeys) {
    // Bail out early if disposed (timer callback may fire after disposal)
    if (_isDisposed) return;

    // Cancel timeout timer
    _batchTimeoutTimer?.cancel();
    _batchTimeoutTimer = null;

    // Clear current batch tracking
    _currentBatchPubkeys = null;

    // Cancel managed subscription
    if (_batchSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_batchSubscriptionId!);
      _batchSubscriptionId = null;
    }

    // Check which profiles were not found
    final unfetchedPubkeys = batchPubkeys
        .where((pubkey) => !_profileCache.containsKey(pubkey))
        .toSet();
    final fetchedCount = batchPubkeys.length - unfetchedPubkeys.length;

    // Clear attempt tracking for successfully fetched profiles
    for (final pubkey in batchPubkeys) {
      if (_profileCache.containsKey(pubkey)) {
        _fetchAttempts.remove(pubkey);
      }
    }

    if (unfetchedPubkeys.isNotEmpty) {
      Log.debug(
        '⏰ Batch profile fetch completed - fetched $fetchedCount/${batchPubkeys.length} profiles, ${unfetchedPubkeys.length} not found',
        name: 'UserProfileService',
        category: LogCategory.system,
      );

      // Track attempts - on first failure try indexers, on second mark as missing
      for (final pubkey in unfetchedPubkeys) {
        final attempts = (_fetchAttempts[pubkey] ?? 0) + 1;
        _fetchAttempts[pubkey] = attempts;

        if (attempts == 1) {
          // First failure: Try indexer relays as fallback
          Log.info(
            '🔍 Profile not found on main relay, trying indexers: $pubkey',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
          // Fire and forget - indexer query will complete the completer if found
          unawaited(_queryIndexersForProfile(pubkey));
        } else if (attempts >= 2) {
          // Second failure (indexers also failed): stop trying this session
          _gaveUpProfiles.add(pubkey);
          _fetchAttempts.remove(pubkey);
          Log.debug(
            '⚠️ Gave up on profile after $attempts attempts: $pubkey',
            name: 'UserProfileService',
            category: LogCategory.system,
          );

          // Complete pending fetch requests with null
          final completer = _profileFetchCompleters.remove(pubkey);
          if (completer != null && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }

      notifyListeners();
    } else {
      Log.info(
        '✅ Batch profile fetch completed - fetched all ${batchPubkeys.length} profiles',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    }

    // Clean up pending requests for this batch
    _pendingRequests.removeAll(batchPubkeys);

    // If we have more pending profiles, start a new batch
    if (_pendingBatchPubkeys.isNotEmpty) {
      Log.debug(
        '📦 Starting next batch for ${_pendingBatchPubkeys.length} pending profiles...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      Timer(const Duration(milliseconds: 50), _executeBatchFetch);
    }
  }

  /// Query profile indexer relays for a kind 0 profile.
  /// Uses a temporary NostrClient to avoid adding indexers to the main relay set,
  /// which would trigger RelaySetChangeBridge, force reconnects, and feed resets.
  /// This prevents lag and stale WebSocket issues for users who don't have
  /// NIP-65 relay lists.
  Future<void> _queryIndexersForProfile(String pubkey) async {
    if (_isDisposed) return;
    if (_skipIndexerFallback) {
      _pendingBatchPubkeys.add(pubkey);
      _batchDebounceTimer?.cancel();
      _batchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
        _executeBatchFetch();
      });
      return;
    }

    Log.debug(
      '🔍 Querying ${_profileIndexerRelays.length} indexers for profile: $pubkey',
      name: 'UserProfileService',
      category: LogCategory.system,
    );

    NostrClient? tempClient;
    try {
      tempClient = NostrClient(
        config: NostrClientConfig(
          signer: PubkeyOnlyNostrSigner(
            '0000000000000000000000000000000000000000000000000000000000000000',
          ),
        ),
        relayManagerConfig: RelayManagerConfig(
          defaultRelayUrl: _profileIndexerRelays.first,
          storage: InMemoryRelayStorage(),
        ),
      );
      await tempClient.initialize();

      // Add remaining indexers (first is already default)
      for (var i = 1; i < _profileIndexerRelays.length; i++) {
        await tempClient
            .addRelay(_profileIndexerRelays[i])
            .timeout(const Duration(seconds: 3), onTimeout: () => false);
      }

      final filter = Filter(kinds: [0], authors: [pubkey], limit: 1);
      final events = await tempClient
          .queryEvents([filter])
          .timeout(const Duration(seconds: 4), onTimeout: () => <Event>[]);

      final foundEvent = events.isNotEmpty ? events.first : null;
      if (foundEvent != null) {
        Log.info(
          '✅ Found profile on indexer: $pubkey',
          name: 'UserProfileService',
          category: LogCategory.system,
        );
        _handleProfileEvent(foundEvent);
        _fetchAttempts.remove(pubkey);
        _pendingRequests.remove(pubkey);
        return;
      }
    } catch (e) {
      Log.debug(
        'Indexer profile query failed: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    } finally {
      tempClient?.dispose();
    }

    Log.warning(
      '❌ Profile not found on any indexer: $pubkey',
      name: 'UserProfileService',
      category: LogCategory.system,
    );

    _pendingBatchPubkeys.add(pubkey);
    _batchDebounceTimer?.cancel();
    _batchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      _executeBatchFetch();
    });
  }

  /// Get display name for a user (with fallback)
  String getDisplayName(String pubkey) {
    final profile = _profileCache[pubkey];
    if (profile?.displayName?.isNotEmpty == true) {
      return profile!.displayName!;
    }
    if (profile?.name?.isNotEmpty == true) {
      return profile!.name!;
    }
    // Immediate fallback to truncated npub
    return NostrKeyUtils.truncateNpub(pubkey);
  }

  /// Remove specific profile from cache
  void removeProfile(String pubkey) {
    if (_profileCache.remove(pubkey) != null) {
      // Notify listeners that profile was removed
      notifyListeners();

      Log.debug(
        '📱️ Removed profile from cache: ${pubkey}...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    }
  }

  /// Background refresh for stale profiles
  Future<void> _backgroundRefreshProfile(String pubkey) async {
    // Don't refresh if already pending
    if (_pendingRequests.contains(pubkey) ||
        _activeSubscriptionIds.containsKey(pubkey)) {
      return;
    }

    // Rate limit background refreshes to avoid overwhelming the UI
    final now = DateTime.now();
    if (_lastBackgroundRefresh != null &&
        now.difference(_lastBackgroundRefresh!).inSeconds < 30) {
      Log.debug(
        'Rate limiting background refresh for ${pubkey}...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return;
    }

    try {
      Log.debug(
        'Background refresh for stale profile ${pubkey}...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );

      _lastBackgroundRefresh = now;

      // Use a longer timeout for background refreshes to reduce urgency
      await fetchProfile(pubkey, forceRefresh: true);
    } catch (e) {
      Log.error(
        'Background refresh failed for ${pubkey}: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    }
  }

  /// Search for users using NIP-0 search capability
  Future<List<UserProfile>> searchUsers(String query, {int? limit}) async {
    if (query.trim().isEmpty) {
      throw ArgumentError('Search query cannot be empty');
    }

    try {
      Log.info(
        '🔍 Starting users search for: "$query"',
        name: 'UserProfileService',
        category: LogCategory.system,
      );

      // Create completer to track search completion
      final searchCompleter = Completer<void>();

      // Use the NostrService searchUsers method
      final searchStream = _nostrService.searchUsers(query, limit: limit ?? 50);

      final foundUsers = <UserProfile>{};

      late final StreamSubscription<Event> subscription;

      // Subscribe to search results
      subscription = searchStream.listen(
        (event) {
          // Parse user event
          final userEvent = UserProfile.fromNostrEvent(event);
          _profileCache[event.pubkey] = userEvent;
          foundUsers.add(userEvent);
        },
        onError: (error) {
          Log.error(
            'Search error: $error',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
          // Search subscriptions can fail without affecting main feeds
          if (!searchCompleter.isCompleted) {
            searchCompleter.completeError(error);
          }
        },
        onDone: () {
          // Search completed naturally - this is expected behavior
          Log.info(
            'Search completed. Found ${foundUsers.length} results',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
          // Search subscription clean up - remove from tracking
          subscription.cancel();
          if (!searchCompleter.isCompleted) {
            searchCompleter.complete();
          }
        },
      );

      // Wait for search to complete with timeout
      await searchCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Log.warning(
            'Search timed out after 10 seconds',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
          // Don't throw - return partial results
        },
      );

      return foundUsers.toList();
    } catch (e) {
      Log.error(
        'Failed to start search: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Test helper method to process profile events directly
  /// Only for testing purposes
  void handleProfileEventForTesting(Event event) {
    _handleProfileEvent(event);
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Cancel batch operations
    _batchDebounceTimer?.cancel();
    _batchTimeoutTimer?.cancel();

    // Cancel batch subscription
    if (_batchSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_batchSubscriptionId!);
      _batchSubscriptionId = null;
    }

    // Cancel all active managed subscriptions
    for (final subscriptionId in _activeSubscriptionIds.values) {
      _subscriptionManager.cancelSubscription(subscriptionId);
    }
    _activeSubscriptionIds.clear();

    // Complete any pending fetch completers
    for (final completer in _profileFetchCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
    _profileFetchCompleters.clear();

    // Dispose connection service to cancel its timer
    _connectionService.dispose();

    // Clean up remaining state
    _pendingRequests.clear();
    _profileCache.clear();
    _pendingBatchPubkeys.clear();
    _knownMissingProfiles.clear();
    _gaveUpProfiles.clear();
    _fetchAttempts.clear();

    Log.debug(
      '🗑️ UserProfileService disposed',
      name: 'UserProfileService',
      category: LogCategory.system,
    );

    // Call super.dispose() to properly clean up ChangeNotifier
    super.dispose();
  }
}

/// Exception thrown by user profile service operations
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class UserProfileServiceException implements Exception {
  const UserProfileServiceException(this.message);
  final String message;

  @override
  String toString() => 'UserProfileServiceException: $message';
}
