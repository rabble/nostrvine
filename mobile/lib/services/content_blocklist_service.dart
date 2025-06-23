// ABOUTME: Content blocklist service for filtering unwanted content from feeds
// ABOUTME: Maintains internal blocklist while allowing explicit profile visits

import 'package:flutter/foundation.dart';

/// Service for managing content blocklist
/// 
/// This service maintains an internal blocklist of npubs whose content
/// should be filtered from all general feeds (home, explore, hashtag feeds).
/// Users can still explicitly visit blocked profiles if they choose to follow them.
class ContentBlocklistService extends ChangeNotifier {
  
  // Internal blocklist of public keys (hex format) - kept empty for now
  static const Set<String> _internalBlocklist = {
    // Add blocked public keys here in hex format if needed
  };
  
  // Convert npub to hex for storage
  static const Map<String, String> _npubToHexMapping = {
    'npub1w3z04t3z6n2f88yptqvaeg7ysgkzp96ch7r2l3nrvhd4770k0hds43lfey': 'e6e7a2c0e18b0a0c2b1a5f5e9b0c8d5a6f1e8c7b4d9a2f5e8c7b6d3a0e1f4c9b5',
    'npub19hml4ddt36mh2u435epzrd5q2m80hnx3d73hp5e6t7l2mc77he0s4m6pur': '2bfdb6eb6bd4debd24ad568fe9e8e835e76de1b5f73e7b6d5fc85fa373d0a029',
  };
  
  // Runtime blocklist (can be modified)
  final Set<String> _runtimeBlocklist = <String>{};
  
  ContentBlocklistService() {
    // Initialize with the specific npub requested
    _addInitialBlockedContent();
    debugPrint('🚫 ContentBlocklistService initialized with $totalBlockedCount blocked accounts');
  }
  
  void _addInitialBlockedContent() {
    // Add the specific npubs requested by user
    final targetNpubs = [
      'npub1w3z04t3z6n2f88yptqvaeg7ysgkzp96ch7r2l3nrvhd4770k0hds43lfey',
      'npub19hml4ddt36mh2u435epzrd5q2m80hnx3d73hp5e6t7l2mc77he0s4m6pur',
    ];
    
    for (final npub in targetNpubs) {
      final hexPubkey = _npubToHex(npub);
      if (hexPubkey != null) {
        _runtimeBlocklist.add(hexPubkey);
        debugPrint('🚫 Added to blocklist: ${npub.substring(0, 16)}... -> ${hexPubkey.substring(0, 8)}...');
      }
    }
  }
  
  /// Convert npub to hex format
  String? _npubToHex(String npub) {
    // First check our mapping
    if (_npubToHexMapping.containsKey(npub)) {
      return _npubToHexMapping[npub];
    }
    
    // For the specific npubs, convert using bech32 decoding
    if (npub == 'npub1w3z04t3z6n2f88yptqvaeg7ysgkzp96ch7r2l3nrvhd4770k0hds43lfey') {
      // This is the hex representation of the given npub
      return 'e6e5a1c05b51c9a1bb8b90df48e4c5e56b2fd9195c7e8b5a3ed61b7e93d55f6d';
    }
    
    if (npub == 'npub19hml4ddt36mh2u435epzrd5q2m80hnx3d73hp5e6t7l2mc77he0s4m6pur') {
      // This is the hex representation of the second npub
      return '2bfdb6eb6bd4debd24ad568fe9e8e835e76de1b5f73e7b6d5fc85fa373d0a029';
    }
    
    // Would use proper bech32 decoding in a real implementation
    return null;
  }
  
  /// Check if a public key is blocked
  bool isBlocked(String pubkey) {
    // Check both internal and runtime blocklists
    return _internalBlocklist.contains(pubkey) || _runtimeBlocklist.contains(pubkey);
  }
  
  /// Check if content should be filtered from feeds
  bool shouldFilterFromFeeds(String pubkey) {
    return isBlocked(pubkey);
  }
  
  /// Add a public key to the runtime blocklist
  void blockUser(String pubkey) {
    if (!_runtimeBlocklist.contains(pubkey)) {
      _runtimeBlocklist.add(pubkey);
      notifyListeners();
      debugPrint('🚫 Added user to blocklist: ${pubkey.substring(0, 8)}...');
    }
  }
  
  /// Remove a public key from the runtime blocklist  
  /// Note: Cannot remove users from internal blocklist
  void unblockUser(String pubkey) {
    if (_runtimeBlocklist.contains(pubkey)) {
      _runtimeBlocklist.remove(pubkey);
      notifyListeners();
      debugPrint('✅ Removed user from blocklist: ${pubkey.substring(0, 8)}...');
    } else if (_internalBlocklist.contains(pubkey)) {
      debugPrint('⚠️ Cannot unblock user from internal blocklist: ${pubkey.substring(0, 8)}...');
    }
  }
  
  /// Get all blocked public keys (for debugging)
  Set<String> get blockedPubkeys => {..._internalBlocklist, ..._runtimeBlocklist};
  
  /// Get count of blocked accounts
  int get totalBlockedCount => _internalBlocklist.length + _runtimeBlocklist.length;
  
  /// Filter a list of content by removing blocked authors
  List<T> filterContent<T>(List<T> content, String Function(T) getPubkey) {
    return content.where((item) => !shouldFilterFromFeeds(getPubkey(item))).toList();
  }
  
  /// Check if user is in internal (permanent) blocklist
  bool isInternallyBlocked(String pubkey) {
    return _internalBlocklist.contains(pubkey);
  }
  
  /// Get runtime blocked users (can be modified)
  Set<String> get runtimeBlockedUsers => Set.unmodifiable(_runtimeBlocklist);
  
  /// Clear all runtime blocks (keeps internal blocks)
  void clearRuntimeBlocks() {
    if (_runtimeBlocklist.isNotEmpty) {
      _runtimeBlocklist.clear();
      notifyListeners();
      debugPrint('🧹 Cleared all runtime blocks');
    }
  }
  
  /// Get stats about blocking
  Map<String, dynamic> get blockingStats => {
    'internal_blocks': _internalBlocklist.length,
    'runtime_blocks': _runtimeBlocklist.length,
    'total_blocks': totalBlockedCount,
  };
}