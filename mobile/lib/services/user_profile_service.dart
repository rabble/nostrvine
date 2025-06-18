// ABOUTME: Service for fetching and caching NIP-01 kind 0 user profile events
// ABOUTME: Manages user metadata including display names, avatars, and descriptions

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr/nostr.dart';
import '../models/user_profile.dart';
import 'nostr_service_interface.dart';
import 'connection_status_service.dart';

/// Service for managing user profiles from Nostr kind 0 events
class UserProfileService extends ChangeNotifier {
  final INostrService _nostrService;
  final ConnectionStatusService _connectionService = ConnectionStatusService();
  
  final Map<String, UserProfile> _profileCache = {};
  final Map<String, StreamSubscription> _profileSubscriptions = {};
  final Set<String> _pendingRequests = {};
  bool _isInitialized = false;
  
  UserProfileService(this._nostrService);
  
  /// Get cached profile for a user
  UserProfile? getCachedProfile(String pubkey) {
    return _profileCache[pubkey];
  }
  
  /// Check if profile is cached
  bool hasProfile(String pubkey) {
    return _profileCache.containsKey(pubkey);
  }
  
  /// Get all cached profiles
  Map<String, UserProfile> get allProfiles => Map.unmodifiable(_profileCache);
  
  /// Initialize the profile service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('👤 Initializing user profile service...');
      
      if (!_nostrService.isInitialized) {
        debugPrint('⚠️ Nostr service not initialized, profile service will wait');
        return;
      }
      
      _isInitialized = true;
      debugPrint('✅ User profile service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize user profile service: $e');
      rethrow;
    }
  }
  
  /// Fetch profile for a specific user
  Future<UserProfile?> fetchProfile(String pubkey, {bool forceRefresh = false}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Return cached profile if available and not forcing refresh
    if (!forceRefresh && _profileCache.containsKey(pubkey)) {
      debugPrint('👤 Returning cached profile for ${pubkey.substring(0, 8)}...');
      return _profileCache[pubkey];
    }
    
    // Check if already requesting this profile - STOP HERE, don't create duplicate subscriptions
    if (_pendingRequests.contains(pubkey)) {
      debugPrint('⏳ Profile request already pending for ${pubkey.substring(0, 8)}... (skipping duplicate)');
      return null;
    }
    
    // Check if we already have an active subscription for this pubkey
    if (_profileSubscriptions.containsKey(pubkey)) {
      debugPrint('🔄 Active subscription already exists for ${pubkey.substring(0, 8)}... (skipping duplicate)');
      return null;
    }
    
    // Check connection
    if (!_connectionService.isOnline) {
      debugPrint('📡 Offline - cannot fetch profile for ${pubkey.substring(0, 8)}...');
      return null;
    }
    
    try {
      _pendingRequests.add(pubkey);
      debugPrint('👤 Fetching profile for user: ${pubkey.substring(0, 8)}...');
      
      // Create filter for kind 0 events from this user
      final filter = Filter(
        kinds: [0], // NIP-01 user metadata
        authors: [pubkey],
        limit: 1, // Only need the most recent profile
      );
      
      // Subscribe to profile events
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
          debugPrint('⏰ Profile fetch timeout for ${pubkey.substring(0, 8)}...');
          _cleanupProfileRequest(pubkey);
        }
      });
      
      return null; // Profile will be available in cache once loaded
    } catch (e) {
      debugPrint('❌ Failed to fetch profile for ${pubkey.substring(0, 8)}: $e');
      _pendingRequests.remove(pubkey);
      return null;
    }
  }
  
  /// Handle incoming profile event
  void _handleProfileEvent(Event event) {
    try {
      if (event.kind != 0) return;
      
      debugPrint('👤 Received profile event for ${event.pubkey.substring(0, 8)}...');
      
      // Parse profile data from event content
      final profile = UserProfile.fromNostrEvent(event);
      
      // Cache the profile
      _profileCache[event.pubkey] = profile;
      _cleanupProfileRequest(event.pubkey);
      
      debugPrint('✅ Cached profile for ${event.pubkey.substring(0, 8)}: ${profile.displayName}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error parsing profile event: $e');
    }
  }
  
  /// Handle profile fetch error
  void _handleProfileError(String pubkey, dynamic error) {
    debugPrint('❌ Profile fetch error for ${pubkey.substring(0, 8)}: $error');
    _cleanupProfileRequest(pubkey);
  }
  
  /// Handle profile fetch completion
  void _handleProfileComplete(String pubkey) {
    debugPrint('🏁 Profile fetch completed for ${pubkey.substring(0, 8)}...');
    _cleanupProfileRequest(pubkey);
  }
  
  /// Cleanup profile request
  void _cleanupProfileRequest(String pubkey) {
    _pendingRequests.remove(pubkey);
    final subscription = _profileSubscriptions.remove(pubkey);
    subscription?.cancel();
  }
  
  /// Batch fetch profiles for multiple users
  Future<void> fetchMultipleProfiles(List<String> pubkeys, {bool forceRefresh = false}) async {
    if (pubkeys.isEmpty) return;
    
    debugPrint('👥 Batch fetching ${pubkeys.length} profiles...');
    
    // Filter out already cached profiles unless forcing refresh
    final pubkeysToFetch = forceRefresh 
        ? pubkeys 
        : pubkeys.where((pubkey) => !_profileCache.containsKey(pubkey)).toList();
    
    if (pubkeysToFetch.isEmpty) {
      debugPrint('👥 All profiles already cached');
      return;
    }
    
    try {
      // Create filter for kind 0 events from these users
      final filter = Filter(
        kinds: [0],
        authors: pubkeysToFetch,
        limit: pubkeysToFetch.length,
      );
      
      debugPrint('👥 Requesting profiles for ${pubkeysToFetch.length} users...');
      
      // Subscribe to profile events
      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
      final subscription = eventStream.listen(
        (event) => _handleProfileEvent(event),
        onError: (error) => debugPrint('❌ Batch profile fetch error: $error'),
        onDone: () => debugPrint('🏁 Batch profile fetch completed'),
      );
      
      // Mark all as pending
      for (final pubkey in pubkeysToFetch) {
        _pendingRequests.add(pubkey);
      }
      
      // Set timeout for batch fetch
      Timer(const Duration(seconds: 15), () {
        subscription.cancel();
        for (final pubkey in pubkeysToFetch) {
          _pendingRequests.remove(pubkey);
        }
        debugPrint('⏰ Batch profile fetch timeout');
      });
    } catch (e) {
      debugPrint('❌ Failed to batch fetch profiles: $e');
      for (final pubkey in pubkeysToFetch) {
        _pendingRequests.remove(pubkey);
      }
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
    // Fallback to shortened pubkey
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
    debugPrint('🧹 Profile cache cleared');
  }
  
  /// Remove specific profile from cache
  void removeProfile(String pubkey) {
    if (_profileCache.remove(pubkey) != null) {
      notifyListeners();
      debugPrint('🗑️ Removed profile from cache: ${pubkey.substring(0, 8)}...');
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
    // Cancel all active subscriptions
    for (final subscription in _profileSubscriptions.values) {
      subscription.cancel();
    }
    _profileSubscriptions.clear();
    _pendingRequests.clear();
    _profileCache.clear();
    super.dispose();
    debugPrint('🗑️ UserProfileService disposed');
  }
}

/// Exception thrown by user profile service operations
class UserProfileServiceException implements Exception {
  final String message;
  
  const UserProfileServiceException(this.message);
  
  @override
  String toString() => 'UserProfileServiceException: $message';
}