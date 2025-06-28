// ABOUTME: DEPRECATED - Legacy key storage service with security vulnerabilities
// ABOUTME: Use SecureKeyStorageService instead for production applications

// SECURITY WARNING: This implementation has critical vulnerabilities:
// 1. Private keys stored as plain strings in memory
// 2. Insecure SharedPreferences fallback for web platform  
// 3. No hardware-backed security utilization
// 4. Memory not securely wiped after operations
//
// This service is maintained only for migration purposes.
// All new code should use SecureKeyStorageService.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import '../utils/nostr_encoding.dart';

/// Exception thrown by key storage operations
class KeyStorageException implements Exception {
  final String message;
  final String? code;
  
  const KeyStorageException(this.message, {this.code});
  
  @override
  String toString() => 'KeyStorageException: $message';
}

/// User key pair containing both public and private keys
class NostrKeyPair {
  final String publicKeyHex;
  final String privateKeyHex;
  final String npub;
  final String nsec;
  
  const NostrKeyPair({
    required this.publicKeyHex,
    required this.privateKeyHex,
    required this.npub,
    required this.nsec,
  });
  
  /// Create key pair from hex private key
  factory NostrKeyPair.fromPrivateKey(String privateKeyHex) {
    if (!NostrEncoding.isValidHexKey(privateKeyHex)) {
      throw const KeyStorageException('Invalid private key format');
    }
    
    // Derive the actual public key using secp256k1
    final publicKeyHex = getPublicKey(privateKeyHex);
    
    return NostrKeyPair(
      publicKeyHex: publicKeyHex,
      privateKeyHex: privateKeyHex,
      npub: NostrEncoding.encodePublicKey(publicKeyHex),
      nsec: NostrEncoding.encodePrivateKey(privateKeyHex),
    );
  }
  
  /// Create key pair from nsec (bech32 private key)
  factory NostrKeyPair.fromNsec(String nsec) {
    final privateKeyHex = NostrEncoding.decodePrivateKey(nsec);
    return NostrKeyPair.fromPrivateKey(privateKeyHex);
  }
  
  /// Generate a new random key pair with timeout for iOS safety
  factory NostrKeyPair.generate() {
    try {
      debugPrint('🔧 Starting key generation...');
      final privateKeyHex = generatePrivateKey();
      debugPrint('✅ Private key generated successfully');
      final keyPair = NostrKeyPair.fromPrivateKey(privateKeyHex);
      debugPrint('✅ Key pair created successfully');
      return keyPair;
    } catch (e) {
      debugPrint('❌ Key generation failed: $e');
      rethrow;
    }
  }
  
  @override
  String toString() => 'NostrKeyPair(npub: ${NostrEncoding.maskKey(npub)})';
}

/// DEPRECATED: Legacy service for storage and management of Nostr keys
/// 
/// WARNING: This service has critical security vulnerabilities and should not be used
/// in production. Use SecureKeyStorageService instead.
@Deprecated('Use SecureKeyStorageService for secure key storage')
class KeyStorageService extends ChangeNotifier {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'nostr_secure_prefs',
      preferencesKeyPrefix: 'nostr_',
    ),
    iOptions: IOSOptions(
      groupId: 'group.openvine.keys',
      accountName: 'OpenVine',
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  // Storage keys
  static const String _privateKeyKey = 'nostr_private_key';
  static const String _publicKeyKey = 'nostr_public_key';
  static const String _npubKey = 'nostr_npub';
  static const String _nsecKey = 'nostr_nsec';
  static const String _hasKeysKey = 'has_nostr_keys';
  static const String _keyCreatedAtKey = 'key_created_at';
  static const String _lastAccessKey = 'last_key_access';
  
  // Multiple identity storage keys
  static const String _savedKeysPrefix = 'saved_identity_';
  
  // In-memory cache for performance
  NostrKeyPair? _cachedKeyPair;
  DateTime? _cacheTimestamp;
  static const Duration _cacheTimeout = Duration(minutes: 15);
  
  // Initialization state
  bool _isInitialized = false;
  bool _useSecureStorage = true;
  
  /// Initialize the key storage service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    debugPrint('🔐 Initializing KeyStorageService');
    
    try {
      // Test secure storage access
      await _secureStorage.containsKey(key: _hasKeysKey);
      
      _isInitialized = true;
      debugPrint('✅ KeyStorageService initialized');
      
    } catch (e) {
      debugPrint('⚠️ Secure storage not available (likely web/Chrome): $e');
      // Fallback to SharedPreferences for web/development
      _useSecureStorage = false;
      _isInitialized = true;
      debugPrint('🔧 KeyStorageService initialized in compatibility mode (using SharedPreferences)');
    }
  }
  
  /// Check if user has stored keys
  Future<bool> hasKeys() async {
    await _ensureInitialized();
    
    try {
      if (_useSecureStorage) {
        try {
          final hasKeysValue = await _secureStorage.read(key: _hasKeysKey);
          if (hasKeysValue == 'true') return true;
        } catch (secureStorageError) {
          debugPrint('⚠️ Secure storage read failed, checking fallback: $secureStorageError');
        }
        
        // Check fallback storage for development
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('dev_$_hasKeysKey') == 'true';
      } else {
        // Fallback to SharedPreferences for web
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool(_hasKeysKey) ?? false;
      }
    } catch (e) {
      debugPrint('⚠️ Error checking for keys: $e');
      return false;
    }
  }
  
  /// Store a new key pair securely
  Future<void> storeKeyPair(NostrKeyPair keyPair) async {
    await _ensureInitialized();
    
    try {
      debugPrint('🔐 Storing new key pair');
      
      try {
        // Try secure storage first
        await Future.wait([
          _secureStorage.write(key: _privateKeyKey, value: keyPair.privateKeyHex),
          _secureStorage.write(key: _publicKeyKey, value: keyPair.publicKeyHex),
          _secureStorage.write(key: _npubKey, value: keyPair.npub),
          _secureStorage.write(key: _nsecKey, value: keyPair.nsec),
          _secureStorage.write(key: _hasKeysKey, value: 'true'),
          _secureStorage.write(key: _keyCreatedAtKey, value: DateTime.now().toIso8601String()),
        ]);
        
        debugPrint('✅ Key pair stored in secure storage');
      } catch (secureStorageError) {
        debugPrint('⚠️ Secure storage failed, falling back to SharedPreferences: $secureStorageError');
        
        // Fallback to SharedPreferences for development
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dev_$_privateKeyKey', keyPair.privateKeyHex);
        await prefs.setString('dev_$_publicKeyKey', keyPair.publicKeyHex);
        await prefs.setString('dev_$_npubKey', keyPair.npub);
        await prefs.setString('dev_$_nsecKey', keyPair.nsec);
        await prefs.setString('dev_$_hasKeysKey', 'true');
        await prefs.setString('dev_$_keyCreatedAtKey', DateTime.now().toIso8601String());
        
        debugPrint('✅ Key pair stored in SharedPreferences (development fallback)');
      }
      
      // Update cache
      _cachedKeyPair = keyPair;
      _cacheTimestamp = DateTime.now();
      
      await _updateLastAccess();
      
      debugPrint('🔑 Public key: ${NostrEncoding.maskKey(keyPair.npub)}');
      
      notifyListeners();
      
    } catch (e) {
      throw KeyStorageException('Failed to store key pair: $e');
    }
  }
  
  /// Generate and store a new key pair
  Future<NostrKeyPair> generateAndStoreKeys() async {
    await _ensureInitialized();
    
    debugPrint('🔧 Generating new Nostr key pair');
    
    try {
      // Add timeout for iOS safety - key generation can sometimes hang
      final keyPair = await Future.any([
        Future(() => NostrKeyPair.generate()),
        Future.delayed(const Duration(seconds: 10), () => throw TimeoutException('Key generation timed out', const Duration(seconds: 10))),
      ]);
      
      await storeKeyPair(keyPair);
      
      debugPrint('✅ Generated and stored new key pair');
      return keyPair;
      
    } catch (e) {
      debugPrint('❌ Key generation error: $e');
      throw KeyStorageException('Failed to generate keys: $e');
    }
  }
  
  /// Import keys from nsec (bech32 private key)
  Future<NostrKeyPair> importFromNsec(String nsec) async {
    await _ensureInitialized();
    
    debugPrint('📥 Importing keys from nsec');
    
    try {
      if (!NostrEncoding.isValidNsec(nsec)) {
        throw const KeyStorageException('Invalid nsec format');
      }
      
      final keyPair = NostrKeyPair.fromNsec(nsec);
      await storeKeyPair(keyPair);
      
      debugPrint('✅ Keys imported successfully');
      return keyPair;
      
    } catch (e) {
      throw KeyStorageException('Failed to import keys: $e');
    }
  }
  
  /// Import keys from hex private key
  Future<NostrKeyPair> importFromHex(String privateKeyHex) async {
    await _ensureInitialized();
    
    debugPrint('📥 Importing keys from hex');
    
    try {
      if (!NostrEncoding.isValidHexKey(privateKeyHex)) {
        throw const KeyStorageException('Invalid private key format');
      }
      
      final keyPair = NostrKeyPair.fromPrivateKey(privateKeyHex);
      await storeKeyPair(keyPair);
      
      debugPrint('✅ Keys imported successfully');
      return keyPair;
      
    } catch (e) {
      throw KeyStorageException('Failed to import keys: $e');
    }
  }
  
  /// Get the current key pair
  Future<NostrKeyPair?> getKeyPair() async {
    await _ensureInitialized();
    
    // Check cache first
    if (_cachedKeyPair != null && _isCacheValid()) {
      await _updateLastAccess();
      return _cachedKeyPair;
    }
    
    try {
      String? privateKey;
      
      try {
        // Try secure storage first
        final hasKeysValue = await _secureStorage.read(key: _hasKeysKey);
        if (hasKeysValue == 'true') {
          privateKey = await _secureStorage.read(key: _privateKeyKey);
        }
      } catch (secureStorageError) {
        debugPrint('⚠️ Secure storage read failed, checking fallback: $secureStorageError');
      }
      
      // Check fallback storage if secure storage failed
      if (privateKey == null) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString('dev_$_hasKeysKey') == 'true') {
          privateKey = prefs.getString('dev_$_privateKeyKey');
        }
      }
      
      if (privateKey == null) return null;
      
      // Reconstruct key pair from stored private key
      final keyPair = NostrKeyPair.fromPrivateKey(privateKey);
      
      // Update cache
      _cachedKeyPair = keyPair;
      _cacheTimestamp = DateTime.now();
      
      await _updateLastAccess();
      
      return keyPair;
      
    } catch (e) {
      debugPrint('❌ Error retrieving key pair: $e');
      throw KeyStorageException('Failed to retrieve keys: $e');
    }
  }
  
  /// Get only the public key (npub)
  Future<String?> getPublicKey() async {
    final keyPair = await getKeyPair();
    return keyPair?.npub;
  }
  
  /// Get the private key for signing (use carefully!)
  Future<String?> getPrivateKeyForSigning() async {
    await _ensureInitialized();
    
    try {
      final keyPair = await getKeyPair();
      if (keyPair == null) return null;
      
      debugPrint('🔓 Private key accessed for signing');
      await _updateLastAccess();
      
      return keyPair.privateKeyHex;
      
    } catch (e) {
      throw KeyStorageException('Failed to get private key: $e');
    }
  }
  
  /// Export nsec for backup (use with extreme caution!)
  Future<String?> exportNsec() async {
    final keyPair = await getKeyPair();
    if (keyPair == null) return null;
    
    debugPrint('⚠️ NSEC exported - ensure secure handling');
    return keyPair.nsec;
  }
  
  /// Delete all stored keys (irreversible!)
  Future<void> deleteKeys() async {
    await _ensureInitialized();
    
    debugPrint('🗑️ Deleting all stored keys');
    
    try {
      await Future.wait([
        _secureStorage.delete(key: _privateKeyKey),
        _secureStorage.delete(key: _publicKeyKey),
        _secureStorage.delete(key: _npubKey),
        _secureStorage.delete(key: _nsecKey),
        _secureStorage.delete(key: _hasKeysKey),
        _secureStorage.delete(key: _keyCreatedAtKey),
        _secureStorage.delete(key: _lastAccessKey),
      ]);
      
      // Clear cache
      _cachedKeyPair = null;
      _cacheTimestamp = null;
      
      debugPrint('✅ All keys deleted');
      notifyListeners();
      
    } catch (e) {
      throw KeyStorageException('Failed to delete keys: $e');
    }
  }
  
  /// Get key creation timestamp
  Future<DateTime?> getKeyCreationTime() async {
    try {
      final timestamp = await _secureStorage.read(key: _keyCreatedAtKey);
      return timestamp != null ? DateTime.parse(timestamp) : null;
    } catch (e) {
      return null;
    }
  }
  
  /// Get last access timestamp
  Future<DateTime?> getLastAccessTime() async {
    try {
      final timestamp = await _secureStorage.read(key: _lastAccessKey);
      return timestamp != null ? DateTime.parse(timestamp) : null;
    } catch (e) {
      return null;
    }
  }
  
  /// Clear the in-memory cache
  void clearCache() {
    _cachedKeyPair = null;
    _cacheTimestamp = null;
    debugPrint('🧹 Key cache cleared');
  }
  
  /// Check if the cache is still valid
  bool _isCacheValid() {
    if (_cacheTimestamp == null) return false;
    
    final age = DateTime.now().difference(_cacheTimestamp!);
    return age < _cacheTimeout;
  }
  
  /// Update the last access timestamp
  Future<void> _updateLastAccess() async {
    try {
      await _secureStorage.write(
        key: _lastAccessKey, 
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      // Non-critical error, just log it
      debugPrint('⚠️ Failed to update last access time: $e');
    }
  }
  
  /// Ensure the service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
  
  /// Store a key pair for a specific identity (for multi-account support)
  Future<void> storeIdentityKeyPair(String npub, NostrKeyPair keyPair) async {
    await _ensureInitialized();
    
    try {
      debugPrint('🔐 Storing identity key pair for ${NostrEncoding.maskKey(npub)}');
      
      final identityKey = '$_savedKeysPrefix$npub';
      
      // Store as JSON for the saved identity
      final identityData = {
        'privateKeyHex': keyPair.privateKeyHex,
        'publicKeyHex': keyPair.publicKeyHex,
        'npub': keyPair.npub,
        'nsec': keyPair.nsec,
        'savedAt': DateTime.now().toIso8601String(),
      };
      
      if (_useSecureStorage) {
        try {
          await _secureStorage.write(
            key: identityKey,
            value: jsonEncode(identityData),
          );
          debugPrint('✅ Identity stored in secure storage');
        } catch (e) {
          debugPrint('⚠️ Secure storage failed, using SharedPreferences: $e');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('dev_$identityKey', jsonEncode(identityData));
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(identityKey, jsonEncode(identityData));
      }
      
      debugPrint('✅ Stored identity for ${NostrEncoding.maskKey(npub)}');
    } catch (e) {
      throw KeyStorageException('Failed to store identity: $e');
    }
  }
  
  /// Retrieve a key pair for a specific identity
  Future<NostrKeyPair?> getIdentityKeyPair(String npub) async {
    await _ensureInitialized();
    
    try {
      final identityKey = '$_savedKeysPrefix$npub';
      String? identityJson;
      
      if (_useSecureStorage) {
        try {
          identityJson = await _secureStorage.read(key: identityKey);
        } catch (e) {
          debugPrint('⚠️ Secure storage read failed, checking SharedPreferences: $e');
          final prefs = await SharedPreferences.getInstance();
          identityJson = prefs.getString('dev_$identityKey');
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        identityJson = prefs.getString(identityKey);
      }
      
      if (identityJson == null) {
        debugPrint('⚠️ No saved identity found for ${NostrEncoding.maskKey(npub)}');
        return null;
      }
      
      final identityData = jsonDecode(identityJson) as Map<String, dynamic>;
      
      return NostrKeyPair(
        publicKeyHex: identityData['publicKeyHex'] as String,
        privateKeyHex: identityData['privateKeyHex'] as String,
        npub: identityData['npub'] as String,
        nsec: identityData['nsec'] as String,
      );
    } catch (e) {
      debugPrint('❌ Error retrieving identity: $e');
      return null;
    }
  }
  
  /// Switch to a different identity
  Future<bool> switchToIdentity(String npub) async {
    try {
      // First, save the current identity
      final currentKeyPair = await getKeyPair();
      if (currentKeyPair != null) {
        await storeIdentityKeyPair(currentKeyPair.npub, currentKeyPair);
      }
      
      // Get the target identity
      final targetKeyPair = await getIdentityKeyPair(npub);
      if (targetKeyPair == null) {
        debugPrint('❌ Target identity not found');
        return false;
      }
      
      // Store as the active identity
      await storeKeyPair(targetKeyPair);
      
      debugPrint('✅ Switched to identity: ${NostrEncoding.maskKey(npub)}');
      return true;
    } catch (e) {
      debugPrint('❌ Error switching identity: $e');
      return false;
    }
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing KeyStorageService');
    clearCache();
    super.dispose();
  }
}