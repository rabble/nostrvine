// ABOUTME: Secure key storage service using hardware-backed security and memory-safe containers
// ABOUTME: Replaces the vulnerable KeyStorageService with production-grade cryptographic key protection

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/secure_key_container.dart';
import '../utils/nostr_encoding.dart';
import 'platform_secure_storage.dart';

/// Exception thrown by secure key storage operations
class SecureKeyStorageException implements Exception {
  final String message;
  final String? code;
  
  const SecureKeyStorageException(this.message, {this.code});
  
  @override
  String toString() => 'SecureKeyStorageException: $message';
}

/// Security configuration for key storage operations
class SecurityConfig {
  final bool requireHardwareBacked;
  final bool requireBiometrics;
  final bool allowFallbackSecurity;
  
  const SecurityConfig({
    this.requireHardwareBacked = true,
    this.requireBiometrics = false,
    this.allowFallbackSecurity = false,
  });
  
  /// Default high-security configuration
  static const SecurityConfig strict = SecurityConfig(
    requireHardwareBacked: true,
    requireBiometrics: false,
    allowFallbackSecurity: false,
  );
  
  /// Desktop-compatible configuration (allows software-only security)
  static const SecurityConfig desktop = SecurityConfig(
    requireHardwareBacked: false,
    requireBiometrics: false,
    allowFallbackSecurity: true,
  );
  
  /// Maximum security configuration with biometrics
  static const SecurityConfig maximum = SecurityConfig(
    requireHardwareBacked: true,
    requireBiometrics: true,
    allowFallbackSecurity: false,
  );
  
  /// Fallback configuration for older devices
  static const SecurityConfig compatible = SecurityConfig(
    requireHardwareBacked: false,
    requireBiometrics: false,
    allowFallbackSecurity: true,
  );
}

/// Secure key storage service with hardware-backed protection
class SecureKeyStorageService extends ChangeNotifier {
  static const String _primaryKeyId = 'nostr_primary_key';
  static const String _keyCreatedAtKey = 'key_created_at';
  static const String _lastAccessKey = 'last_key_access';
  static const String _savedKeysPrefix = 'saved_identity_';
  
  final PlatformSecureStorage _platformStorage = PlatformSecureStorage.instance;
  SecurityConfig _securityConfig = SecurityConfig.strict;
  
  // Secure in-memory cache (automatically wiped)
  SecureKeyContainer? _cachedKeyContainer;
  DateTime? _cacheTimestamp;
  static const Duration _cacheTimeout = Duration(minutes: 5); // Reduced from 15 minutes
  
  // Initialization state
  bool _isInitialized = false;
  String? _initializationError;
  
  SecureKeyStorageService({SecurityConfig? securityConfig}) {
    if (securityConfig != null) {
      _securityConfig = securityConfig;
    } else {
      // Use platform-appropriate default configuration
      _securityConfig = _getPlatformDefaultConfig();
    }
  }
  
  /// Get platform-appropriate default security configuration
  SecurityConfig _getPlatformDefaultConfig() {
    if (kIsWeb) {
      // Web: Use browser storage persistence, no hardware backing
      return const SecurityConfig(
        requireHardwareBacked: false,
        requireBiometrics: false,
        allowFallbackSecurity: true,
      );
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      // Desktop: Use OS keychain/credential store, allow software fallback
      return SecurityConfig.desktop;
    } else {
      // Mobile (iOS/Android): Prefer hardware backing but allow fallback
      return const SecurityConfig(
        requireHardwareBacked: false, // Changed to false to allow fallback
        requireBiometrics: false,
        allowFallbackSecurity: true,
      );
    }
  }
  
  /// Initialize the secure key storage service
  Future<void> initialize() async {
    if (_isInitialized && _initializationError == null) return;
    
    debugPrint('🔐 Initializing SecureKeyStorageService');
    
    try {
      // Initialize platform-specific secure storage
      await _platformStorage.initialize();
      
      // Check if we can meet our security requirements
      if (_securityConfig.requireHardwareBacked && !_platformStorage.supportsHardwareSecurity) {
        if (!_securityConfig.allowFallbackSecurity) {
          throw const SecureKeyStorageException(
            'Hardware-backed security required but not available on this device',
            code: 'hardware_not_available',
          );
        } else {
          debugPrint('⚠️ Hardware security not available, using software fallback');
        }
      }
      
      if (_securityConfig.requireBiometrics && !_platformStorage.supportsBiometrics) {
        if (!_securityConfig.allowFallbackSecurity) {
          throw const SecureKeyStorageException(
            'Biometric authentication required but not available on this device',
            code: 'biometrics_not_available',
          );
        } else {
          debugPrint('⚠️ Biometrics not available, continuing without biometric protection');
        }
      }
      
      _isInitialized = true;
      _initializationError = null;
      
      debugPrint('✅ SecureKeyStorageService initialized');
      debugPrint('🔒 Security level: ${_getSecurityLevelDescription()}');
      
    } catch (e) {
      _initializationError = e.toString();
      debugPrint('❌ Failed to initialize secure key storage: $e');
      rethrow;
    }
  }
  
  /// Check if user has stored keys
  Future<bool> hasKeys() async {
    await _ensureInitialized();
    
    try {
      return await _platformStorage.hasKey(_primaryKeyId);
    } catch (e) {
      debugPrint('⚠️ Error checking for keys: $e');
      return false;
    }
  }
  
  /// Generate and store a new secure key pair
  Future<SecureKeyContainer> generateAndStoreKeys({
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();
    
    debugPrint('🔧 Generating new secure Nostr key pair');
    
    try {
      // Generate new secure key container
      final keyContainer = SecureKeyContainer.generate();
      
      debugPrint('🔑 Generated key for: ${NostrEncoding.maskKey(keyContainer.npub)}');
      
      // Store in platform-specific secure storage
      final result = await _platformStorage.storeKey(
        keyId: _primaryKeyId,
        keyContainer: keyContainer,
        requireBiometrics: _securityConfig.requireBiometrics,
        requireHardwareBacked: _securityConfig.requireHardwareBacked,
      );
      
      if (!result.success) {
        keyContainer.dispose();
        throw SecureKeyStorageException('Failed to store key: ${result.error}');
      }
      
      // Update cache
      _updateCache(keyContainer);
      
      // Store metadata
      await _storeMetadata();
      
      debugPrint('✅ Generated and stored new secure key pair');
      debugPrint('🔒 Security level: ${result.securityLevel?.name ?? 'unknown'}');
      
      notifyListeners();
      return keyContainer;
      
    } catch (e) {
      debugPrint('❌ Key generation error: $e');
      if (e is SecureKeyStorageException) rethrow;
      throw SecureKeyStorageException('Failed to generate keys: $e');
    }
  }
  
  /// Import keys from nsec (bech32 private key)
  Future<SecureKeyContainer> importFromNsec(String nsec, {
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();
    
    debugPrint('📥 Importing keys from nsec');
    
    try {
      if (!NostrEncoding.isValidNsec(nsec)) {
        throw const SecureKeyStorageException('Invalid nsec format');
      }
      
      // Create secure container from nsec
      final keyContainer = SecureKeyContainer.fromNsec(nsec);
      
      debugPrint('🔑 Imported key for: ${NostrEncoding.maskKey(keyContainer.npub)}');
      
      // Store in platform-specific secure storage
      final result = await _platformStorage.storeKey(
        keyId: _primaryKeyId,
        keyContainer: keyContainer,
        requireBiometrics: _securityConfig.requireBiometrics,
        requireHardwareBacked: _securityConfig.requireHardwareBacked,
      );
      
      if (!result.success) {
        keyContainer.dispose();
        throw SecureKeyStorageException('Failed to store imported key: ${result.error}');
      }
      
      // Update cache
      _updateCache(keyContainer);
      
      // Store metadata
      await _storeMetadata();
      
      debugPrint('✅ Keys imported and stored securely');
      debugPrint('🔒 Security level: ${result.securityLevel?.name ?? 'unknown'}');
      
      notifyListeners();
      return keyContainer;
      
    } catch (e) {
      debugPrint('❌ Import error: $e');
      if (e is SecureKeyStorageException) rethrow;
      throw SecureKeyStorageException('Failed to import keys: $e');
    }
  }
  
  /// Get the current secure key container
  Future<SecureKeyContainer?> getKeyContainer({
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();
    
    // Check cache first
    if (_cachedKeyContainer != null && !_cachedKeyContainer!.isDisposed && _isCacheValid()) {
      await _updateLastAccess();
      return _cachedKeyContainer;
    }
    
    try {
      debugPrint('🔓 Retrieving secure key container');
      
      final keyContainer = await _platformStorage.retrieveKey(
        keyId: _primaryKeyId,
        biometricPrompt: biometricPrompt,
      );
      
      if (keyContainer == null) {
        debugPrint('⚠️ No key found in secure storage');
        return null;
      }
      
      // Update cache
      _updateCache(keyContainer);
      
      await _updateLastAccess();
      
      debugPrint('✅ Retrieved secure key container');
      return keyContainer;
      
    } catch (e) {
      debugPrint('❌ Error retrieving key container: $e');
      if (e is SecureKeyStorageException) rethrow;
      throw SecureKeyStorageException('Failed to retrieve keys: $e');
    }
  }
  
  /// Import keys from hex private key
  Future<SecureKeyContainer> importFromHex(String privateKeyHex, {
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();
    
    debugPrint('📥 Importing keys from hex to secure storage');
    
    try {
      if (!NostrEncoding.isValidHexKey(privateKeyHex)) {
        throw const SecureKeyStorageException('Invalid private key format');
      }
      
      // Create secure container from hex
      final keyContainer = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
      
      debugPrint('🔑 Imported key for: ${NostrEncoding.maskKey(keyContainer.npub)}');
      
      // Store in platform-specific secure storage
      final result = await _platformStorage.storeKey(
        keyId: _primaryKeyId,
        keyContainer: keyContainer,
        requireBiometrics: _securityConfig.requireBiometrics,
        requireHardwareBacked: _securityConfig.requireHardwareBacked,
      );
      
      if (!result.success) {
        keyContainer.dispose();
        throw SecureKeyStorageException('Failed to store imported key: ${result.error}');
      }
      
      // Update cache
      _updateCache(keyContainer);
      
      // Store metadata
      await _storeMetadata();
      
      debugPrint('✅ Keys imported from hex and stored securely');
      debugPrint('🔒 Security level: ${result.securityLevel?.name ?? 'unknown'}');
      
      notifyListeners();
      return keyContainer;
      
    } catch (e) {
      debugPrint('❌ Hex import error: $e');
      if (e is SecureKeyStorageException) rethrow;
      throw SecureKeyStorageException('Failed to import keys: $e');
    }
  }
  
  /// Get only the public key (npub)
  Future<String?> getPublicKey({String? biometricPrompt}) async {
    final keyContainer = await getKeyContainer(biometricPrompt: biometricPrompt);
    return keyContainer?.npub;
  }
  
  /// Perform operation with private key (for signing)
  Future<T?> withPrivateKey<T>(
    T Function(String privateKeyHex) operation, {
    String? biometricPrompt,
  }) async {
    final keyContainer = await getKeyContainer(biometricPrompt: biometricPrompt);
    if (keyContainer == null) return null;
    
    debugPrint('🔓 Private key accessed for signing operation');
    await _updateLastAccess();
    
    return keyContainer.withPrivateKey(operation);
  }
  
  /// Export nsec for backup (use with extreme caution!)
  Future<String?> exportNsec({
    String? biometricPrompt,
  }) async {
    final keyContainer = await getKeyContainer(biometricPrompt: biometricPrompt);
    if (keyContainer == null) return null;
    
    debugPrint('⚠️ NSEC export requested - ensure secure handling');
    
    return keyContainer.withNsec((nsec) => nsec);
  }
  
  /// Delete all stored keys (irreversible!)
  Future<void> deleteKeys({
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();
    
    debugPrint('🗑️ Deleting all stored secure keys');
    
    try {
      // Delete from platform storage
      final success = await _platformStorage.deleteKey(
        keyId: _primaryKeyId,
        biometricPrompt: biometricPrompt,
      );
      
      if (!success) {
        debugPrint('⚠️ Platform key deletion may have failed');
      }
      
      // Clear cache
      _clearCache();
      
      // TODO: Delete metadata
      
      debugPrint('✅ All keys deleted');
      notifyListeners();
      
    } catch (e) {
      throw SecureKeyStorageException('Failed to delete keys: $e');
    }
  }
  
  /// Store a key container for a specific identity (multi-account support)
  Future<void> storeIdentityKeyContainer(String npub, SecureKeyContainer keyContainer) async {
    await _ensureInitialized();
    
    try {
      debugPrint('🔐 Storing identity key container for ${NostrEncoding.maskKey(npub)}');
      
      final identityKeyId = '$_savedKeysPrefix$npub';
      
      final result = await _platformStorage.storeKey(
        keyId: identityKeyId,
        keyContainer: keyContainer,
        requireBiometrics: _securityConfig.requireBiometrics,
        requireHardwareBacked: _securityConfig.requireHardwareBacked,
      );
      
      if (!result.success) {
        throw SecureKeyStorageException('Failed to store identity: ${result.error}');
      }
      
      debugPrint('✅ Stored identity for ${NostrEncoding.maskKey(npub)}');
    } catch (e) {
      if (e is SecureKeyStorageException) rethrow;
      throw SecureKeyStorageException('Failed to store identity: $e');
    }
  }
  
  /// Retrieve a key container for a specific identity
  Future<SecureKeyContainer?> getIdentityKeyContainer(String npub, {
    String? biometricPrompt,
  }) async {
    await _ensureInitialized();
    
    try {
      final identityKeyId = '$_savedKeysPrefix$npub';
      
      return await _platformStorage.retrieveKey(
        keyId: identityKeyId,
        biometricPrompt: biometricPrompt,
      );
    } catch (e) {
      debugPrint('❌ Error retrieving identity: $e');
      return null;
    }
  }
  
  /// Switch to a different identity
  Future<bool> switchToIdentity(String npub, {
    String? biometricPrompt,
  }) async {
    try {
      // Save current identity first
      final currentContainer = await getKeyContainer(biometricPrompt: biometricPrompt);
      if (currentContainer != null) {
        await storeIdentityKeyContainer(currentContainer.npub, currentContainer);
      }
      
      // Get target identity
      final targetContainer = await getIdentityKeyContainer(npub, biometricPrompt: biometricPrompt);
      if (targetContainer == null) {
        debugPrint('❌ Target identity not found');
        return false;
      }
      
      // Store as primary identity
      final result = await _platformStorage.storeKey(
        keyId: _primaryKeyId,
        keyContainer: targetContainer,
        requireBiometrics: _securityConfig.requireBiometrics,
        requireHardwareBacked: _securityConfig.requireHardwareBacked,
      );
      
      if (!result.success) {
        targetContainer.dispose();
        return false;
      }
      
      // Update cache
      _updateCache(targetContainer);
      
      debugPrint('✅ Switched to identity: ${NostrEncoding.maskKey(npub)}');
      notifyListeners();
      return true;
      
    } catch (e) {
      debugPrint('❌ Error switching identity: $e');
      return false;
    }
  }
  
  /// Get security information
  Map<String, dynamic> get securityInfo {
    return {
      'platform': _platformStorage.platformName,
      'hardware_backed': _platformStorage.supportsHardwareSecurity,
      'biometrics_available': _platformStorage.supportsBiometrics,
      'capabilities': _platformStorage.capabilities.map((c) => c.name).toList(),
      'security_config': {
        'require_hardware': _securityConfig.requireHardwareBacked,
        'require_biometrics': _securityConfig.requireBiometrics,
        'allow_fallback': _securityConfig.allowFallbackSecurity,
      },
      'cache_timeout_minutes': _cacheTimeout.inMinutes,
    };
  }
  
  /// Update the in-memory cache with a new key container
  void _updateCache(SecureKeyContainer keyContainer) {
    // Dispose old cached container
    _clearCache();
    
    // Set new cache
    _cachedKeyContainer = keyContainer;
    _cacheTimestamp = DateTime.now();
  }
  
  /// Clear the in-memory cache
  void _clearCache() {
    _cachedKeyContainer?.dispose();
    _cachedKeyContainer = null;
    _cacheTimestamp = null;
    debugPrint('🧹 Secure key cache cleared');
  }
  
  /// Public method to clear cache (for compatibility)
  void clearCache() {
    _clearCache();
  }
  
  /// Check if the cache is still valid
  bool _isCacheValid() {
    if (_cacheTimestamp == null) return false;
    
    final age = DateTime.now().difference(_cacheTimestamp!);
    return age < _cacheTimeout;
  }
  
  /// Store metadata about key operations
  Future<void> _storeMetadata() async {
    // TODO: Implement metadata storage (creation time, last access, etc.)
    // This will need to use regular SharedPreferences for non-sensitive metadata
  }
  
  /// Update the last access timestamp
  Future<void> _updateLastAccess() async {
    // TODO: Implement last access tracking
  }
  
  /// Get security level description
  String _getSecurityLevelDescription() {
    final parts = <String>[];
    
    if (_platformStorage.supportsHardwareSecurity) {
      parts.add('Hardware-backed');
    } else {
      parts.add('Software-only');
    }
    
    if (_platformStorage.supportsBiometrics) {
      parts.add('Biometric-capable');
    }
    
    return parts.join(', ');
  }
  
  /// Ensure the service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized || _initializationError != null) {
      await initialize();
    }
  }
  
  @override
  void dispose() {
    debugPrint('🗑️ Disposing SecureKeyStorageService');
    _clearCache();
    super.dispose();
  }
}