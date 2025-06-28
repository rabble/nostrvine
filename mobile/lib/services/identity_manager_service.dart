// ABOUTME: Service for managing multiple Nostr identities with secure storage
// ABOUTME: Allows users to save, switch between, and manage multiple Nostr accounts

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'key_storage_service.dart';
import '../utils/nostr_encoding.dart';

/// Represents a saved Nostr identity
class SavedIdentity {
  final String npub;
  final String displayName;
  final DateTime savedAt;
  final DateTime? lastUsedAt;
  final bool isActive;

  SavedIdentity({
    required this.npub,
    required this.displayName,
    required this.savedAt,
    this.lastUsedAt,
    this.isActive = false,
  });

  Map<String, dynamic> toJson() => {
    'npub': npub,
    'displayName': displayName,
    'savedAt': savedAt.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
    'isActive': isActive,
  };

  factory SavedIdentity.fromJson(Map<String, dynamic> json) => SavedIdentity(
    npub: json['npub'] as String,
    displayName: json['displayName'] as String,
    savedAt: DateTime.parse(json['savedAt'] as String),
    lastUsedAt: json['lastUsedAt'] != null 
        ? DateTime.parse(json['lastUsedAt'] as String) 
        : null,
    isActive: json['isActive'] as bool? ?? false,
  );
}

/// Service for managing multiple Nostr identities
class IdentityManagerService extends ChangeNotifier {
  static const String _identitiesKey = 'saved_nostr_identities';
  static const String _activeIdentityKey = 'active_nostr_identity';
  
  final KeyStorageService _keyStorage;
  List<SavedIdentity> _savedIdentities = [];
  String? _activeIdentityNpub;

  IdentityManagerService({KeyStorageService? keyStorage})
      : _keyStorage = keyStorage ?? KeyStorageService();

  List<SavedIdentity> get savedIdentities => List.unmodifiable(_savedIdentities);
  String? get activeIdentityNpub => _activeIdentityNpub;
  
  /// Initialize the service and load saved identities
  Future<void> initialize() async {
    await _loadSavedIdentities();
  }

  /// Load saved identities from storage
  Future<void> _loadSavedIdentities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load the list of saved identities
      final identitiesJson = prefs.getString(_identitiesKey);
      if (identitiesJson != null) {
        final List<dynamic> decoded = jsonDecode(identitiesJson);
        _savedIdentities = decoded
            .map((json) => SavedIdentity.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      // Load the active identity
      _activeIdentityNpub = prefs.getString(_activeIdentityKey);
      
      notifyListeners();
      debugPrint('📱 Loaded ${_savedIdentities.length} saved identities');
    } catch (e) {
      debugPrint('❌ Error loading saved identities: $e');
    }
  }

  /// Save the current identity before switching
  Future<void> saveCurrentIdentity() async {
    try {
      final currentKeyPair = await _keyStorage.getKeyPair();
      if (currentKeyPair == null) {
        debugPrint('⚠️ No current identity to save');
        return;
      }

      // Check if this identity is already saved
      final existingIndex = _savedIdentities.indexWhere(
        (identity) => identity.npub == currentKeyPair.npub,
      );

      final displayName = NostrEncoding.maskKey(currentKeyPair.npub);
      
      if (existingIndex >= 0) {
        // Update existing identity
        _savedIdentities[existingIndex] = SavedIdentity(
          npub: currentKeyPair.npub,
          displayName: displayName,
          savedAt: _savedIdentities[existingIndex].savedAt,
          lastUsedAt: DateTime.now(),
          isActive: true,
        );
        debugPrint('📝 Updated existing identity: $displayName');
      } else {
        // Add new identity
        _savedIdentities.add(SavedIdentity(
          npub: currentKeyPair.npub,
          displayName: displayName,
          savedAt: DateTime.now(),
          lastUsedAt: DateTime.now(),
          isActive: true,
        ));
        debugPrint('💾 Saved new identity: $displayName');
      }

      // Mark all other identities as inactive
      for (int i = 0; i < _savedIdentities.length; i++) {
        if (_savedIdentities[i].npub != currentKeyPair.npub) {
          _savedIdentities[i] = SavedIdentity(
            npub: _savedIdentities[i].npub,
            displayName: _savedIdentities[i].displayName,
            savedAt: _savedIdentities[i].savedAt,
            lastUsedAt: _savedIdentities[i].lastUsedAt,
            isActive: false,
          );
        }
      }

      _activeIdentityNpub = currentKeyPair.npub;
      await _persistIdentities();
    } catch (e) {
      debugPrint('❌ Error saving current identity: $e');
    }
  }

  /// Switch to a saved identity
  Future<bool> switchToIdentity(String npub) async {
    try {
      final identity = _savedIdentities.firstWhere(
        (id) => id.npub == npub,
        orElse: () => throw Exception('Identity not found'),
      );

      // First, save the current identity if it exists
      await saveCurrentIdentity();

      // Find the private key for this npub
      // Note: This requires that we've previously saved the nsec securely
      // For now, this is a limitation - we can only switch to identities
      // that were imported during this app's lifetime
      
      debugPrint('🔄 Switching to identity: ${identity.displayName}');
      
      // Update the active identity
      _activeIdentityNpub = npub;
      
      // Update saved identities to mark the new one as active
      for (int i = 0; i < _savedIdentities.length; i++) {
        _savedIdentities[i] = SavedIdentity(
          npub: _savedIdentities[i].npub,
          displayName: _savedIdentities[i].displayName,
          savedAt: _savedIdentities[i].savedAt,
          lastUsedAt: _savedIdentities[i].npub == npub 
              ? DateTime.now() 
              : _savedIdentities[i].lastUsedAt,
          isActive: _savedIdentities[i].npub == npub,
        );
      }
      
      await _persistIdentities();
      return true;
    } catch (e) {
      debugPrint('❌ Error switching identity: $e');
      return false;
    }
  }

  /// Remove a saved identity
  Future<void> removeIdentity(String npub) async {
    try {
      _savedIdentities.removeWhere((identity) => identity.npub == npub);
      
      if (_activeIdentityNpub == npub) {
        _activeIdentityNpub = null;
      }
      
      await _persistIdentities();
      debugPrint('🗑️ Removed identity with npub: ${NostrEncoding.maskKey(npub)}');
    } catch (e) {
      debugPrint('❌ Error removing identity: $e');
    }
  }

  /// Persist identities to storage
  Future<void> _persistIdentities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final identitiesJson = jsonEncode(
        _savedIdentities.map((id) => id.toJson()).toList(),
      );
      
      await prefs.setString(_identitiesKey, identitiesJson);
      
      if (_activeIdentityNpub != null) {
        await prefs.setString(_activeIdentityKey, _activeIdentityNpub!);
      } else {
        await prefs.remove(_activeIdentityKey);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error persisting identities: $e');
    }
  }

  /// Clear all saved identities (use with caution!)
  Future<void> clearAllIdentities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_identitiesKey);
      await prefs.remove(_activeIdentityKey);
      
      _savedIdentities.clear();
      _activeIdentityNpub = null;
      
      notifyListeners();
      debugPrint('🗑️ Cleared all saved identities');
    } catch (e) {
      debugPrint('❌ Error clearing identities: $e');
    }
  }
}