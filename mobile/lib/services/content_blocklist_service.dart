// ABOUTME: Content blocklist service for filtering unwanted content from feeds
// ABOUTME: Maintains internal blocklist while allowing explicit profile visits

import 'package:flutter/foundation.dart';
import '../utils/nostr_encoding.dart';
import '../utils/unified_logger.dart';

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
  
  
  // Runtime blocklist (can be modified)
  final Set<String> _runtimeBlocklist = <String>{};
  
  ContentBlocklistService() {
    // Initialize with the specific npub requested
    _addInitialBlockedContent();
    Log.info('ContentBlocklistService initialized with $totalBlockedCount blocked accounts', name: 'ContentBlocklistService', category: LogCategory.system);
  }
  
  void _addInitialBlockedContent() {
    // Add the specific npubs requested by user
    final targetNpubs = [
      'npub1w3z04t3z6n2f88yptqvaeg7ysgkzp96ch7r2l3nrvhd4770k0hds43lfey',
      'npub19hml4ddt36mh2u435epzrd5q2m80hnx3d73hp5e6t7l2mc77he0s4m6pur',
      'npub1t9pu3reuvrxeakcjtfngu2g344qelszwj32fakt2wgvsrhv4sdeqe6jz4j',
    ];
    
    for (final npub in targetNpubs) {
      final hexPubkey = _npubToHex(npub);
      if (hexPubkey != null) {
        _runtimeBlocklist.add(hexPubkey);
        Log.debug('Added to blocklist: ${npub.substring(0, 16)}... -> ${hexPubkey.substring(0, 8)}...', name: 'ContentBlocklistService', category: LogCategory.system);
      }
    }
  }
  
  /// Convert npub to hex format
  String? _npubToHex(String npub) {
    try {
      // Use proper bech32 decoding
      return NostrEncoding.decodePublicKey(npub);
    } catch (e) {
      Log.error('Failed to decode npub $npub: $e', name: 'ContentBlocklistService', category: LogCategory.system);
      return null;
    }
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
      Log.debug('Added user to blocklist: ${pubkey.substring(0, 8)}...', name: 'ContentBlocklistService', category: LogCategory.system);
    }
  }
  
  /// Remove a public key from the runtime blocklist  
  /// Note: Cannot remove users from internal blocklist
  void unblockUser(String pubkey) {
    if (_runtimeBlocklist.contains(pubkey)) {
      _runtimeBlocklist.remove(pubkey);
      notifyListeners();
      Log.info('Removed user from blocklist: ${pubkey.substring(0, 8)}...', name: 'ContentBlocklistService', category: LogCategory.system);
    } else if (_internalBlocklist.contains(pubkey)) {
      Log.warning('Cannot unblock user from internal blocklist: ${pubkey.substring(0, 8)}...', name: 'ContentBlocklistService', category: LogCategory.system);
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
      Log.debug('🧹 Cleared all runtime blocks', name: 'ContentBlocklistService', category: LogCategory.system);
    }
  }
  
  /// Get stats about blocking
  Map<String, dynamic> get blockingStats => {
    'internal_blocks': _internalBlocklist.length,
    'runtime_blocks': _runtimeBlocklist.length,
    'total_blocks': totalBlockedCount,
  };
}