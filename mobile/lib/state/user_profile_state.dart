// ABOUTME: User profile state model for managing profile cache and loading states
// ABOUTME: Used by Riverpod UserProfileProvider to manage reactive profile state

import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/user_profile.dart';

part 'user_profile_state.freezed.dart';
part 'user_profile_state.g.dart';

@freezed
class UserProfileState with _$UserProfileState {
  const factory UserProfileState({
    // Profile cache - pubkey -> profile
    @Default({}) Map<String, UserProfile> profileCache,
    
    // Pending profile requests
    @Default({}) Set<String> pendingRequests,
    
    // Missing profiles to avoid spam
    @Default({}) Set<String> knownMissingProfiles,
    @Default({}) Map<String, DateTime> missingProfileRetryAfter,
    
    // Batch fetching state
    @Default({}) Set<String> pendingBatchPubkeys,
    
    // Loading and error state
    @Default(false) bool isLoading,
    @Default(false) bool isInitialized,
    String? error,
    
    // Stats
    @Default(0) int totalProfilesCached,
    @Default(0) int totalProfilesRequested,
  }) = _UserProfileState;
  
  factory UserProfileState.fromJson(Map<String, dynamic> json) =>
      _$UserProfileStateFromJson(json);
  
  const UserProfileState._();
  
  /// Create initial state
  static const UserProfileState initial = UserProfileState();
  
  /// Check if a profile is cached
  bool hasProfile(String pubkey) => profileCache.containsKey(pubkey);
  
  /// Get cached profile
  UserProfile? getCachedProfile(String pubkey) => profileCache[pubkey];
  
  /// Check if profile request is pending
  bool isRequestPending(String pubkey) => pendingRequests.contains(pubkey);
  
  /// Check if we should skip fetching (known missing)
  bool shouldSkipFetch(String pubkey) {
    if (!knownMissingProfiles.contains(pubkey)) return false;
    
    final retryAfter = missingProfileRetryAfter[pubkey];
    if (retryAfter == null) return false;
    
    return DateTime.now().isBefore(retryAfter);
  }
}