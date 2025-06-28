// ABOUTME: Authentication service managing user login, key generation, and auth state
// ABOUTME: Handles Nostr identity creation, import, and session management with secure storage

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:nostr_sdk/event.dart';
import 'secure_key_storage_service.dart';
import 'key_migration_service.dart';
import '../utils/secure_key_container.dart';
import '../utils/nostr_encoding.dart';

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
    
    debugPrint('🔄 Performing key migration to secure storage');
    
    try {
      final result = await _migrationService.performMigration(
        biometricPrompt: biometricPrompt,
        deleteAfterMigration: true,
      );
      
      if (result.isSuccess) {
        _migrationRequired = false;
        debugPrint('✅ Migration completed successfully');
        
        // Re-check auth after migration
        await _checkExistingAuth();
        return true;
      } else {
        debugPrint('❌ Migration failed: ${result.error}');
        _lastError = 'Migration failed: ${result.error}';
        return false;
      }
    } catch (e) {
      debugPrint('❌ Migration error: $e');
      _lastError = 'Migration error: $e';
      return false;
    }
  }
  
  /// Initialize the authentication service
  Future<void> initialize() async {
    debugPrint('🔐 Initializing SecureAuthService');
    
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
      
      debugPrint('✅ SecureAuthService initialized');
      
    } catch (e) {
      debugPrint('❌ SecureAuthService initialization failed: $e');
      _lastError = 'Failed to initialize auth: $e';
      
      // Defer state change to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setAuthState(AuthState.unauthenticated);
      });
    }
  }
  
  /// Create a new Nostr identity
  Future<AuthResult> createNewIdentity({String? biometricPrompt}) async {
    debugPrint('🆕 Creating new secure Nostr identity');
    
    _setAuthState(AuthState.authenticating);
    _lastError = null;
    
    try {
      // Generate new secure key container
      final keyContainer = await _keyStorage.generateAndStoreKeys(
        biometricPrompt: biometricPrompt,
      );
      
      // Set up user session
      await _setupUserSession(keyContainer);
      
      debugPrint('✅ New secure identity created successfully');
      debugPrint('🔑 Public key: ${NostrEncoding.maskKey(keyContainer.npub)}');
      
      return AuthResult.success(keyContainer);
      
    } catch (e) {
      debugPrint('❌ Failed to create secure identity: $e');
      _lastError = 'Failed to create identity: $e';
      _setAuthState(AuthState.unauthenticated);
      
      return AuthResult.failure(_lastError!);
    }
  }
  
  /// Import identity from nsec (bech32 private key)
  Future<AuthResult> importFromNsec(String nsec, {String? biometricPrompt}) async {
    debugPrint('📥 Importing identity from nsec to secure storage');
    
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
      
      debugPrint('✅ Identity imported to secure storage successfully');
      debugPrint('🔑 Public key: ${NostrEncoding.maskKey(keyContainer.npub)}');
      
      return AuthResult.success(keyContainer);
      
    } catch (e) {
      debugPrint('❌ Failed to import identity: $e');
      _lastError = 'Failed to import identity: $e';
      _setAuthState(AuthState.unauthenticated);
      
      return AuthResult.failure(_lastError!);
    }
  }
  
  /// Import identity from hex private key
  Future<AuthResult> importFromHex(String privateKeyHex, {String? biometricPrompt}) async {
    debugPrint('📥 Importing identity from hex to secure storage');
    
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
      
      debugPrint('✅ Identity imported from hex to secure storage successfully');
      debugPrint('🔑 Public key: ${NostrEncoding.maskKey(keyContainer.npub)}');
      
      return AuthResult.success(keyContainer);
      
    } catch (e) {
      debugPrint('❌ Failed to import from hex: $e');
      _lastError = 'Failed to import from hex: $e';
      _setAuthState(AuthState.unauthenticated);
      
      return AuthResult.failure(_lastError!);
    }
  }
  
  /// Sign out the current user
  Future<void> signOut({bool deleteKeys = false}) async {
    debugPrint('👋 Signing out user');
    
    try {
      if (deleteKeys) {
        debugPrint('🗑️ Deleting stored keys');
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
      
      debugPrint('✅ User signed out');
      
    } catch (e) {
      debugPrint('❌ Error during sign out: $e');
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
      debugPrint('❌ Failed to get private key: $e');
      return null;
    }
  }
  
  /// Export nsec for backup purposes
  Future<String?> exportNsec({String? biometricPrompt}) async {
    if (!isAuthenticated) return null;
    
    try {
      debugPrint('⚠️ Exporting nsec - ensure secure handling');
      return await _keyStorage.exportNsec(biometricPrompt: biometricPrompt);
    } catch (e) {
      debugPrint('❌ Failed to export nsec: $e');
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
      debugPrint('❌ Cannot sign event - user not authenticated');
      return null;
    }
    
    try {
      return await _keyStorage.withPrivateKey<Event?>((privateKey) {
        // Create event with current user's public key
        final event = Event(
          _currentKeyContainer!.publicKeyHex,
          kind,
          tags ?? [],
          content,
        );
        
        // Sign the event
        event.sign(privateKey);
        
        return event;
      }, biometricPrompt: biometricPrompt);
      
    } catch (e) {
      debugPrint('❌ Failed to create event: $e');
      return null;
    }
  }
  
  /// Check for existing authentication
  Future<void> _checkExistingAuth() async {
    try {
      final hasKeys = await _keyStorage.hasKeys();
      
      if (hasKeys) {
        debugPrint('🔍 Found existing secure keys, loading saved identity...');
        
        final keyContainer = await _keyStorage.getKeyContainer();
        if (keyContainer != null) {
          debugPrint('✅ Loaded existing secure identity: ${NostrEncoding.maskKey(keyContainer.npub)}');
          await _setupUserSession(keyContainer);
          return;
        } else {
          debugPrint('⚠️ Has keys flag set but could not load secure key container');
        }
      }
      
      debugPrint('📭 No existing secure keys found, creating new identity automatically...');
      
      // Auto-create identity like TikTok - seamless onboarding
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setAuthState(AuthState.authenticating);
      });
      
      final result = await createNewIdentity();
      if (result.success && result.keyContainer != null) {
        debugPrint('✅ Auto-created NEW secure Nostr identity: ${NostrEncoding.maskKey(result.keyContainer!.npub)}');
        debugPrint('🔐 This identity is now securely saved and will be reused on next launch');
      } else {
        debugPrint('❌ Failed to auto-create identity: ${result.errorMessage}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setAuthState(AuthState.unauthenticated);
        });
      }
      
    } catch (e) {
      debugPrint('❌ Error checking existing auth: $e');
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
    
    debugPrint('✅ Secure user session established');
    debugPrint('👤 Profile: ${_currentProfile!.displayName}');
    debugPrint('🔒 Security: Hardware-backed storage active');
  }
  
  /// Check if migration from legacy storage is needed
  Future<void> _checkMigrationStatus() async {
    try {
      final migrationStatus = await _migrationService.checkMigrationStatus();
      
      _migrationRequired = migrationStatus.status == MigrationStatus.pending;
      
      if (_migrationRequired) {
        debugPrint('⚠️ Legacy keys found - migration required for security');
      } else if (migrationStatus.status == MigrationStatus.failed) {
        debugPrint('❌ Migration check failed: ${migrationStatus.error}');
      }
    } catch (e) {
      debugPrint('⚠️ Migration status check failed: $e');
      _migrationRequired = false;
    }
  }
  
  /// Web authentication is not supported with secure storage
  /// Use mobile platforms for secure key management
  @Deprecated('Web authentication not supported in secure mode')
  Future<void> setWebAuthenticationKey(String publicKeyHex) async {
    debugPrint('❌ Web authentication not supported with secure storage');
    
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
      
      debugPrint('🔄 Auth state changed: ${newState.name}');
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
    debugPrint('🗑️ Disposing SecureAuthService');
    
    // Securely dispose of key container
    _currentKeyContainer?.dispose();
    _currentKeyContainer = null;
    
    _authStateController.close();
    _profileController.close();
    _keyStorage.dispose();
    
    super.dispose();
  }
}