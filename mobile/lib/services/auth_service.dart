// ABOUTME: Authentication service managing user login, key generation, and auth state
// ABOUTME: Handles Nostr identity creation, import, and session management with secure storage

import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:nostr_sdk/event.dart';
import 'secure_key_storage_service.dart';
import 'key_migration_service.dart';
import '../utils/secure_key_container.dart';
import '../utils/nostr_encoding.dart';
import '../utils/nostr_timestamp.dart';
import '../utils/unified_logger.dart';
import 'user_profile_service.dart' as ups;

/// Authentication state for the user
enum AuthState {
  /// User is not authenticated (no keys stored)
  unauthenticated,
  /// User is authenticated (has valid keys)
  authenticated,
  /// Authentication state is being checked
  checking,
  /// Authentication is in progress (generating/importing keys)
  authenticating,
}

/// Result of authentication operations
class AuthResult {
  final bool success;
  final String? errorMessage;
  final SecureKeyContainer? keyContainer;
  
  const AuthResult({
    required this.success,
    this.errorMessage,
    this.keyContainer,
  });
  
  factory AuthResult.success(SecureKeyContainer keyContainer) {
    return AuthResult(success: true, keyContainer: keyContainer);
  }
  
  factory AuthResult.failure(String errorMessage) {
    return AuthResult(success: false, errorMessage: errorMessage);
  }
}

/// User profile information
class UserProfile {
  final String npub;
  final String publicKeyHex;
  final DateTime? keyCreatedAt;
  final DateTime? lastAccessAt;
  final String displayName;
  final String? about;
  final String? picture;
  final String? nip05;
  
  const UserProfile({
    required this.npub,
    required this.publicKeyHex,
    this.keyCreatedAt,
    this.lastAccessAt,
    required this.displayName,
    this.about,
    this.picture,
    this.nip05,
  });
  
  /// Create minimal profile from secure key container
  factory UserProfile.fromSecureContainer(SecureKeyContainer keyContainer) {
    return UserProfile(
      npub: keyContainer.npub,
      publicKeyHex: keyContainer.publicKeyHex,
      displayName: NostrEncoding.maskKey(keyContainer.npub),
    );
  }
}

/// Main authentication service for the OpenVine app
class AuthService extends ChangeNotifier {
  final SecureKeyStorageService _keyStorage;
  final KeyMigrationService _migrationService;
  
  AuthState _authState = AuthState.checking;
  SecureKeyContainer? _currentKeyContainer;
  UserProfile? _currentProfile;
  String? _lastError;
  bool _migrationRequired = false;
  
  // Streaming controllers for reactive auth state
  final StreamController<AuthState> _authStateController = 
      StreamController<AuthState>.broadcast();
  final StreamController<UserProfile?> _profileController = 
      StreamController<UserProfile?>.broadcast();
      
  AuthService({SecureKeyStorageService? keyStorage}) 
      : _keyStorage = keyStorage ?? SecureKeyStorageService(),
        _migrationService = KeyMigrationService();
  
  /// Current authentication state
  AuthState get authState => _authState;
  
  /// Stream of authentication state changes
  Stream<AuthState> get authStateStream => _authStateController.stream;
  
  /// Current user profile (null if not authenticated)
  UserProfile? get currentProfile => _currentProfile;
  
  /// Stream of profile changes
  Stream<UserProfile?> get profileStream => _profileController.stream;
  
  /// Current public key (npub format)
  String? get currentNpub => _currentKeyContainer?.npub;
  
  /// Current public key (hex format)
  String? get currentPublicKeyHex => _currentKeyContainer?.publicKeyHex;
  
  /// Check if migration is required
  bool get migrationRequired => _migrationRequired;
  
  /// Check if user is authenticated
  bool get isAuthenticated => _authState == AuthState.authenticated;
  
  /// Last authentication error
  String? get lastError => _lastError;
  
  /// Perform migration from legacy storage if needed
  Future<bool> performMigrationIfNeeded({String? biometricPrompt}) async {
    if (!_migrationRequired) return true;
    
    Log.debug('Performing key migration to secure storage', name: 'AuthService', category: LogCategory.auth);
    
    try {
      final result = await _migrationService.performMigration(
        biometricPrompt: biometricPrompt,
        deleteAfterMigration: true,
      );
      
      if (result.isSuccess) {
        _migrationRequired = false;
        Log.info('Migration completed successfully', name: 'AuthService', category: LogCategory.auth);
        
        // Re-check auth after migration
        await _checkExistingAuth();
        return true;
      } else {
        Log.error('Migration failed: ${result.error}', name: 'AuthService', category: LogCategory.auth);
        _lastError = 'Migration failed: ${result.error}';
        return false;
      }
    } catch (e) {
      Log.error('Migration error: $e', name: 'AuthService', category: LogCategory.auth);
      _lastError = 'Migration error: $e';
      return false;
    }
  }
  
  /// Initialize the authentication service
  Future<void> initialize() async {
    Log.debug('� Initializing SecureAuthService', name: 'AuthService', category: LogCategory.auth);
    
    // Defer state changes to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setAuthState(AuthState.checking);
    });
    
    try {
      // Initialize secure key storage
      await _keyStorage.initialize();
      
      // Check if migration is needed
      await _checkMigrationStatus();
      
      // Check for existing keys
      await _checkExistingAuth();
      
      Log.info('SecureAuthService initialized', name: 'AuthService', category: LogCategory.auth);
      
    } catch (e) {
      Log.error('SecureAuthService initialization failed: $e', name: 'AuthService', category: LogCategory.auth);
      _lastError = 'Failed to initialize auth: $e';
      
      // Defer state change to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setAuthState(AuthState.unauthenticated);
      });
    }
  }
  
  /// Create a new Nostr identity
  Future<AuthResult> createNewIdentity({String? biometricPrompt}) async {
    Log.debug('� Creating new secure Nostr identity', name: 'AuthService', category: LogCategory.auth);
    
    _setAuthState(AuthState.authenticating);
    _lastError = null;
    
    try {
      // Generate new secure key container
      final keyContainer = await _keyStorage.generateAndStoreKeys(
        biometricPrompt: biometricPrompt,
      );
      
      // Set up user session
      await _setupUserSession(keyContainer);
      
      Log.info('New secure identity created successfully', name: 'AuthService', category: LogCategory.auth);
      Log.debug('� Public key: ${NostrEncoding.maskKey(keyContainer.npub)}', name: 'AuthService', category: LogCategory.auth);
      
      return AuthResult.success(keyContainer);
      
    } catch (e) {
      Log.error('Failed to create secure identity: $e', name: 'AuthService', category: LogCategory.auth);
      _lastError = 'Failed to create identity: $e';
      _setAuthState(AuthState.unauthenticated);
      
      return AuthResult.failure(_lastError!);
    }
  }
  
  /// Import identity from nsec (bech32 private key)
  Future<AuthResult> importFromNsec(String nsec, {String? biometricPrompt}) async {
    Log.debug('Importing identity from nsec to secure storage', name: 'AuthService', category: LogCategory.auth);
    
    _setAuthState(AuthState.authenticating);
    _lastError = null;
    
    try {
      // Validate nsec format
      if (!NostrEncoding.isValidNsec(nsec)) {
        throw Exception('Invalid nsec format');
      }
      
      // Import keys into secure storage
      final keyContainer = await _keyStorage.importFromNsec(
        nsec,
        biometricPrompt: biometricPrompt,
      );
      
      // Set up user session
      await _setupUserSession(keyContainer);
      
      Log.info('Identity imported to secure storage successfully', name: 'AuthService', category: LogCategory.auth);
      Log.debug('� Public key: ${NostrEncoding.maskKey(keyContainer.npub)}', name: 'AuthService', category: LogCategory.auth);
      
      return AuthResult.success(keyContainer);
      
    } catch (e) {
      Log.error('Failed to import identity: $e', name: 'AuthService', category: LogCategory.auth);
      _lastError = 'Failed to import identity: $e';
      _setAuthState(AuthState.unauthenticated);
      
      return AuthResult.failure(_lastError!);
    }
  }
  
  /// Import identity from hex private key
  Future<AuthResult> importFromHex(String privateKeyHex, {String? biometricPrompt}) async {
    Log.debug('Importing identity from hex to secure storage', name: 'AuthService', category: LogCategory.auth);
    
    _setAuthState(AuthState.authenticating);
    _lastError = null;
    
    try {
      // Validate hex format
      if (!NostrEncoding.isValidHexKey(privateKeyHex)) {
        throw Exception('Invalid private key format');
      }
      
      // Import keys into secure storage
      final keyContainer = await _keyStorage.importFromHex(
        privateKeyHex,
        biometricPrompt: biometricPrompt,
      );
      
      // Set up user session
      await _setupUserSession(keyContainer);
      
      Log.info('Identity imported from hex to secure storage successfully', name: 'AuthService', category: LogCategory.auth);
      Log.debug('� Public key: ${NostrEncoding.maskKey(keyContainer.npub)}', name: 'AuthService', category: LogCategory.auth);
      
      return AuthResult.success(keyContainer);
      
    } catch (e) {
      Log.error('Failed to import from hex: $e', name: 'AuthService', category: LogCategory.auth);
      _lastError = 'Failed to import from hex: $e';
      _setAuthState(AuthState.unauthenticated);
      
      return AuthResult.failure(_lastError!);
    }
  }
  
  /// Refresh the current user's profile from UserProfileService
  Future<void> refreshCurrentProfile(ups.UserProfileService userProfileService) async {
    if (_currentKeyContainer == null) return;
    
    Log.debug('🔄 Refreshing current user profile from UserProfileService', name: 'AuthService', category: LogCategory.auth);
    
    // Get the latest profile from UserProfileService
    final cachedProfile = userProfileService.getCachedProfile(_currentKeyContainer!.publicKeyHex);
    
    if (cachedProfile != null) {
      Log.info('📋 Found updated profile:', name: 'AuthService', category: LogCategory.auth);
      Log.info('  - name: ${cachedProfile.name}', name: 'AuthService', category: LogCategory.auth);
      Log.info('  - displayName: ${cachedProfile.displayName}', name: 'AuthService', category: LogCategory.auth);
      Log.info('  - about: ${cachedProfile.about}', name: 'AuthService', category: LogCategory.auth);
      
      // Update the AuthService profile with data from UserProfileService
      _currentProfile = UserProfile(
        npub: _currentKeyContainer!.npub,
        publicKeyHex: _currentKeyContainer!.publicKeyHex,
        displayName: cachedProfile.displayName ?? cachedProfile.name ?? NostrEncoding.maskKey(_currentKeyContainer!.npub),
        about: cachedProfile.about,
        picture: cachedProfile.picture,
        nip05: cachedProfile.nip05,
      );
      
      // Notify listeners and stream
      _profileController.add(_currentProfile);
      notifyListeners();
      
      Log.info('✅ AuthService profile updated', name: 'AuthService', category: LogCategory.auth);
    } else {
      Log.warning('⚠️ No cached profile found in UserProfileService', name: 'AuthService', category: LogCategory.auth);
    }
  }
  
  /// Sign out the current user
  Future<void> signOut({bool deleteKeys = false}) async {
    Log.debug('� Signing out user', name: 'AuthService', category: LogCategory.auth);
    
    try {
      if (deleteKeys) {
        Log.debug('�️ Deleting stored keys', name: 'AuthService', category: LogCategory.auth);
        await _keyStorage.deleteKeys();
      } else {
        // Just clear cache
        _keyStorage.clearCache();
      }
      
      // Clear session
      _currentKeyContainer?.dispose();
      _currentKeyContainer = null;
      _currentProfile = null;
      _lastError = null;
      
      _setAuthState(AuthState.unauthenticated);
      
      Log.info('User signed out', name: 'AuthService', category: LogCategory.auth);
      
    } catch (e) {
      Log.error('Error during sign out: $e', name: 'AuthService', category: LogCategory.auth);
      _lastError = 'Sign out failed: $e';
    }
  }
  
  /// Get the private key for signing operations
  Future<String?> getPrivateKeyForSigning({String? biometricPrompt}) async {
    if (!isAuthenticated) return null;
    
    try {
      return await _keyStorage.withPrivateKey<String?>(
        (privateKeyHex) => privateKeyHex,
        biometricPrompt: biometricPrompt,
      );
    } catch (e) {
      Log.error('Failed to get private key: $e', name: 'AuthService', category: LogCategory.auth);
      return null;
    }
  }
  
  /// Export nsec for backup purposes
  Future<String?> exportNsec({String? biometricPrompt}) async {
    if (!isAuthenticated) return null;
    
    try {
      Log.warning('Exporting nsec - ensure secure handling', name: 'AuthService', category: LogCategory.auth);
      return await _keyStorage.exportNsec(biometricPrompt: biometricPrompt);
    } catch (e) {
      Log.error('Failed to export nsec: $e', name: 'AuthService', category: LogCategory.auth);
      return null;
    }
  }
  
  /// Create and sign a Nostr event
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    String? biometricPrompt,
  }) async {
    if (!isAuthenticated || _currentKeyContainer == null) {
      Log.error('Cannot sign event - user not authenticated', name: 'AuthService', category: LogCategory.auth);
      return null;
    }
    
    try {
      return await _keyStorage.withPrivateKey<Event?>((privateKey) {
        // Create event with current user's public key
        // Use appropriate timestamp backdating based on event kind
        final driftTolerance = NostrTimestamp.getDriftToleranceForKind(kind);
        
        // CRITICAL: vine.hol.is relay requires specific tags for storage
        final eventTags = List<List<String>>.from(tags ?? []);
        
        // CRITICAL: Kind 0 events require expiration tag FIRST (matching Python script order)
        if (kind == 0) {
          final expirationTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + (72 * 60 * 60); // 72 hours
          eventTags.add(['expiration', expirationTimestamp.toString()]);
        }
        
        eventTags.add(['h', 'vine']); // Required by vine.hol.is relay
        
        final event = Event(
          _currentKeyContainer!.publicKeyHex,
          kind,
          eventTags,
          content,
          createdAt: NostrTimestamp.now(driftTolerance: driftTolerance),
        );
        
        // DEBUG: Log event details before signing
        Log.info('🔍 Event BEFORE signing:', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - ID: ${event.id}', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - Pubkey: ${event.pubkey}', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - Kind: ${event.kind}', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - Created at: ${event.createdAt}', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - Tags: ${event.tags}', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - Content: ${event.content}', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - Signature (before): ${event.sig}', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - Is valid (before): ${event.isValid}', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - Is signed (before): ${event.isSigned}', name: 'AuthService', category: LogCategory.auth);
        
        // CRITICAL DEBUG: Log the exact JSON array used for ID calculation
        final idCalculationArray = [0, event.pubkey, event.createdAt, event.kind, event.tags, event.content];
        final idCalculationJson = jsonEncode(idCalculationArray);
        Log.info('📊 CRITICAL: ID calculation JSON array:', name: 'AuthService', category: LogCategory.auth);
        Log.info('   Raw Array: $idCalculationArray', name: 'AuthService', category: LogCategory.auth);
        Log.info('   JSON: $idCalculationJson', name: 'AuthService', category: LogCategory.auth);
        Log.info('   JSON Length: ${idCalculationJson.length} chars', name: 'AuthService', category: LogCategory.auth);
        
        // Sign the event
        event.sign(privateKey);
        
        // DEBUG: Log event details after signing
        Log.info('🔍 Event AFTER signing:', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - ID (should be same): ${event.id}', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - Signature (after): ${event.sig}', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - Is valid (after): ${event.isValid}', name: 'AuthService', category: LogCategory.auth);
        Log.info('  - Is signed (after): ${event.isSigned}', name: 'AuthService', category: LogCategory.auth);
        
        // CRITICAL: Verify signature is actually valid
        if (!event.isSigned) {
          Log.error('❌ Event signature validation FAILED!', name: 'AuthService', category: LogCategory.auth);
          Log.error('   This would cause relay to accept but not store the event', name: 'AuthService', category: LogCategory.auth);
          return null;
        }
        
        if (!event.isValid) {
          Log.error('❌ Event structure validation FAILED!', name: 'AuthService', category: LogCategory.auth);
          Log.error('   Event ID does not match computed hash', name: 'AuthService', category: LogCategory.auth);
          return null;
        }
        
        Log.info('✅ Event signature and structure validation PASSED', name: 'AuthService', category: LogCategory.auth);
        
        return event;
      }, biometricPrompt: biometricPrompt);
      
    } catch (e) {
      Log.error('Failed to create event: $e', name: 'AuthService', category: LogCategory.auth);
      return null;
    }
  }
  
  /// Check for existing authentication
  Future<void> _checkExistingAuth() async {
    try {
      final hasKeys = await _keyStorage.hasKeys();
      
      if (hasKeys) {
        Log.info('Found existing secure keys, loading saved identity...', name: 'AuthService', category: LogCategory.auth);
        
        final keyContainer = await _keyStorage.getKeyContainer();
        if (keyContainer != null) {
          Log.info('Loaded existing secure identity: ${NostrEncoding.maskKey(keyContainer.npub)}', name: 'AuthService', category: LogCategory.auth);
          await _setupUserSession(keyContainer);
          return;
        } else {
          Log.warning('Has keys flag set but could not load secure key container', name: 'AuthService', category: LogCategory.auth);
        }
      }
      
      Log.info('No existing secure keys found, creating new identity automatically...', name: 'AuthService', category: LogCategory.auth);
      
      // Auto-create identity like TikTok - seamless onboarding
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setAuthState(AuthState.authenticating);
      });
      
      final result = await createNewIdentity();
      if (result.success && result.keyContainer != null) {
        Log.info('Auto-created NEW secure Nostr identity: ${NostrEncoding.maskKey(result.keyContainer!.npub)}', name: 'AuthService', category: LogCategory.auth);
        Log.debug('� This identity is now securely saved and will be reused on next launch', name: 'AuthService', category: LogCategory.auth);
      } else {
        Log.error('Failed to auto-create identity: ${result.errorMessage}', name: 'AuthService', category: LogCategory.auth);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setAuthState(AuthState.unauthenticated);
        });
      }
      
    } catch (e) {
      Log.error('Error checking existing auth: $e', name: 'AuthService', category: LogCategory.auth);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setAuthState(AuthState.unauthenticated);
      });
    }
  }
  
  /// Set up user session after successful authentication
  Future<void> _setupUserSession(SecureKeyContainer keyContainer) async {
    _currentKeyContainer = keyContainer;
    
    // Create user profile from secure container
    _currentProfile = UserProfile(
      npub: keyContainer.npub,
      publicKeyHex: keyContainer.publicKeyHex,
      displayName: NostrEncoding.maskKey(keyContainer.npub),
    );
    
    // TODO: Add secure metadata tracking for timestamps
    // final createdAt = await _keyStorage.getKeyCreationTime();
    // final lastAccess = await _keyStorage.getLastAccessTime();
    
    _setAuthState(AuthState.authenticated);
    _profileController.add(_currentProfile);
    
    Log.info('Secure user session established', name: 'AuthService', category: LogCategory.auth);
    Log.verbose('Profile: ${_currentProfile!.displayName}', name: 'AuthService', category: LogCategory.auth);
    Log.debug('� Security: Hardware-backed storage active', name: 'AuthService', category: LogCategory.auth);
  }
  
  /// Check if migration from legacy storage is needed
  Future<void> _checkMigrationStatus() async {
    try {
      final migrationStatus = await _migrationService.checkMigrationStatus();
      
      _migrationRequired = migrationStatus.status == MigrationStatus.pending;
      
      if (_migrationRequired) {
        Log.warning('Legacy keys found - migration required for security', name: 'AuthService', category: LogCategory.auth);
      } else if (migrationStatus.status == MigrationStatus.failed) {
        Log.error('Migration check failed: ${migrationStatus.error}', name: 'AuthService', category: LogCategory.auth);
      }
    } catch (e) {
      Log.error('Migration status check failed: $e', name: 'AuthService', category: LogCategory.auth);
      _migrationRequired = false;
    }
  }
  
  /// Web authentication is not supported with secure storage
  /// Use mobile platforms for secure key management
  @Deprecated('Web authentication not supported in secure mode')
  Future<void> setWebAuthenticationKey(String publicKeyHex) async {
    Log.error('Web authentication not supported with secure storage', name: 'AuthService', category: LogCategory.auth);
    
    _lastError = 'Web authentication not supported in secure mode. Please use mobile app for secure key management.';
    _setAuthState(AuthState.unauthenticated);
    
    throw const SecureKeyStorageException(
      'Web platform not supported for secure key storage',
      code: 'web_not_supported',
    );
  }

  /// Update authentication state and notify listeners
  void _setAuthState(AuthState newState) {
    if (_authState != newState) {
      _authState = newState;
      _authStateController.add(newState);
      notifyListeners();
      
      Log.debug('Auth state changed: ${newState.name}', name: 'AuthService', category: LogCategory.auth);
    }
  }
  
  /// Get user statistics
  Map<String, dynamic> get userStats {
    return {
      'is_authenticated': isAuthenticated,
      'auth_state': authState.name,
      'npub': currentNpub != null ? NostrEncoding.maskKey(currentNpub!) : null,
      'key_created_at': _currentProfile?.keyCreatedAt?.toIso8601String(),
      'last_access_at': _currentProfile?.lastAccessAt?.toIso8601String(),
      'has_error': _lastError != null,
      'last_error': _lastError,
    };
  }
  

  @override
  void dispose() {
    Log.debug('�️ Disposing SecureAuthService', name: 'AuthService', category: LogCategory.auth);
    
    // Securely dispose of key container
    _currentKeyContainer?.dispose();
    _currentKeyContainer = null;
    
    _authStateController.close();
    _profileController.close();
    _keyStorage.dispose();
    
    super.dispose();
  }
}