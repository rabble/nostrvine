// ABOUTME: Service for fetching and caching NIP-01 kind 0 user profile events
// ABOUTME: Manages user metadata including display names, avatars, and descriptions

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import '../models/user_profile.dart';
import 'nostr_service_interface.dart';
import 'connection_status_service.dart';
import 'subscription_manager.dart';
import 'profile_cache_service.dart';
import '../utils/unified_logger.dart';

/// Service for managing user profiles from Nostr kind 0 events
class UserProfileService extends ChangeNotifier {
  final INostrService _nostrService;
  final ConnectionStatusService _connectionService = ConnectionStatusService();
  
  final Map<String, UserProfile> _profileCache = {}; // In-memory cache for fast access
  final Map<String, StreamSubscription> _profileSubscriptions = {};
  final Map<String, String> _activeSubscriptionIds = {}; // pubkey -> subscription ID
  final Set<String> _pendingRequests = {};
  bool _isInitialized = false;
  
  // Batch fetching management
  StreamSubscription? _batchSubscription;
  Timer? _batchTimeout;
  Timer? _batchDebounceTimer;
  final Set<String> _pendingBatchPubkeys = {};
  
  // Missing profile tracking to avoid relay spam
  final Set<String> _knownMissingProfiles = {};
  final Map<String, DateTime> _missingProfileRetryAfter = {};
  
  SubscriptionManager? _subscriptionManager;
  ProfileCacheService? _persistentCache;
  
  UserProfileService(this._nostrService);
  
  /// Set subscription manager for optimized profile fetching
  void setSubscriptionManager(SubscriptionManager subscriptionManager) {
    _subscriptionManager = subscriptionManager;
    Log.debug('SubscriptionManager attached to UserProfileService', name: 'UserProfileService', category: LogCategory.system);
  }
  
  /// Set persistent cache service for profile storage
  void setPersistentCache(ProfileCacheService cacheService) {
    _persistentCache = cacheService;
    Log.debug('� ProfileCacheService attached to UserProfileService', name: 'UserProfileService', category: LogCategory.system);
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
        return profile;
      }
    }
    
    return null;
  }
  
  /// Check if profile is cached
  bool hasProfile(String pubkey) {
    if (_profileCache.containsKey(pubkey)) return true;
    
    // Also check persistent cache
    if (_persistentCache?.isInitialized == true) {
      return _persistentCache!.getCachedProfile(pubkey) != null;
    }
    
    return false;
  }
  
  /// Check if we should skip fetching this profile to avoid relay spam
  bool shouldSkipProfileFetch(String pubkey) {
    // Don't fetch if we know it's missing and retry time hasn't passed
    if (_knownMissingProfiles.contains(pubkey)) {
      final retryAfter = _missingProfileRetryAfter[pubkey];
      if (retryAfter != null && DateTime.now().isBefore(retryAfter)) {
        return true; // Still in cooldown period
      }
      // Cooldown expired, remove from missing list to allow retry
      _knownMissingProfiles.remove(pubkey);
      _missingProfileRetryAfter.remove(pubkey);
    }
    return false;
  }
  
  /// Mark a pubkey as having no profile to avoid future requests
  void markProfileAsMissing(String pubkey) {
    _knownMissingProfiles.add(pubkey);
    // Retry after 1 hour for missing profiles
    _missingProfileRetryAfter[pubkey] = DateTime.now().add(const Duration(hours: 1));
    Log.debug('Marked profile as missing: ${pubkey.substring(0, 8)}... (retry after 1 hour)', 
        name: 'UserProfileService', category: LogCategory.system);
  }
  
  /// Get all cached profiles
  Map<String, UserProfile> get allProfiles => Map.unmodifiable(_profileCache);
  
  /// Update a cached profile (e.g., after editing)
  Future<void> updateCachedProfile(UserProfile profile) async {
    // Update in-memory cache
    _profileCache[profile.pubkey] = profile;
    
    // Update persistent cache
    if (_persistentCache?.isInitialized == true) {
      await _persistentCache!.updateCachedProfile(profile);
    }
    
    Log.debug('Updated cached profile for ${profile.pubkey.substring(0, 8)}: ${profile.bestDisplayName}', name: 'UserProfileService', category: LogCategory.system);
    notifyListeners();
  }
  
  /// Initialize the profile service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      Log.verbose('Initializing user profile service...', name: 'UserProfileService', category: LogCategory.system);
      
      if (!_nostrService.isInitialized) {
        Log.warning('Nostr service not initialized, profile service will wait', name: 'UserProfileService', category: LogCategory.system);
        return;
      }
      
      _isInitialized = true;
      Log.info('User profile service initialized', name: 'UserProfileService', category: LogCategory.system);
    } catch (e) {
      Log.error('Failed to initialize user profile service: $e', name: 'UserProfileService', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Fetch profile for a specific user
  Future<UserProfile?> fetchProfile(String pubkey, {bool forceRefresh = false}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // If forcing refresh, clean up existing state first
    if (forceRefresh) {
      Log.debug('🔄 Force refresh requested for ${pubkey.substring(0, 8)}... - clearing cache and subscriptions', name: 'UserProfileService', category: LogCategory.system);
      
      // Clear cached profile
      _profileCache.remove(pubkey);
      if (_persistentCache?.isInitialized == true) {
        _persistentCache!.removeCachedProfile(pubkey);
      }
      
      // Cancel any existing subscriptions for this pubkey
      _cleanupProfileRequest(pubkey);
    }
    
    // Return cached profile if available and not forcing refresh
    if (!forceRefresh && hasProfile(pubkey)) {
      final cachedProfile = getCachedProfile(pubkey);
      
      // Check if we should do a soft refresh (background update)
      if (cachedProfile != null && _persistentCache?.shouldRefreshProfile(pubkey) == true) {
        Log.debug('Profile cached but stale for ${pubkey.substring(0, 8)}... - will refresh in background', name: 'UserProfileService', category: LogCategory.system);
        // Do a background refresh without blocking the UI
        Future.microtask(() => _backgroundRefreshProfile(pubkey));
      }
      
      Log.verbose('Returning cached profile for ${pubkey.substring(0, 8)}...', name: 'UserProfileService', category: LogCategory.system);
      return cachedProfile;
    }
    
    // Check if already requesting this profile - STOP HERE, don't create duplicate subscriptions
    // (Note: forceRefresh already cleaned up existing requests above)
    if (_pendingRequests.contains(pubkey)) {
      Log.warning('⏳ Profile request already pending for ${pubkey.substring(0, 8)}... (skipping duplicate)', name: 'UserProfileService', category: LogCategory.system);
      return null;
    }
    
    // Check if we already have an active subscription for this pubkey
    // (Note: forceRefresh already cleaned up existing subscriptions above)
    if (_profileSubscriptions.containsKey(pubkey) || _activeSubscriptionIds.containsKey(pubkey)) {
      Log.warning('Active subscription already exists for ${pubkey.substring(0, 8)}... (skipping duplicate)', name: 'UserProfileService', category: LogCategory.system);
      return null;
    }
    
    // Check connection
    if (!_connectionService.isOnline) {
      Log.debug('Offline - cannot fetch profile for ${pubkey.substring(0, 8)}...', name: 'UserProfileService', category: LogCategory.system);
      return null;
    }
    
    try {
      _pendingRequests.add(pubkey);
      Log.verbose('🔍 DEBUG: Starting profile fetch for user: ${pubkey.substring(0, 8)}...', name: 'UserProfileService', category: LogCategory.system);
      Log.info('🔍 DEBUG: forceRefresh=$forceRefresh', name: 'UserProfileService', category: LogCategory.system);
      
      // Create filter for kind 0 events from this user
      final filter = Filter(
        kinds: [0], // NIP-01 user metadata
        authors: [pubkey],
        limit: 1, // Only need the most recent profile
        h: ['vine'], // vine.hol.is optimized for vine-tagged content - gets more results!
      );
      
      // Use managed subscription if available
      if (_subscriptionManager != null) {
        final subscriptionId = await _subscriptionManager!.createSubscription(
          name: 'profile_${pubkey.substring(0, 8)}',
          filters: [filter],
          onEvent: (event) => _handleProfileEvent(event),
          onError: (error) => _handleProfileError(pubkey, error),
          onComplete: () => _handleProfileComplete(pubkey),
          timeout: const Duration(seconds: 10),
          priority: 2, // High priority for profile fetches (user-facing)
        );
        
        _activeSubscriptionIds[pubkey] = subscriptionId;
      } else {
        // Fall back to direct subscription
        final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
        final subscription = eventStream.listen(
          (event) => _handleProfileEvent(event),
          onError: (error) => _handleProfileError(pubkey, error),
          onDone: () => _handleProfileComplete(pubkey),
        );
        
        _profileSubscriptions[pubkey] = subscription;
        
        // Set timeout for profile fetch
        Timer(const Duration(seconds: 10), () {
          if (_pendingRequests.contains(pubkey)) {
            _cleanupProfileRequest(pubkey);
          }
        });
      }
      
      return null; // Profile will be available in cache once loaded
    } catch (e) {
      Log.error('Failed to fetch profile for ${pubkey.substring(0, 8)}: $e', name: 'UserProfileService', category: LogCategory.system);
      _pendingRequests.remove(pubkey);
      return null;
    }
  }
  
  /// Handle incoming profile event
  void _handleProfileEvent(Event event) {
    try {
      if (event.kind != 0) return;
      
      Log.info('📨 Received profile event for ${event.pubkey.substring(0, 8)}...', name: 'UserProfileService', category: LogCategory.system);
      Log.info('  - Event ID: ${event.id}', name: 'UserProfileService', category: LogCategory.system);
      Log.info('  - Created at: ${event.createdAt}', name: 'UserProfileService', category: LogCategory.system);
      Log.info('  - Content: ${event.content}', name: 'UserProfileService', category: LogCategory.system);
      Log.info('🔍 DEBUG: Event received in _handleProfileEvent', name: 'UserProfileService', category: LogCategory.system);
      
      // Parse profile data from event content
      final profile = UserProfile.fromNostrEvent(event);
      
      Log.info('  - Parsed name: ${profile.name}', name: 'UserProfileService', category: LogCategory.system);
      Log.info('  - Parsed displayName: ${profile.displayName}', name: 'UserProfileService', category: LogCategory.system);
      Log.info('  - Parsed about: ${profile.about}', name: 'UserProfileService', category: LogCategory.system);
      
      // Check if this is newer than existing cached profile
      final existingProfile = _profileCache[event.pubkey];
      if (existingProfile != null) {
        Log.info('🔄 Existing profile found, comparing timestamps:', name: 'UserProfileService', category: LogCategory.system);
        Log.info('  - Existing eventId: ${existingProfile.eventId}', name: 'UserProfileService', category: LogCategory.system);
        Log.info('  - Existing createdAt: ${existingProfile.createdAt}', name: 'UserProfileService', category: LogCategory.system);
        Log.info('  - New createdAt: ${profile.createdAt}', name: 'UserProfileService', category: LogCategory.system);
        
        if (existingProfile.createdAt.isAfter(profile.createdAt)) {
          Log.warning('⚠️ Received older profile event, ignoring', name: 'UserProfileService', category: LogCategory.system);
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
      
      _cleanupProfileRequest(event.pubkey);
      
      Log.info('✅ Cached profile for ${event.pubkey.substring(0, 8)}: ${profile.bestDisplayName}', name: 'UserProfileService', category: LogCategory.system);
      notifyListeners();
    } catch (e) {
      Log.error('Error parsing profile event: $e', name: 'UserProfileService', category: LogCategory.system);
    }
  }
  
  /// Handle profile fetch error
  void _handleProfileError(String pubkey, dynamic error) {
    Log.error('Profile fetch error for ${pubkey.substring(0, 8)}: $error', name: 'UserProfileService', category: LogCategory.system);
    _cleanupProfileRequest(pubkey);
  }
  
  /// Handle profile fetch completion
  void _handleProfileComplete(String pubkey) {
    _cleanupProfileRequest(pubkey);
  }
  
  /// Cleanup profile request
  void _cleanupProfileRequest(String pubkey) {
    _pendingRequests.remove(pubkey);
    
    // Clean up managed subscription
    final subscriptionId = _activeSubscriptionIds.remove(pubkey);
    if (subscriptionId != null && _subscriptionManager != null) {
      _subscriptionManager!.cancelSubscription(subscriptionId);
    }
    
    // Clean up direct subscription
    final subscription = _profileSubscriptions.remove(pubkey);
    subscription?.cancel();
  }
  
  /// Batch fetch profiles for multiple users
  Future<void> fetchMultipleProfiles(List<String> pubkeys, {bool forceRefresh = false}) async {
    if (pubkeys.isEmpty) return;
    
    // Filter out already cached profiles unless forcing refresh
    final filteredPubkeys = forceRefresh 
        ? pubkeys 
        : pubkeys.where((pubkey) => !_profileCache.containsKey(pubkey) && !_pendingRequests.contains(pubkey)).toList();
    
    // Further filter out known missing profiles to avoid relay spam
    final pubkeysToFetch = filteredPubkeys.where((pubkey) => 
        forceRefresh || !shouldSkipProfileFetch(pubkey)).toList();
    
    final skippedCount = filteredPubkeys.length - pubkeysToFetch.length;
    if (skippedCount > 0) {
      Log.debug('Skipping ${skippedCount} known missing profiles to avoid relay spam', 
          name: 'UserProfileService', category: LogCategory.system);
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
    if (_batchSubscription != null) {
      Log.debug('📦 Added ${pubkeysToFetch.length} profiles to pending batch (total pending: ${_pendingBatchPubkeys.length})', name: 'UserProfileService', category: LogCategory.system);
      return;
    }
    
    // Debounce: wait a short time to collect more profiles before fetching
    _batchDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      _executeBatchFetch();
    });
  }
  
  /// Execute the actual batch fetch
  void _executeBatchFetch() {
    if (_pendingBatchPubkeys.isEmpty) return;
    
    // Move pending to current batch
    final batchPubkeys = _pendingBatchPubkeys.toList();
    _pendingBatchPubkeys.clear();
    
    Log.debug('🔄 Executing batch fetch for ${batchPubkeys.length} profiles...', name: 'UserProfileService', category: LogCategory.system);
    Log.debug('📋 Sample pubkeys: ${batchPubkeys.take(3).map((p) => p.substring(0, 8)).join(", ")}...', name: 'UserProfileService', category: LogCategory.system);
    
    try {
      // Create filter for kind 0 events from these users
      final filter = Filter(
        kinds: [0],
        authors: batchPubkeys,
        limit: math.min(batchPubkeys.length, 500), // Use vine.hol.is recommended limit
        h: ['vine'], // vine.hol.is optimized for vine-tagged content - gets more results!
      );
      
      // Track which profiles we're fetching in this batch
      final thisBatchPubkeys = Set<String>.from(batchPubkeys);
      
      // Subscribe to profile events
      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
      _batchSubscription = eventStream.listen(
        (event) => _handleProfileEvent(event),
        onError: (error) => Log.error('Batch profile fetch error: $error', name: 'UserProfileService', category: LogCategory.system),
        onDone: () => _completeBatchFetch(thisBatchPubkeys),
      );
      
      // Set timeout for batch fetch - reduced timeout for faster UI
      _batchTimeout = Timer(const Duration(seconds: 5), () {
        _completeBatchFetch(thisBatchPubkeys);
      });
    } catch (e) {
      Log.error('Failed to batch fetch profiles: $e', name: 'UserProfileService', category: LogCategory.system);
      _completeBatchFetch(batchPubkeys.toSet());
    }
  }
  
  /// Complete the batch fetch and clean up
  void _completeBatchFetch(Set<String> batchPubkeys) {
    _batchSubscription?.cancel();
    _batchSubscription = null;
    
    _batchTimeout?.cancel();
    _batchTimeout = null;
    
    // Check which profiles were not found and mark them as missing
    final unfetchedPubkeys = batchPubkeys.where((pubkey) => !_profileCache.containsKey(pubkey)).toSet();
    final fetchedCount = batchPubkeys.length - unfetchedPubkeys.length;
    
    if (unfetchedPubkeys.isNotEmpty) {
      Log.debug('⏰ Batch profile fetch completed - fetched $fetchedCount/${batchPubkeys.length} profiles, ${unfetchedPubkeys.length} not found', 
          name: 'UserProfileService', category: LogCategory.system);
      
      // Mark unfetched profiles as missing to avoid future relay spam
      for (final pubkey in unfetchedPubkeys) {
        markProfileAsMissing(pubkey);
      }
    } else {
      Log.info('✅ Batch profile fetch completed - fetched all ${batchPubkeys.length} profiles', name: 'UserProfileService', category: LogCategory.system);
    }
    
    // Clean up pending requests for this batch
    _pendingRequests.removeAll(batchPubkeys);
    
    // If we have more pending profiles, start a new batch
    if (_pendingBatchPubkeys.isNotEmpty) {
      Log.debug('📦 Starting next batch for ${_pendingBatchPubkeys.length} pending profiles...', name: 'UserProfileService', category: LogCategory.system);
      Timer(const Duration(milliseconds: 100), () {
        _executeBatchFetch();
      });
    }
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
    // Immediate fallback to shortened pubkey (don't wait for profile fetch)
    return pubkey.length > 16 ? '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 8)}' : pubkey;
  }
  
  /// Get avatar URL for a user
  String? getAvatarUrl(String pubkey) {
    return _profileCache[pubkey]?.picture;
  }
  
  /// Get user bio/description
  String? getUserBio(String pubkey) {
    return _profileCache[pubkey]?.about;
  }
  
  /// Clear profile cache
  void clearCache() {
    _profileCache.clear();
    notifyListeners();
    Log.debug('🧹 Profile cache cleared', name: 'UserProfileService', category: LogCategory.system);
  }
  
  /// Remove specific profile from cache
  void removeProfile(String pubkey) {
    if (_profileCache.remove(pubkey) != null) {
      notifyListeners();
      Log.debug('�️ Removed profile from cache: ${pubkey.substring(0, 8)}...', name: 'UserProfileService', category: LogCategory.system);
    }
  }
  
  /// Background refresh for stale profiles
  Future<void> _backgroundRefreshProfile(String pubkey) async {
    // Don't refresh if already pending
    if (_pendingRequests.contains(pubkey) || 
        _profileSubscriptions.containsKey(pubkey) || 
        _activeSubscriptionIds.containsKey(pubkey)) {
      return;
    }
    
    try {
      Log.debug('Background refresh for stale profile ${pubkey.substring(0, 8)}...', name: 'UserProfileService', category: LogCategory.system);
      await fetchProfile(pubkey, forceRefresh: true);
    } catch (e) {
      Log.error('Background refresh failed for ${pubkey.substring(0, 8)}: $e', name: 'UserProfileService', category: LogCategory.system);
    }
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedProfiles': _profileCache.length,
      'pendingRequests': _pendingRequests.length,
      'activeSubscriptions': _profileSubscriptions.length,
      'isInitialized': _isInitialized,
    };
  }
  
  @override
  void dispose() {
    // Cancel batch operations
    _batchDebounceTimer?.cancel();
    _batchTimeout?.cancel();
    _batchSubscription?.cancel();
    
    // Cancel all active subscriptions
    for (final subscription in _profileSubscriptions.values) {
      subscription.cancel();
    }
    _profileSubscriptions.clear();
    _pendingRequests.clear();
    _profileCache.clear();
    _pendingBatchPubkeys.clear();
    _knownMissingProfiles.clear();
    _missingProfileRetryAfter.clear();
    super.dispose();
    Log.debug('🗑️ UserProfileService disposed', name: 'UserProfileService', category: LogCategory.system);
  }
}

/// Exception thrown by user profile service operations
class UserProfileServiceException implements Exception {
  final String message;
  
  const UserProfileServiceException(this.message);
  
  @override
  String toString() => 'UserProfileServiceException: $message';
}