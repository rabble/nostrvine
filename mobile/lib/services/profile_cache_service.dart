// ABOUTME: Persistent cache service for user profiles using Hive storage
// ABOUTME: Provides fast local storage and retrieval of Nostr user profiles with automatic cleanup

import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

/// Service for persistent caching of user profiles
class ProfileCacheService extends ChangeNotifier {
  static const String _boxName = 'user_profiles';
  static const int _maxCacheSize = 1000; // Maximum number of profiles to cache
  static const Duration _cacheExpiry = Duration(days: 7); // Cache profiles for 7 days
  
  Box<UserProfile>? _profileBox;
  bool _isInitialized = false;
  
  /// Check if the cache service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Initialize the profile cache
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Register the UserProfile adapter if not already registered
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(UserProfileAdapter());
      }
      
      // Open the profiles box
      _profileBox = await Hive.openBox<UserProfile>(_boxName);
      _isInitialized = true;
      
      debugPrint('✅ ProfileCacheService initialized with ${_profileBox!.length} cached profiles');
      
      // Clean up old profiles on startup
      await _cleanupExpiredProfiles();
      
    } catch (e) {
      debugPrint('❌ Failed to initialize ProfileCacheService: $e');
      rethrow;
    }
  }
  
  /// Get a cached profile by pubkey
  UserProfile? getCachedProfile(String pubkey) {
    if (!_isInitialized || _profileBox == null) return null;
    
    try {
      final profile = _profileBox!.get(pubkey);
      
      if (profile == null) return null;
      
      // Check if profile is expired
      if (_isProfileExpired(profile)) {
        debugPrint('🗑️ Removing expired profile for ${pubkey.substring(0, 8)}...');
        _profileBox!.delete(pubkey);
        return null;
      }
      
      debugPrint('💾 Retrieved cached profile for ${pubkey.substring(0, 8)}... (${profile.bestDisplayName})');
      return profile;
      
    } catch (e) {
      debugPrint('❌ Error retrieving cached profile for $pubkey: $e');
      return null;
    }
  }
  
  /// Cache a profile
  Future<void> cacheProfile(UserProfile profile) async {
    if (!_isInitialized || _profileBox == null) {
      debugPrint('⚠️ ProfileCacheService not initialized, cannot cache profile');
      return;
    }
    
    try {
      // Check if we need to make space
      if (_profileBox!.length >= _maxCacheSize) {
        await _cleanupOldestProfiles();
      }
      
      await _profileBox!.put(profile.pubkey, profile);
      debugPrint('💾 Cached profile for ${profile.pubkey.substring(0, 8)}... (${profile.bestDisplayName})');
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Error caching profile for ${profile.pubkey}: $e');
    }
  }
  
  /// Update an existing cached profile
  Future<void> updateCachedProfile(UserProfile profile) async {
    if (!_isInitialized || _profileBox == null) return;
    
    try {
      final existing = _profileBox!.get(profile.pubkey);
      
      // Only update if the new profile is newer
      if (existing == null || profile.createdAt.isAfter(existing.createdAt)) {
        await _profileBox!.put(profile.pubkey, profile);
        debugPrint('🔄 Updated cached profile for ${profile.pubkey.substring(0, 8)}... (${profile.bestDisplayName})');
        notifyListeners();
      } else {
        debugPrint('⏩ Skipping update for ${profile.pubkey.substring(0, 8)}... - cached version is newer');
      }
      
    } catch (e) {
      debugPrint('❌ Error updating cached profile for ${profile.pubkey}: $e');
    }
  }
  
  /// Remove a profile from cache
  Future<void> removeCachedProfile(String pubkey) async {
    if (!_isInitialized || _profileBox == null) return;
    
    try {
      await _profileBox!.delete(pubkey);
      debugPrint('🗑️ Removed cached profile for ${pubkey.substring(0, 8)}...');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing cached profile for $pubkey: $e');
    }
  }
  
  /// Get all cached pubkeys
  List<String> getCachedPubkeys() {
    if (!_isInitialized || _profileBox == null) return [];
    return _profileBox!.keys.cast<String>().toList();
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    if (!_isInitialized || _profileBox == null) {
      return {
        'isInitialized': false,
        'totalProfiles': 0,
        'expiredProfiles': 0,
      };
    }
    
    final allProfiles = _profileBox!.values.toList();
    final expiredCount = allProfiles.where(_isProfileExpired).length;
    
    return {
      'isInitialized': true,
      'totalProfiles': allProfiles.length,
      'expiredProfiles': expiredCount,
      'cacheHitRate': 0.0, // TODO: Track hit rate
    };
  }
  
  /// Clear all cached profiles
  Future<void> clearCache() async {
    if (!_isInitialized || _profileBox == null) return;
    
    try {
      await _profileBox!.clear();
      debugPrint('🗑️ Cleared all cached profiles');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing profile cache: $e');
    }
  }
  
  /// Check if a profile is expired
  bool _isProfileExpired(UserProfile profile) {
    final now = DateTime.now();
    return now.difference(profile.createdAt) > _cacheExpiry;
  }
  
  /// Clean up expired profiles
  Future<void> _cleanupExpiredProfiles() async {
    if (!_isInitialized || _profileBox == null) return;
    
    try {
      final expiredKeys = <String>[];
      
      for (final entry in _profileBox!.toMap().entries) {
        if (_isProfileExpired(entry.value)) {
          expiredKeys.add(entry.key);
        }
      }
      
      if (expiredKeys.isNotEmpty) {
        for (final key in expiredKeys) {
          await _profileBox!.delete(key);
        }
        debugPrint('🗑️ Cleaned up ${expiredKeys.length} expired profiles');
      }
      
    } catch (e) {
      debugPrint('❌ Error cleaning up expired profiles: $e');
    }
  }
  
  /// Clean up oldest profiles to make space
  Future<void> _cleanupOldestProfiles() async {
    if (!_isInitialized || _profileBox == null) return;
    
    try {
      final profiles = _profileBox!.toMap().entries.toList();
      
      // Sort by creation date (oldest first)
      profiles.sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));
      
      // Remove oldest 10% of profiles
      final toRemove = (profiles.length * 0.1).ceil();
      
      for (int i = 0; i < toRemove && i < profiles.length; i++) {
        await _profileBox!.delete(profiles[i].key);
      }
      
      debugPrint('🗑️ Removed $toRemove oldest profiles to make space');
      
    } catch (e) {
      debugPrint('❌ Error cleaning up oldest profiles: $e');
    }
  }
  
  @override
  void dispose() {
    _profileBox?.close();
    super.dispose();
  }
}