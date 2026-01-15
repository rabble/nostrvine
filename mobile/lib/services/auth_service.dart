// ABOUTME: Authentication service managing user login, key generation, and
// auth state
// ABOUTME: Handles Nostr identity creation, import, and session management
// with secure storage

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer, SecureKeyStorage;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/services/user_profile_service.dart' as ups;
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/nostr_timestamp.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Key for persisted authentication source
const _kAuthSourceKey = 'authentication_source';

// Keys for bunker connection persistence
const _kBunkerInfoKey = 'bunker_info';

/// Source of authentication used to restore session at startup
enum AuthenticationSource {
  none('none'),
  divineOAuth('divineOAuth'),
  importedKeys('imported_keys'),
  automatic('automatic'),
  bunker('bunker');

  const AuthenticationSource(this.code);

  final String code;

  static AuthenticationSource fromCode(String? code) {
    return AuthenticationSource.values
            .where((s) => s.code == code)
            .firstOrNull ??
        AuthenticationSource.none;
  }
}

/// Authentication state for the user
enum AuthState {
  /// User is not authenticated (no keys stored)
  unauthenticated,

  /// User has keys but hasn't accepted Terms of Service yet
  awaitingTosAcceptance,

  /// User is authenticated (has valid keys and accepted TOS)
  authenticated,

  /// Authentication state is being checked
  checking,

  /// Authentication is in progress (generating/importing keys)
  authenticating,
}

/// Result of authentication operations
class AuthResult {
  const AuthResult({
    required this.success,
    this.errorMessage,
    this.keyContainer,
  });

  factory AuthResult.success(SecureKeyContainer keyContainer) =>
      AuthResult(success: true, keyContainer: keyContainer);

  factory AuthResult.failure(String errorMessage) =>
      AuthResult(success: false, errorMessage: errorMessage);

  final bool success;
  final String? errorMessage;
  final SecureKeyContainer? keyContainer;
}

/// User profile information
class UserProfile {
  const UserProfile({
    required this.npub,
    required this.publicKeyHex,
    required this.displayName,
    this.keyCreatedAt,
    this.lastAccessAt,
    this.about,
    this.picture,
    this.nip05,
  });

  /// Create minimal profile from secure key container
  factory UserProfile.fromSecureContainer(SecureKeyContainer keyContainer) =>
      UserProfile(
        npub: keyContainer.npub,
        publicKeyHex: keyContainer.publicKeyHex,
        displayName: NostrKeyUtils.maskKey(keyContainer.npub),
      );

  final String npub;
  final String publicKeyHex;
  final DateTime? keyCreatedAt;
  final DateTime? lastAccessAt;
  final String displayName;
  final String? about;
  final String? picture;
  final String? nip05;
}

/// Main authentication service for the divine app
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via
/// Riverpod
class AuthService {
  AuthService({
    required UserDataCleanupService userDataCleanupService,
    SecureKeyStorage? keyStorage,
    KeycastOAuth? oauthClient,
    FlutterSecureStorage? flutterSecureStorage,
    OAuthConfig? oauthConfig,
  }) : _keyStorage = keyStorage ?? SecureKeyStorage(),
       _userDataCleanupService = userDataCleanupService,
       _oauthClient = oauthClient,
       _flutterSecureStorage = flutterSecureStorage,
       _oauthConfig =
           oauthConfig ??
           const OAuthConfig(serverUrl: '', clientId: '', redirectUri: '');
  final SecureKeyStorage _keyStorage;
  final UserDataCleanupService _userDataCleanupService;
  final KeycastOAuth? _oauthClient;
  final FlutterSecureStorage? _flutterSecureStorage;

  AuthState _authState = AuthState.checking;
  SecureKeyContainer? _currentKeyContainer;
  UserProfile? _currentProfile;
  String? _lastError;
  KeycastRpc? _keycastSigner;

  // NIP-46 bunker signer state
  NostrRemoteSigner? _bunkerSigner;

  /// Returns the active remote signer (bunker takes priority over OAuth RPC)
  NostrSigner? get rpcSigner => _bunkerSigner ?? _keycastSigner;
  final OAuthConfig _oauthConfig;

  // Streaming controllers for reactive auth state
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  final StreamController<UserProfile?> _profileController =
      StreamController<UserProfile?>.broadcast();

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
  /// Works for both local keys (via keyContainer) and bunker auth (via profile)
  String? get currentPublicKeyHex =>
      _currentKeyContainer?.publicKeyHex ?? _currentProfile?.publicKeyHex;

  /// Current secure key container (null if not authenticated)
  ///
  /// Used by NostrClientProvider to create AuthServiceSigner.
  /// The container provides secure access to private key operations.
  SecureKeyContainer? get currentKeyContainer => _currentKeyContainer;

  /// Check if user is authenticated
  bool get isAuthenticated => _authState == AuthState.authenticated;

  /// Authentication source used for current session
  AuthenticationSource _authSource = AuthenticationSource.none;

  /// Get the current authentication source
  AuthenticationSource get authenticationSource => _authSource;

  /// Check if user has registered with divine (email/password)
  /// Returns true if authenticated via divine OAuth, false for anonymous/imported keys
  bool get isRegistered => _authSource == AuthenticationSource.divineOAuth;

  /// Check if user is using an anonymous auto-generated identity
  bool get isAnonymous => _authSource == AuthenticationSource.automatic;

  /// Last authentication error
  String? get lastError => _lastError;

  /// Initialize the authentication service
  Future<void> initialize() async {
    Log.debug(
      'Initializing SecureAuthService',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Set checking state immediately - we're starting the auth check now
    _setAuthState(AuthState.checking);

    try {
      // Initialize secure key storage
      await _keyStorage.initialize();

      // Decide restore path based on persisted authentication source
      final authSource = await _loadAuthSource();
      Log.info(
        'authSource: $authSource',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      switch (authSource) {
        case AuthenticationSource.none:
          // Explicit logout or fresh install — show welcome
          _setAuthState(AuthState.unauthenticated);
          return;

        case AuthenticationSource.divineOAuth:
          // Try to load authorized session from secure storage
          final session = await KeycastSession.load(_flutterSecureStorage);
          if (session != null && session.hasRpcAccess) {
            await signInWithDivineOAuth(session);
            return;
          }
          // session not restored — fall back to unauthenticated
          _setAuthState(AuthState.unauthenticated);
          return;

        case AuthenticationSource.importedKeys:
          // Only restore if secure keys exist
          final hasKeys = await _keyStorage.hasKeys();
          if (hasKeys) {
            final keyContainer = await _keyStorage.getKeyContainer();
            if (keyContainer != null) {
              await _setupUserSession(
                keyContainer,
                AuthenticationSource.importedKeys,
              );
              return;
            }
          }
          _setAuthState(AuthState.unauthenticated);
          return;

        case AuthenticationSource.automatic:
          // Default behavior: check for keys and auto-create if needed
          await _checkExistingAuth();

        case AuthenticationSource.bunker:
          // Try to restore bunker connection from secure storage
          final bunkerInfo = await _loadBunkerInfo();
          if (bunkerInfo != null) {
            await _reconnectBunker(bunkerInfo);
            return;
          }
          // Bunker info not found — fall back to unauthenticated
          _setAuthState(AuthState.unauthenticated);
          return;
      }

      Log.info(
        'SecureAuthService initialized',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'SecureAuthService initialization failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to initialize auth: $e';

      // Set state synchronously to prevent loading screen deadlock
      _setAuthState(AuthState.unauthenticated);
    }
  }

  /// Create a new Nostr identity
  Future<AuthResult> createNewIdentity({String? biometricPrompt}) async {
    Log.debug(
      '📱 Creating new secure Nostr identity',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      // Generate new secure key container
      final keyContainer = await _keyStorage.generateAndStoreKeys(
        biometricPrompt: biometricPrompt,
      );

      // Set up user session
      await _setupUserSession(keyContainer, AuthenticationSource.automatic);

      Log.info(
        'New secure identity created successfully',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.debug(
        '📱 Public key: ${NostrKeyUtils.maskKey(keyContainer.npub)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return AuthResult.success(keyContainer);
    } catch (e) {
      Log.error(
        'Failed to create secure identity: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to create identity: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  Future<AuthenticationSource> _loadAuthSource() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kAuthSourceKey);
      final authSource = AuthenticationSource.fromCode(raw);
      Log.info(
        'Loaded $_kAuthSourceKey as $authSource',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return authSource;
    } catch (e) {
      return AuthenticationSource.automatic;
    }
  }

  /// Save bunker connection info to secure storage
  Future<void> _saveBunkerInfo(NostrRemoteSignerInfo info) async {
    if (_flutterSecureStorage == null) return;
    try {
      // Serialize bunker info as bunker URL (includes all needed data)
      final bunkerUrl = info.toString();
      await _flutterSecureStorage.write(key: _kBunkerInfoKey, value: bunkerUrl);
      Log.info(
        'Saved bunker info to secure storage',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to save bunker info: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Load bunker connection info from secure storage
  Future<NostrRemoteSignerInfo?> _loadBunkerInfo() async {
    if (_flutterSecureStorage == null) return null;
    try {
      final bunkerUrl = await _flutterSecureStorage.read(key: _kBunkerInfoKey);
      if (bunkerUrl == null || bunkerUrl.isEmpty) return null;

      final info = NostrRemoteSignerInfo.parseBunkerUrl(bunkerUrl);
      if (info != null) {
        Log.info(
          'Loaded bunker info from secure storage',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
      return info;
    } catch (e) {
      Log.error(
        'Failed to load bunker info: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Clear bunker connection info from secure storage
  Future<void> _clearBunkerInfo() async {
    if (_flutterSecureStorage == null) return;
    try {
      await _flutterSecureStorage.delete(key: _kBunkerInfoKey);
      Log.info(
        'Cleared bunker info from secure storage',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to clear bunker info: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Sets up the auth URL callback for bunker operations that require user
  /// approval.
  /// This must be called after creating a NostrRemoteSigner instance.
  void _setupBunkerAuthCallback() {
    if (_bunkerSigner == null) return;

    _bunkerSigner!.onAuthUrlReceived = (authUrl) async {
      Log.info(
        'Bunker requires authentication, opening: $authUrl',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Log.error(
          'Could not launch auth URL: $authUrl',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    };
  }

  /// Reconnect to a bunker using saved connection info
  Future<void> _reconnectBunker(NostrRemoteSignerInfo info) async {
    Log.info(
      'Reconnecting to bunker...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);

    try {
      // Create and connect the remote signer
      // Don't send a new connect request - the bunker already authorized us
      // during the initial connection. We just need to reconnect to the relay.
      _bunkerSigner = NostrRemoteSigner(RelayMode.baseMode, info);
      _setupBunkerAuthCallback();
      await _bunkerSigner!.connect(sendConnectRequest: false);

      // Use saved public key if available, otherwise request it from bunker
      var userPubkey = info.userPubkey;
      if (userPubkey == null || userPubkey.isEmpty) {
        Log.info(
          'No saved userPubkey, requesting from bunker...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        userPubkey = await _bunkerSigner!.pullPubkey();
      } else {
        Log.info(
          'Using saved userPubkey: $userPubkey',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
      if (userPubkey == null || userPubkey.isEmpty) {
        throw Exception('Failed to get public key from bunker');
      }

      _currentKeyContainer = SecureKeyContainer.fromPublicKey(userPubkey);

      // Create a minimal profile for the bunker user
      final npub = NostrKeyUtils.encodePubKey(userPubkey);
      _currentProfile = UserProfile(
        npub: npub,
        publicKeyHex: userPubkey,
        displayName: NostrKeyUtils.maskKey(npub),
      );

      _authSource = AuthenticationSource.bunker;
      _setAuthState(AuthState.authenticated);
      _profileController.add(_currentProfile);

      Log.info(
        'Bunker reconnection successful for user: $userPubkey',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Bunker reconnection failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _bunkerSigner = null;
      _setAuthState(AuthState.unauthenticated);
    }
  }

  /// Import identity from nsec (bech32 private key)
  Future<AuthResult> importFromNsec(
    String nsec, {
    String? biometricPrompt,
  }) async {
    Log.debug(
      'Importing identity from nsec to secure storage',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;
    await _onTermsAccepted();

    try {
      // Validate nsec format
      if (!NostrKeyUtils.isValidNsec(nsec)) {
        throw Exception('Invalid nsec format');
      }

      // Import keys into secure storage
      final keyContainer = await _keyStorage.importFromNsec(
        nsec,
        biometricPrompt: biometricPrompt,
      );

      // Set up user session
      await _setupUserSession(keyContainer, AuthenticationSource.importedKeys);

      Log.info(
        'Identity imported to secure storage successfully',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.debug(
        '📱 Public key: ${NostrKeyUtils.maskKey(keyContainer.npub)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return AuthResult.success(keyContainer);
    } catch (e) {
      Log.error(
        'Failed to import identity: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to import identity: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Import identity from hex private key
  Future<AuthResult> importFromHex(
    String privateKeyHex, {
    String? biometricPrompt,
  }) async {
    Log.debug(
      'Importing identity from hex to secure storage',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;
    await _onTermsAccepted();

    try {
      // Validate hex format
      if (!NostrKeyUtils.isValidKey(privateKeyHex)) {
        throw Exception('Invalid private key format');
      }

      // Import keys into secure storage
      final keyContainer = await _keyStorage.importFromHex(
        privateKeyHex,
        biometricPrompt: biometricPrompt,
      );

      // Set up user session
      await _setupUserSession(keyContainer, AuthenticationSource.importedKeys);

      Log.info(
        'Identity imported from hex to secure storage successfully',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.debug(
        '📱 Public key: ${NostrKeyUtils.maskKey(keyContainer.npub)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return AuthResult.success(keyContainer);
    } catch (e) {
      Log.error(
        'Failed to import from hex: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to import from hex: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Connect using a NIP-46 bunker URL for remote signing
  ///
  /// The bunker URL format is:
  /// `bunker://<remote-signer-pubkey>?relay=<wss://relay>&secret=<optional>`
  ///
  /// This establishes a connection with a remote signer (bunker) that holds
  /// the user's private keys. All signing operations will be delegated to
  /// the bunker via Nostr relay messages.
  Future<AuthResult> connectWithBunker(String bunkerUrl) async {
    Log.info(
      'Connecting with bunker URL...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    await _onTermsAccepted();
    _lastError = null;

    try {
      // Parse the bunker URL
      final bunkerInfo = NostrRemoteSignerInfo.parseBunkerUrl(bunkerUrl);
      if (bunkerInfo == null) {
        throw Exception('Invalid bunker URL format');
      }

      const authTimeout = Duration(seconds: 120);

      Log.debug(
        'Creating NostrRemoteSigner for '
        'bunker: ${bunkerInfo.remoteSignerPubkey}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      _bunkerSigner = NostrRemoteSigner(RelayMode.baseMode, bunkerInfo);
      _setupBunkerAuthCallback();

      String? connectResult;
      try {
        Log.debug(
          'Sending connect request to bunker...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        connectResult = await _bunkerSigner!.connect().timeout(
          authTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Bunker connection timed out. If an approval page opened, '
              'please approve the connection and try again.',
            );
          },
        );
      } on TimeoutException {
        rethrow;
      }

      // Check if connect was acknowledged
      if (connectResult == null) {
        Log.warning(
          'Connect returned null - bunker may not have acknowledged',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } else {
        Log.info(
          'Connected to bunker successfully',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      // Get user's public key from the bunker
      final String? userPubkey;
      try {
        Log.debug(
          'Requesting public key from bunker...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        userPubkey = await _bunkerSigner!.pullPubkey().timeout(
          authTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Timed out waiting for public key from bunker. '
              'The remote signer may be offline or unresponsive.',
            );
          },
        );
        Log.debug(
          'pullPubkey result: $userPubkey',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } on TimeoutException {
        rethrow;
      }

      if (userPubkey == null || userPubkey.isEmpty) {
        throw Exception(
          'Failed to get public key from bunker. '
          'The remote signer did not respond with a valid key.',
        );
      }

      await _saveBunkerInfo(bunkerInfo);

      await _setupUserSession(
        SecureKeyContainer.fromPublicKey(userPubkey),
        AuthenticationSource.bunker,
      );

      Log.info(
        'Bunker connection successful for user: $userPubkey',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return const AuthResult(success: true);
    } catch (e) {
      Log.error(
        'Bunker connection failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _bunkerSigner = null;
      _lastError = 'Bunker connection failed: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Refresh the current user's profile from UserProfileService
  Future<void> refreshCurrentProfile(
    ups.UserProfileService userProfileService,
  ) async {
    if (_currentKeyContainer == null) return;

    Log.debug(
      '🔄 Refreshing current user profile from UserProfileService',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Get the latest profile from UserProfileService
    final cachedProfile = userProfileService.getCachedProfile(
      _currentKeyContainer!.publicKeyHex,
    );

    if (cachedProfile != null) {
      Log.info(
        '📋 Found updated profile:',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.info(
        '  - name: ${cachedProfile.name}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.info(
        '  - displayName: ${cachedProfile.displayName}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.info(
        '  - about: ${cachedProfile.about}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // Update the AuthService profile with data from UserProfileService
      _currentProfile = UserProfile(
        npub: _currentKeyContainer!.npub,
        publicKeyHex: _currentKeyContainer!.publicKeyHex,
        displayName:
            cachedProfile.displayName ??
            cachedProfile.name ??
            NostrKeyUtils.maskKey(_currentKeyContainer!.npub),
        about: cachedProfile.about,
        picture: cachedProfile.picture,
        nip05: cachedProfile.nip05,
      );

      // Notify listeners and stream
      _profileController.add(_currentProfile);

      Log.info(
        '✅ AuthService profile updated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } else {
      Log.warning(
        '⚠️ No cached profile found in UserProfileService',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// transitions to authenticated state w/o first creating or importing keys
  Future<void> signInAutomatically() async {
    try {
      // If not authenticated (e.g., after logout), re-initialize to load
      // existing keys
      if (_authState != AuthState.authenticated) {
        await _checkExistingAuth();
      }
      await _onTermsAccepted();

      Log.info(
        'Terms of Service accepted, user is now fully authenticated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to save TOS acceptance: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to accept terms: $e';
    }
  }

  /// Sign in using OAuth 2.0 flow
  Future<void> signInWithDivineOAuth(KeycastSession session) async {
    Log.debug(
      'Integrating OAuth session into AuthService',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    await _onTermsAccepted();
    _lastError = null;

    try {
      _keycastSigner = KeycastRpc.fromSession(_oauthConfig, session);

      final publicKeyHex = await _keycastSigner?.getPublicKey();
      if (publicKeyHex == null) {
        throw Exception('Could not retrieve public key from server');
      }

      _currentProfile = UserProfile(
        npub: NostrKeyUtils.encodePubKey(publicKeyHex),
        publicKeyHex: publicKeyHex,
        displayName: 'diVine User',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_pubkey_hex', publicKeyHex);

      Log.info(
        '✅ Divine oauth listener setting auth state to authenticated.',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _profileController.add(_currentProfile);

      final keyContainer = SecureKeyContainer.fromPublicKey(publicKeyHex);
      await _setupUserSession(keyContainer, AuthenticationSource.divineOAuth);

      Log.info(
        '✅ Divine oauth session successfully integrated for $publicKeyHex',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to integrate oauth session: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'oauth integration failed: $e';
      _setAuthState(AuthState.unauthenticated);
    }
  }

  /// Sign out the current user
  Future<void> signOut({bool deleteKeys = false}) async {
    Log.debug(
      '📱 Signing out user',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    try {
      // Clear TOS acceptance on any logout - user must re-accept when logging
      // back in
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAuthSourceKey);
      await prefs.remove('age_verified_16_plus');
      await prefs.remove('terms_accepted_at');

      // Clear user-specific cached data on explicit logout
      await _userDataCleanupService.clearUserSpecificData(
        reason: 'explicit_logout',
      );

      // Clear the stored pubkey tracking so next login is treated as new
      await prefs.remove('current_user_pubkey_hex');

      if (deleteKeys) {
        Log.debug(
          '📱️ Deleting stored keys',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        await _keyStorage.deleteKeys();
      } else {
        _keyStorage.clearCache();
      }

      // Clear session
      _currentKeyContainer?.dispose();
      _currentKeyContainer = null;
      _currentProfile = null;
      _lastError = null;

      // Clean up bunker signer if active
      if (_bunkerSigner != null) {
        _bunkerSigner!.close();
        _bunkerSigner = null;
        await _clearBunkerInfo();
      }

      try {
        if (_oauthClient != null) {
          await _oauthClient.logout();
        } else {
          await KeycastSession.clear(_flutterSecureStorage);
        }
      } catch (_) {}

      _setAuthState(AuthState.unauthenticated);

      Log.info(
        'User signed out',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Error during sign out: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
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
      Log.error(
        'Failed to get private key: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Export nsec for backup purposes
  Future<String?> exportNsec({String? biometricPrompt}) async {
    if (!isAuthenticated) return null;

    if (authenticationSource != AuthenticationSource.automatic &&
        authenticationSource != AuthenticationSource.importedKeys) {
      Log.warning(
        'Exporting nsec for $authenticationSource not supported',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }

    try {
      Log.warning(
        'Exporting nsec - ensure secure handling',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return await _keyStorage.exportNsec(biometricPrompt: biometricPrompt);
    } catch (e) {
      Log.error(
        'Failed to export nsec: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Create and sign a Nostr event
  /// Handles both local SecureKeyStorage and remote KeycastRpc signing
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    String? biometricPrompt,
  }) async {
    if (!isAuthenticated || _currentKeyContainer == null) {
      Log.error(
        'Cannot sign event - user not authenticated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }

    try {
      // 1. Prepare event metadata and tags
      // CRITICAL: divine relays require specific tags for storage
      final eventTags = List<List<String>>.from(tags ?? []);

      // CRITICAL: Kind 0 events require expiration tag FIRST (matching Python
      // script order)
      if (kind == 0) {
        final expirationTimestamp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
            (72 * 60 * 60); // 72 hours
        eventTags.add(['expiration', expirationTimestamp.toString()]);
      }

      // Create the unsigned event object
      final driftTolerance = NostrTimestamp.getDriftToleranceForKind(kind);
      final event = Event(
        _currentKeyContainer!.publicKeyHex,
        kind,
        eventTags,
        content,
        createdAt: NostrTimestamp.now(driftTolerance: driftTolerance),
      );

      // 2. Branch Signing Logic (Local vs RPC)
      Event? signedEvent;

      if (rpcSigner case final rpcSigner?) {
        Log.info('🚀 Signing via Remote RPC', name: 'AuthService');
        signedEvent = await rpcSigner.signEvent(event);
      } else {
        Log.info('🔐 Signing via Local Secure Storage', name: 'AuthService');
        signedEvent = await _keyStorage.withPrivateKey<Event?>((privateKey) {
          event.sign(privateKey);
          return event;
        }, biometricPrompt: biometricPrompt);
      }

      // 3. Post-Signing Validation and Debugging
      if (signedEvent == null) {
        Log.error(
          '❌ Signing failed: Signer returned null',
          name: 'AuthService',
        );
        return null;
      }

      // CRITICAL: Verify signature is actually valid
      if (!signedEvent.isSigned) {
        Log.error(
          '❌ Event signature validation FAILED!',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.error(
          '   This would cause relay to accept but not store the event',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return null;
      }

      if (!signedEvent.isValid) {
        Log.error(
          '❌ Event structure validation FAILED!',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.error(
          '   Event ID does not match computed hash',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return null;
      }

      Log.info(
        '✅ Event signed and validated: ${signedEvent.id}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return signedEvent;
    } catch (e) {
      Log.error(
        'Failed to create or sign event: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Check for existing authentication
  Future<void> _checkExistingAuth() async {
    try {
      final hasKeys = await _keyStorage.hasKeys();

      if (hasKeys) {
        Log.info(
          'Found existing secure keys, loading saved identity...',
          name: 'AuthService',
          category: LogCategory.auth,
        );

        final keyContainer = await _keyStorage.getKeyContainer();
        if (keyContainer != null) {
          Log.info(
            'Loaded existing secure identity: '
            '${NostrKeyUtils.maskKey(keyContainer.npub)}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _setupUserSession(keyContainer, AuthenticationSource.automatic);
          return;
        } else {
          Log.warning(
            'Has keys flag set but could not load secure key container',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        }
      }

      Log.info(
        'No existing secure keys found, creating new identity automatically...',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // Auto-create identity like TikTok - seamless onboarding
      // Note: createNewIdentity() sets state to authenticating immediately, so
      // no need to set it here
      final result = await createNewIdentity();
      if (result.success && result.keyContainer != null) {
        Log.info(
          'Auto-created NEW secure Nostr identity: '
          '${NostrKeyUtils.maskKey(result.keyContainer!.npub)}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        Log.debug(
          '📱 This identity is now securely saved '
          'and will be reused on next launch',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } else {
        Log.error(
          'Failed to auto-create identity: ${result.errorMessage}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        // Set state synchronously to prevent loading screen deadlock
        _setAuthState(AuthState.unauthenticated);
      }
    } catch (e) {
      Log.error(
        'Error checking existing auth: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      // Set state synchronously to prevent loading screen deadlock
      _setAuthState(AuthState.unauthenticated);
    }
  }

  Future<void> _onTermsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'terms_accepted_at',
      DateTime.now().toIso8601String(),
    );
    await prefs.setBool('age_verified_16_plus', true);
  }

  /// Set up user session after successful authentication
  Future<void> _setupUserSession(
    SecureKeyContainer keyContainer,
    AuthenticationSource source,
  ) async {
    _currentKeyContainer = keyContainer;
    _authSource = source;

    // Create user profile
    _currentProfile = UserProfile(
      npub: keyContainer.npub,
      publicKeyHex: keyContainer.publicKeyHex,
      displayName: NostrKeyUtils.maskKey(keyContainer.npub),
    );

    // Store current user pubkey in SharedPreferences for router redirect checks
    // This allows the router to know which user's following list to check
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we need to clear user-specific data due to identity change
      final shouldClean = _userDataCleanupService.shouldClearDataForUser(
        keyContainer.publicKeyHex,
      );

      if (shouldClean) {
        await _userDataCleanupService.clearUserSpecificData(
          reason: 'identity_change',
        );
        // restore the TOS acceptance since we wouldn't be here otherwise
        await _onTermsAccepted();
      }
      await prefs.setString(
        'current_user_pubkey_hex',
        keyContainer.publicKeyHex,
      );

      await prefs.setString(_kAuthSourceKey, source.code);
      _setAuthState(AuthState.authenticated);
    } catch (e) {
      Log.warning(
        'error in _setupUserSession: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      // Default to awaiting TOS if we can't check
      _setAuthState(AuthState.awaitingTosAcceptance);
    }

    _profileController.add(_currentProfile);

    Log.info(
      'Secure user session established',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    Log.verbose(
      'Profile: ${_currentProfile!.displayName}',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    Log.debug(
      '📱 Security: Hardware-backed storage active',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }

  /// Update authentication state and notify listeners
  void _setAuthState(AuthState newState) {
    if (_authState != newState) {
      _authState = newState;
      _authStateController.add(newState);

      Log.debug(
        'Auth state changed: ${newState.name}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Get user statistics
  Map<String, dynamic> get userStats => {
    'is_authenticated': isAuthenticated,
    'auth_state': authState.name,
    'npub': currentNpub != null ? NostrKeyUtils.maskKey(currentNpub!) : null,
    'key_created_at': _currentProfile?.keyCreatedAt?.toIso8601String(),
    'last_access_at': _currentProfile?.lastAccessAt?.toIso8601String(),
    'has_error': _lastError != null,
    'last_error': _lastError,
  };

  Future<void> dispose() async {
    Log.debug(
      '📱️ Disposing SecureAuthService',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Securely dispose of key container
    _currentKeyContainer?.dispose();
    _currentKeyContainer = null;

    await _authStateController.close();
    await _profileController.close();
    _keyStorage.dispose();
  }
}
