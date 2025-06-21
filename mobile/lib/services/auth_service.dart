// ABOUTME: Authentication service managing user login, key generation, and auth state
// ABOUTME: Handles Nostr identity creation, import, and session management with secure storage

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:nostr/nostr.dart';
import 'key_storage_service.dart';
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
  final NostrKeyPair? keyPair;
  
  const AuthResult({
    required this.success,
    this.errorMessage,
    this.keyPair,
  });
  
  factory AuthResult.success(NostrKeyPair keyPair) {
    return AuthResult(success: true, keyPair: keyPair);
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
  
  const UserProfile({
    required this.npub,
    required this.publicKeyHex,
    this.keyCreatedAt,
    this.lastAccessAt,
    required this.displayName,
    this.about,
    this.picture,
  });
  
  /// Create minimal profile from key pair
  factory UserProfile.fromKeyPair(NostrKeyPair keyPair) {
    return UserProfile(
      npub: keyPair.npub,
      publicKeyHex: keyPair.publicKeyHex,
      displayName: NostrEncoding.maskKey(keyPair.npub),
    );
  }
}

/// Main authentication service for the NostrVine app
class AuthService extends ChangeNotifier {
  final KeyStorageService _keyStorage;
  
  AuthState _authState = AuthState.checking;
  NostrKeyPair? _currentKeyPair;
  UserProfile? _currentProfile;
  String? _lastError;
  
  // Streaming controllers for reactive auth state
  final StreamController<AuthState> _authStateController = 
      StreamController<AuthState>.broadcast();
  final StreamController<UserProfile?> _profileController = 
      StreamController<UserProfile?>.broadcast();
      
  AuthService({KeyStorageService? keyStorage}) 
      : _keyStorage = keyStorage ?? KeyStorageService();
  
  /// Current authentication state
  AuthState get authState => _authState;
  
  /// Stream of authentication state changes
  Stream<AuthState> get authStateStream => _authStateController.stream;
  
  /// Current user profile (null if not authenticated)
  UserProfile? get currentProfile => _currentProfile;
  
  /// Stream of profile changes
  Stream<UserProfile?> get profileStream => _profileController.stream;
  
  /// Current public key (npub format)
  String? get currentNpub => _currentKeyPair?.npub;
  
  /// Current public key (hex format)
  String? get currentPublicKeyHex => _currentKeyPair?.publicKeyHex;
  
  /// Check if user is authenticated
  bool get isAuthenticated => _authState == AuthState.authenticated;
  
  /// Last authentication error
  String? get lastError => _lastError;
  
  /// Initialize the authentication service
  Future<void> initialize() async {
    debugPrint('🔐 Initializing AuthService');
    
    // Defer state changes to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setAuthState(AuthState.checking);
    });
    
    try {
      // Initialize key storage
      await _keyStorage.initialize();
      
      // Check for existing keys
      await _checkExistingAuth();
      
      debugPrint('✅ AuthService initialized');
      
    } catch (e) {
      debugPrint('❌ AuthService initialization failed: $e');
      _lastError = 'Failed to initialize auth: $e';
      
      // Defer state change to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setAuthState(AuthState.unauthenticated);
      });
    }
  }
  
  /// Create a new Nostr identity
  Future<AuthResult> createNewIdentity() async {
    debugPrint('🆕 Creating new Nostr identity');
    
    _setAuthState(AuthState.authenticating);
    _lastError = null;
    
    try {
      // Generate new key pair
      final keyPair = await _keyStorage.generateAndStoreKeys();
      
      // Set up user session
      await _setupUserSession(keyPair);
      
      debugPrint('✅ New identity created successfully');
      debugPrint('🔑 Public key: ${NostrEncoding.maskKey(keyPair.npub)}');
      
      return AuthResult.success(keyPair);
      
    } catch (e) {
      debugPrint('❌ Failed to create identity: $e');
      _lastError = 'Failed to create identity: $e';
      _setAuthState(AuthState.unauthenticated);
      
      return AuthResult.failure(_lastError!);
    }
  }
  
  /// Import identity from nsec (bech32 private key)
  Future<AuthResult> importFromNsec(String nsec) async {
    debugPrint('📥 Importing identity from nsec');
    
    _setAuthState(AuthState.authenticating);
    _lastError = null;
    
    try {
      // Validate nsec format
      if (!NostrEncoding.isValidNsec(nsec)) {
        throw Exception('Invalid nsec format');
      }
      
      // Import keys
      final keyPair = await _keyStorage.importFromNsec(nsec);
      
      // Set up user session
      await _setupUserSession(keyPair);
      
      debugPrint('✅ Identity imported successfully');
      debugPrint('🔑 Public key: ${NostrEncoding.maskKey(keyPair.npub)}');
      
      return AuthResult.success(keyPair);
      
    } catch (e) {
      debugPrint('❌ Failed to import identity: $e');
      _lastError = 'Failed to import identity: $e';
      _setAuthState(AuthState.unauthenticated);
      
      return AuthResult.failure(_lastError!);
    }
  }
  
  /// Import identity from hex private key
  Future<AuthResult> importFromHex(String privateKeyHex) async {
    debugPrint('📥 Importing identity from hex');
    
    _setAuthState(AuthState.authenticating);
    _lastError = null;
    
    try {
      // Validate hex format
      if (!NostrEncoding.isValidHexKey(privateKeyHex)) {
        throw Exception('Invalid private key format');
      }
      
      // Import keys
      final keyPair = await _keyStorage.importFromHex(privateKeyHex);
      
      // Set up user session
      await _setupUserSession(keyPair);
      
      debugPrint('✅ Identity imported successfully');
      debugPrint('🔑 Public key: ${NostrEncoding.maskKey(keyPair.npub)}');
      
      return AuthResult.success(keyPair);
      
    } catch (e) {
      debugPrint('❌ Failed to import identity: $e');
      _lastError = 'Failed to import identity: $e';
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
      _currentKeyPair = null;
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
  Future<String?> getPrivateKeyForSigning() async {
    if (!isAuthenticated) return null;
    
    try {
      return await _keyStorage.getPrivateKeyForSigning();
    } catch (e) {
      debugPrint('❌ Failed to get private key: $e');
      return null;
    }
  }
  
  /// Export nsec for backup purposes
  Future<String?> exportNsec() async {
    if (!isAuthenticated) return null;
    
    try {
      debugPrint('⚠️ Exporting nsec - ensure secure handling');
      return await _keyStorage.exportNsec();
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
  }) async {
    if (!isAuthenticated) {
      debugPrint('❌ Cannot sign event - user not authenticated');
      return null;
    }
    
    try {
      final privateKey = await getPrivateKeyForSigning();
      if (privateKey == null) return null;
      
      final event = Event.from(
        kind: kind,
        content: content,
        tags: tags ?? [],
        privkey: privateKey,
      );
      
      debugPrint('✏️ Created and signed event: ${event.id}');
      return event;
      
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
        debugPrint('🔍 Found existing keys, loading session');
        
        final keyPair = await _keyStorage.getKeyPair();
        if (keyPair != null) {
          await _setupUserSession(keyPair);
          return;
        }
      }
      
      debugPrint('📭 No existing authentication found, creating new identity automatically');
      
      // Auto-create identity like TikTok - seamless onboarding
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setAuthState(AuthState.authenticating);
      });
      
      final result = await createNewIdentity();
      if (result.success) {
        debugPrint('✅ Auto-created new Nostr identity for seamless onboarding');
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
  Future<void> _setupUserSession(NostrKeyPair keyPair) async {
    _currentKeyPair = keyPair;
    
    // Create user profile
    _currentProfile = UserProfile.fromKeyPair(keyPair);
    
    // Add timestamps if available
    final createdAt = await _keyStorage.getKeyCreationTime();
    final lastAccess = await _keyStorage.getLastAccessTime();
    
    if (createdAt != null || lastAccess != null) {
      _currentProfile = UserProfile(
        npub: _currentProfile!.npub,
        publicKeyHex: _currentProfile!.publicKeyHex,
        keyCreatedAt: createdAt,
        lastAccessAt: lastAccess,
        displayName: _currentProfile!.displayName,
        about: _currentProfile!.about,
        picture: _currentProfile!.picture,
      );
    }
    
    _setAuthState(AuthState.authenticated);
    _profileController.add(_currentProfile);
    
    debugPrint('✅ User session established');
    debugPrint('👤 Profile: ${_currentProfile!.displayName}');
  }
  
  /// Set web authentication key (for NIP-07 and bunker authentication)
  Future<void> setWebAuthenticationKey(String publicKeyHex) async {
    debugPrint('🌐 Setting web authentication key');
    
    _setAuthState(AuthState.authenticating);
    _lastError = null;
    
    try {
      // Validate hex format
      if (!NostrEncoding.isValidHexKey(publicKeyHex)) {
        throw Exception('Invalid public key format');
      }
      
      // Create a NostrKeyPair with only the public key (no private key for web auth)
      final npub = NostrEncoding.encodePublicKey(publicKeyHex);
      final keyPair = NostrKeyPair(
        privateKeyHex: '', // Empty for web auth - signing handled by external services
        publicKeyHex: publicKeyHex,
        npub: npub,
        nsec: '', // Empty for web auth
      );
      
      // Set up user session without storing keys (web auth is session-only)
      await _setupWebUserSession(keyPair);
      
      debugPrint('✅ Web authentication key set successfully');
      debugPrint('🔑 Public key: ${NostrEncoding.maskKey(npub)}');
      
    } catch (e) {
      debugPrint('❌ Failed to set web authentication key: $e');
      _lastError = 'Failed to set web authentication: $e';
      _setAuthState(AuthState.unauthenticated);
      rethrow;
    }
  }
  
  /// Set up user session for web authentication (no key storage)
  Future<void> _setupWebUserSession(NostrKeyPair keyPair) async {
    _currentKeyPair = keyPair;
    
    // Create user profile
    _currentProfile = UserProfile.fromKeyPair(keyPair);
    
    // Mark as authenticated
    _setAuthState(AuthState.authenticated);
    _profileController.add(_currentProfile);
    
    debugPrint('✅ Web user session established');
    debugPrint('👤 Profile: ${_currentProfile!.displayName}');
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
    debugPrint('🗑️ Disposing AuthService');
    
    _authStateController.close();
    _profileController.close();
    _keyStorage.dispose();
    
    super.dispose();
  }
}