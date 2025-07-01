// ABOUTME: Riverpod providers for user profile service with reactive state management
// ABOUTME: Replaces Provider-based UserProfileService with StateNotifier pattern

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

import '../state/user_profile_state.dart';
import '../models/user_profile.dart';
import '../services/nostr_service_interface.dart';
import '../services/subscription_manager.dart';
import '../utils/unified_logger.dart';

part 'user_profile_providers.g.dart';

// Provider dependencies
@riverpod
INostrService nostrService(Ref ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
}

@riverpod
SubscriptionManager subscriptionManager(Ref ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
}

// User profile service provider with state management
@riverpod
class UserProfiles extends _$UserProfiles {
  // Active subscription tracking
  final Map<String, String> _activeSubscriptionIds = {}; // pubkey -> subscription ID
  String? _batchSubscriptionId;
  Timer? _batchTimer;
  Timer? _batchDebounceTimer;
  
  @override
  UserProfileState build() {
    ref.onDispose(() {
      _cleanupAllSubscriptions();
      _batchTimer?.cancel();
      _batchDebounceTimer?.cancel();
    });
    
    return UserProfileState.initial;
  }
  
  /// Initialize the profile service
  Future<void> initialize() async {
    if (state.isInitialized) return;
    
    Log.verbose('Initializing user profile provider...', name: 'UserProfileProvider', category: LogCategory.system);
    
    final nostrService = ref.read(nostrServiceProvider);
    
    if (!nostrService.isInitialized) {
      Log.warning('Nostr service not initialized, profile provider will wait', name: 'UserProfileProvider', category: LogCategory.system);
      return;
    }
    
    state = state.copyWith(isInitialized: true);
    Log.info('User profile provider initialized', name: 'UserProfileProvider', category: LogCategory.system);
  }
  
  /// Get cached profile for a user
  UserProfile? getCachedProfile(String pubkey) {
    return state.getCachedProfile(pubkey);
  }
  
  /// Update a cached profile
  void updateCachedProfile(UserProfile profile) {
    state = state.copyWith(
      profileCache: {...state.profileCache, profile.pubkey: profile},
      totalProfilesCached: state.profileCache.length + 1,
    );
    
    Log.debug('Updated cached profile for ${profile.pubkey.substring(0, 8)}: ${profile.bestDisplayName}', 
        name: 'UserProfileProvider', category: LogCategory.system);
  }
  
  /// Fetch profile for a specific user
  Future<UserProfile?> fetchProfile(String pubkey, {bool forceRefresh = false}) async {
    if (!state.isInitialized) {
      await initialize();
    }
    
    // If forcing refresh, clear cache first
    if (forceRefresh) {
      Log.debug('🔄 Force refresh requested for ${pubkey.substring(0, 8)}... - clearing cache', 
          name: 'UserProfileProvider', category: LogCategory.system);
      
      final newCache = {...state.profileCache}..remove(pubkey);
      state = state.copyWith(profileCache: newCache);
      
      // Cancel any existing subscriptions
      await _cleanupProfileRequest(pubkey);
    }
    
    // Return cached profile if available
    if (!forceRefresh && state.hasProfile(pubkey)) {
      Log.verbose('Returning cached profile for ${pubkey.substring(0, 8)}...', 
          name: 'UserProfileProvider', category: LogCategory.system);
      return state.getCachedProfile(pubkey);
    }
    
    // Check if already requesting
    if (state.isRequestPending(pubkey)) {
      Log.warning('⏳ Profile request already pending for ${pubkey.substring(0, 8)}...', 
          name: 'UserProfileProvider', category: LogCategory.system);
      return null;
    }
    
    // Check if we should skip (known missing)
    if (state.shouldSkipFetch(pubkey)) {
      Log.debug('Skipping fetch for known missing profile: ${pubkey.substring(0, 8)}...', 
          name: 'UserProfileProvider', category: LogCategory.system);
      return null;
    }
    
    try {
      // Mark as pending
      state = state.copyWith(
        pendingRequests: {...state.pendingRequests, pubkey},
        isLoading: true,
        totalProfilesRequested: state.totalProfilesRequested + 1,
      );
      
      Log.verbose('🔍 Starting profile fetch for user: ${pubkey.substring(0, 8)}...', 
          name: 'UserProfileProvider', category: LogCategory.system);
      
      // Create filter for Kind 0 profile event
      final filter = Filter(
        kinds: const [0],
        authors: [pubkey],
        limit: 1,
        h: ['vine'], // Required for vine.hol.is relay
      );
      
      // Subscribe and wait for profile
      final nostrService = ref.read(nostrServiceProvider);
      final completer = Completer<UserProfile?>();
      
      final stream = nostrService.subscribeToEvents(filters: [filter]);
      StreamSubscription<Event>? subscription;
      
      // Timeout after 5 seconds
      final timer = Timer(const Duration(seconds: 5), () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });
      
      subscription = stream.listen(
        (event) {
          timer.cancel();
          subscription?.cancel();
          
          try {
            final profile = UserProfile.fromNostrEvent(event);
            
            // Update cache
            state = state.copyWith(
              profileCache: {...state.profileCache, pubkey: profile},
              totalProfilesCached: state.profileCache.length + 1,
            );
            
            Log.info('✅ Fetched profile for ${pubkey.substring(0, 8)}: ${profile.bestDisplayName}', 
                name: 'UserProfileProvider', category: LogCategory.system);
            
            if (!completer.isCompleted) {
              completer.complete(profile);
            }
          } catch (e) {
            Log.error('Error parsing profile event: $e', name: 'UserProfileProvider', category: LogCategory.system);
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          }
        },
        onError: (error) {
          timer.cancel();
          subscription?.cancel();
          Log.error('Error fetching profile: $error', name: 'UserProfileProvider', category: LogCategory.system);
          
          state = state.copyWith(error: error.toString());
          
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
        onDone: () {
          timer.cancel();
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      );
      
      final profile = await completer.future;
      
      // If no profile found, mark as missing
      if (profile == null) {
        markProfileAsMissing(pubkey);
      }
      
      return profile;
    } finally {
      // Remove from pending
      final newPending = {...state.pendingRequests}..remove(pubkey);
      state = state.copyWith(
        pendingRequests: newPending,
        isLoading: newPending.isEmpty && state.pendingBatchPubkeys.isEmpty,
      );
    }
  }
  
  /// Fetch multiple profiles with batching
  Future<void> fetchMultipleProfiles(List<String> pubkeys, {bool forceRefresh = false}) async {
    if (!state.isInitialized) {
      await initialize();
    }
    
    // Filter out already cached profiles (unless forcing refresh)
    final pubkeysToFetch = forceRefresh 
        ? pubkeys 
        : pubkeys.where((p) => !state.hasProfile(p) && !state.shouldSkipFetch(p)).toList();
    
    if (pubkeysToFetch.isEmpty) {
      Log.debug('All requested profiles already cached', name: 'UserProfileProvider', category: LogCategory.system);
      return;
    }
    
    Log.info('📋 Batch fetching ${pubkeysToFetch.length} profiles', name: 'UserProfileProvider', category: LogCategory.system);
    
    // Add to pending batch
    state = state.copyWith(
      pendingBatchPubkeys: {...state.pendingBatchPubkeys, ...pubkeysToFetch},
      isLoading: true,
    );
    
    // Debounce batch execution
    _batchDebounceTimer?.cancel();
    _batchDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      executeBatchFetch();
    });
  }
  
  /// Mark a profile as missing to avoid spam
  void markProfileAsMissing(String pubkey) {
    final retryAfter = DateTime.now().add(const Duration(hours: 1));
    
    state = state.copyWith(
      knownMissingProfiles: {...state.knownMissingProfiles, pubkey},
      missingProfileRetryAfter: {...state.missingProfileRetryAfter, pubkey: retryAfter},
    );
    
    Log.debug('Marked profile as missing: ${pubkey.substring(0, 8)}... (retry after 1 hour)', 
        name: 'UserProfileProvider', category: LogCategory.system);
  }
  
  // Private helper methods
  
  // Made package-private for testing
  @visibleForTesting
  Future<void> executeBatchFetch() async {
    if (state.pendingBatchPubkeys.isEmpty) return;
    
    final pubkeysToFetch = state.pendingBatchPubkeys.toList();
    Log.debug('_executeBatchFetch called with ${pubkeysToFetch.length} pubkeys', 
        name: 'UserProfileProvider', category: LogCategory.system);
    
    try {
      // Create filter for multiple authors
      final filter = Filter(
        kinds: const [0],
        authors: pubkeysToFetch,
        limit: pubkeysToFetch.length,
        h: ['vine'], // Required for vine.hol.is relay
      );
      
      final nostrService = ref.read(nostrServiceProvider);
      Log.debug('Got nostr service, subscribing to events...', 
          name: 'UserProfileProvider', category: LogCategory.system);
      final stream = nostrService.subscribeToEvents(filters: [filter]);
      StreamSubscription<Event>? subscription;
      
      // Collect profiles as they come in
      final fetchedPubkeys = <String>{};
      
      // Timeout after 5 seconds
      _batchTimer = Timer(const Duration(seconds: 5), () {
        subscription?.cancel();
        _finalizeBatchFetch(pubkeysToFetch, fetchedPubkeys);
      });
      
      subscription = stream.listen(
        (event) {
          try {
            final profile = UserProfile.fromNostrEvent(event);
            fetchedPubkeys.add(profile.pubkey);
            
            // Update cache
            state = state.copyWith(
              profileCache: {...state.profileCache, profile.pubkey: profile},
              totalProfilesCached: state.profileCache.length + 1,
            );
            
            Log.debug('Batch fetched profile: ${profile.bestDisplayName}', 
                name: 'UserProfileProvider', category: LogCategory.system);
          } catch (e) {
            Log.error('Error parsing batch profile event: $e', 
                name: 'UserProfileProvider', category: LogCategory.system);
          }
        },
        onError: (error) {
          Log.error('Batch fetch error: $error', name: 'UserProfileProvider', category: LogCategory.system);
          state = state.copyWith(error: error.toString());
        },
        onDone: () {
          _batchTimer?.cancel();
          subscription?.cancel();
          _finalizeBatchFetch(pubkeysToFetch, fetchedPubkeys);
        },
      );
      
      // Store subscription ID for cleanup
      _batchSubscriptionId = 'batch-${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      Log.error('Error executing batch fetch: $e', name: 'UserProfileProvider', category: LogCategory.system);
      state = state.copyWith(
        pendingBatchPubkeys: {},
        isLoading: state.pendingRequests.isEmpty,
        error: e.toString(),
      );
    }
  }
  
  void _finalizeBatchFetch(List<String> requested, Set<String> fetched) {
    // Mark unfetched profiles as missing
    for (final pubkey in requested) {
      if (!fetched.contains(pubkey)) {
        markProfileAsMissing(pubkey);
      }
    }
    
    // Clear batch state
    state = state.copyWith(
      pendingBatchPubkeys: {},
      isLoading: state.pendingRequests.isNotEmpty,
    );
    
    Log.info('Batch fetch complete: ${fetched.length}/${requested.length} profiles fetched', 
        name: 'UserProfileProvider', category: LogCategory.system);
  }
  
  Future<void> _cleanupProfileRequest(String pubkey) async {
    final subscriptionId = _activeSubscriptionIds[pubkey];
    if (subscriptionId != null) {
      try {
        final subscriptionManager = ref.read(subscriptionManagerProvider);
        subscriptionManager.cancelSubscription(subscriptionId);
        _activeSubscriptionIds.remove(pubkey);
      } catch (e) {
        Log.error('Error canceling subscription: $e', name: 'UserProfileProvider', category: LogCategory.system);
      }
    }
  }
  
  void _cleanupAllSubscriptions() {
    try {
      final subscriptionManager = ref.read(subscriptionManagerProvider);
      
      // Clean up individual subscriptions
      for (final subscriptionId in _activeSubscriptionIds.values) {
        subscriptionManager.cancelSubscription(subscriptionId);
      }
      _activeSubscriptionIds.clear();
      
      // Clean up batch subscription
      if (_batchSubscriptionId != null) {
        subscriptionManager.cancelSubscription(_batchSubscriptionId!);
        _batchSubscriptionId = null;
      }
    } catch (e) {
      // Container might be disposed, ignore cleanup errors
      Log.debug('Cleanup error during disposal: $e', name: 'UserProfileProvider', category: LogCategory.system);
    }
  }
  
  /// Check if we have a cached profile
  bool hasProfile(String pubkey) {
    return state.hasProfile(pubkey);
  }
}