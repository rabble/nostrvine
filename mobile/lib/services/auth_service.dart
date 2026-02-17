// ABOUTME: Authentication service managing user login, key generation, and
// auth state
// ABOUTME: Handles Nostr identity creation, import, and session management
// with secure storage

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer, SecureKeyStorage;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service_signer.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/blossom_server_discovery_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/services/relay_discovery_service.dart';
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

// Keys for Amber (NIP-55) connection persistence
const _kAmberPubkeyKey = 'amber_pubkey';
const _kAmberPackageKey = 'amber_package';

/// Source of authentication used to restore session at startup
enum AuthenticationSource {
  none('none'),
  divineOAuth('divineOAuth'),
  importedKeys('imported_keys'),
  automatic('automatic'),
  bunker('bunker'),
  amber('amber');

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

/// Callback to pre-fetch following list from REST API before auth state is set.
///
/// Called during login setup to populate SharedPreferences cache so the
/// router redirect has accurate following data before it fires synchronously.
typedef PreFetchFollowingCallback = Future<void> Function(String pubkeyHex);

/// Main authentication service for the divine app
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via
/// Riverpod
class AuthService implements BackgroundAwareService {
  AuthService({
    required UserDataCleanupService userDataCleanupService,
    SecureKeyStorage? keyStorage,
    KeycastOAuth? oauthClient,
    FlutterSecureStorage? flutterSecureStorage,
    OAuthConfig? oauthConfig,
    PendingVerificationService? pendingVerificationService,
    PreFetchFollowingCallback? preFetchFollowing,
  }) : _keyStorage = keyStorage ?? SecureKeyStorage(),
       _userDataCleanupService = userDataCleanupService,
       _oauthClient = oauthClient,
       _flutterSecureStorage = flutterSecureStorage,
       _pendingVerificationService = pendingVerificationService,
       _preFetchFollowing = preFetchFollowing,
       _oauthConfig =
           oauthConfig ??
           const OAuthConfig(serverUrl: '', clientId: '', redirectUri: '');
  final SecureKeyStorage _keyStorage;
  final UserDataCleanupService _userDataCleanupService;
  final KeycastOAuth? _oauthClient;
  final FlutterSecureStorage? _flutterSecureStorage;
  final PendingVerificationService? _pendingVerificationService;
  final PreFetchFollowingCallback? _preFetchFollowing;

  AuthState _authState = AuthState.checking;
  SecureKeyContainer? _currentKeyContainer;
  UserProfile? _currentProfile;
  String? _lastError;
  KeycastRpc? _keycastSigner;

  // NIP-46 bunker signer state
  NostrRemoteSigner? _bunkerSigner;

  // NIP-55 Android signer (Amber) state
  AndroidNostrSigner? _amberSigner;

  // NIP-46 nostrconnect:// session state (for client-initiated connections)
  NostrConnectSession? _nostrConnectSession;

  // Relay discovery state (NIP-65)
  List<DiscoveredRelay> _userRelays = [];
  bool _hasExistingProfile = false;
  final RelayDiscoveryService _relayDiscoveryService = RelayDiscoveryService();

  // Blossom server discovery state (kind 10063 / BUD-03)
  List<DiscoveredBlossomServer> _userBlossomServers = [];
  bool _hasUserBlossomServers = false;
  final BlossomServerDiscoveryService _blossomDiscoveryService =
      BlossomServerDiscoveryService();

  /// Returns the active remote signer (Amber > bunker > OAuth RPC)
  NostrSigner? get rpcSigner => _amberSigner ?? _bunkerSigner ?? _keycastSigner;
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

  /// Get discovered user relays (NIP-65)
  List<DiscoveredRelay> get userRelays => List.unmodifiable(_userRelays);

  /// Check if user has an existing profile (kind 0)
  bool get hasExistingProfile => _hasExistingProfile;

  /// Get discovered user Blossom servers (kind 10063 / BUD-03)
  List<DiscoveredBlossomServer> get userBlossomServers =>
      List.unmodifiable(_userBlossomServers);

  /// Check if user has discovered Blossom servers
  bool get hasUserBlossomServers => _userBlossomServers.isNotEmpty;

  /// Last authentication error
  String? get lastError => _lastError;

  /// Clear the last authentication error
  ///
  /// Call this when navigating away from screens that displayed the error,
  /// to prevent stale errors from being shown on other screens.
  void clearError() {
    _lastError = null;
  }

  /// Check if there are saved keys on device (without authenticating)
  ///
  /// Useful for showing different UI on welcome screen when user has
  /// previously used the app vs fresh install.
  Future<bool> hasSavedKeys() async {
    return _keyStorage.hasKeys();
  }

  /// Get the saved npub from storage (without authenticating)
  ///
  /// Returns null if no keys are saved. Used to show which identity
  /// will be resumed on welcome screen.
  Future<String?> getSavedNpub() async {
    final hasKeys = await _keyStorage.hasKeys();
    if (!hasKeys) return null;

    final keyContainer = await _keyStorage.getKeyContainer();
    return keyContainer?.npub;
  }

  /// Initialize the authentication service
  Future<void> initialize() async {
    Log.debug(
      'Initializing SecureAuthService',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Set checking state immediately - we're starting the auth check now
    _setAuthState(AuthState.checking);

    // Register with BackgroundActivityManager for lifecycle callbacks
    BackgroundActivityManager().registerService(this);

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

        case AuthenticationSource.amber:
          // Try to restore Amber (NIP-55) connection from secure storage
          final amberInfo = await _loadAmberInfo();
          if (amberInfo != null) {
            await _reconnectAmber(amberInfo.pubkey, amberInfo.package);
            return;
          }
          // Amber info not found — fall back to unauthenticated
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
      Log.info(
        'Loaded bunker info from secure storage',
        name: 'AuthService',
        category: LogCategory.auth,
      );
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

      // Run discovery in background - not needed for home feed
      unawaited(_performDiscovery());

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

  /// Connect using NIP-55 Android signer (Amber) for local signing
  ///
  /// This establishes a connection with an external Android signer app
  /// (e.g., Amber) that holds the user's private keys. All signing operations
  /// will be delegated to the signer app via Android intents.
  ///
  /// Only available on Android. Throws [UnsupportedError] on other platforms.
  Future<AuthResult> connectWithAmber() async {
    Log.info(
      'Connecting with Android signer (Amber)...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      // Check platform
      if (!_isAndroid()) {
        throw UnsupportedError(
          'NIP-55 Android signer only supported on Android',
        );
      }

      // Check if a signer app is installed
      final exists = await AndroidPlugin.existAndroidNostrSigner();
      if (exists != true) {
        throw Exception(
          'No Android signer app (e.g., Amber) installed. '
          'Please install a NIP-55 compatible signer app.',
        );
      }

      // Create the signer and get public key
      _amberSigner = AndroidNostrSigner();
      final pubkey = await _amberSigner!.getPublicKey();

      if (pubkey == null || pubkey.isEmpty) {
        throw Exception(
          'Failed to get public key from signer. '
          'The user may have denied the permission request.',
        );
      }

      // Save connection info for session restoration
      await _saveAmberInfo(pubkey, _amberSigner!.getPackage());

      // Set up user session
      await _setupUserSession(
        SecureKeyContainer.fromPublicKey(pubkey),
        AuthenticationSource.amber,
      );

      Log.info(
        'Amber connection successful for user: $pubkey',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return const AuthResult(success: true);
    } catch (e) {
      Log.error(
        'Amber connection failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _amberSigner = null;
      _lastError = 'Amber connection failed: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Helper to check if running on Android
  bool _isAndroid() {
    try {
      // This import is available at the top of the file
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Save Amber connection info to secure storage
  Future<void> _saveAmberInfo(String pubkey, String? package) async {
    if (_flutterSecureStorage == null) return;
    try {
      await _flutterSecureStorage.write(key: _kAmberPubkeyKey, value: pubkey);
      if (package != null) {
        await _flutterSecureStorage.write(
          key: _kAmberPackageKey,
          value: package,
        );
      }
      Log.info(
        'Saved Amber info to secure storage',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to save Amber info: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Load Amber connection info from secure storage
  Future<({String pubkey, String? package})?> _loadAmberInfo() async {
    if (_flutterSecureStorage == null) return null;
    try {
      final pubkey = await _flutterSecureStorage.read(key: _kAmberPubkeyKey);
      if (pubkey == null || pubkey.isEmpty) return null;

      final package = await _flutterSecureStorage.read(key: _kAmberPackageKey);
      Log.info(
        'Loaded Amber info from secure storage',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return (pubkey: pubkey, package: package);
    } catch (e) {
      Log.error(
        'Failed to load Amber info: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Clear Amber connection info from secure storage
  Future<void> _clearAmberInfo() async {
    if (_flutterSecureStorage == null) return;
    try {
      await _flutterSecureStorage.delete(key: _kAmberPubkeyKey);
      await _flutterSecureStorage.delete(key: _kAmberPackageKey);
      Log.info(
        'Cleared Amber info from secure storage',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to clear Amber info: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Reconnect to Amber using saved connection info
  Future<void> _reconnectAmber(String pubkey, String? package) async {
    Log.info(
      'Reconnecting to Amber...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);

    try {
      // Check platform
      if (!_isAndroid()) {
        throw UnsupportedError(
          'NIP-55 Android signer only supported on Android',
        );
      }

      // Check if a signer app is still installed
      final exists = await AndroidPlugin.existAndroidNostrSigner();
      if (exists != true) {
        throw Exception('Android signer app no longer installed');
      }

      // Recreate signer with saved pubkey and package
      _amberSigner = AndroidNostrSigner(pubkey: pubkey, package: package);

      _currentKeyContainer = SecureKeyContainer.fromPublicKey(pubkey);

      // Create a minimal profile for the Amber user
      final npub = NostrKeyUtils.encodePubKey(pubkey);
      _currentProfile = UserProfile(
        npub: npub,
        publicKeyHex: pubkey,
        displayName: NostrKeyUtils.maskKey(npub),
      );

      _authSource = AuthenticationSource.amber;

      _setAuthState(AuthState.authenticated);
      _profileController.add(_currentProfile);

      // Run discovery in background - not needed for home feed
      unawaited(_performDiscovery());

      Log.info(
        'Amber reconnection successful for user: $pubkey',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Amber reconnection failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _amberSigner = null;
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
    _lastError = null;

    try {
      // Parse the bunker URL
      final bunkerInfo = NostrRemoteSignerInfo.parseBunkerUrl(bunkerUrl);

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
        // Verify bunker signer is properly initialized
        final signer = _bunkerSigner;
        if (signer == null) {
          throw StateError('Bunker signer is null before pullPubkey');
        }
        Log.debug(
          'Bunker signer info: remoteSignerPubkey=${signer.info.remoteSignerPubkey}, '
          'relays=${signer.info.relays.length}, nsec=${signer.info.nsec != null}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        userPubkey = await signer.pullPubkey().timeout(
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
      } catch (e, stackTrace) {
        Log.error(
          'pullPubkey failed: $e\n$stackTrace',
          name: 'AuthService',
          category: LogCategory.auth,
        );
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
      // Clean up bunker signer connections before nulling
      _bunkerSigner?.close();
      _bunkerSigner = null;
      _lastError = 'Bunker connection failed: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Initiate a client-side NIP-46 connection using nostrconnect:// URL.
  ///
  /// This generates a nostrconnect:// URL that the user can display as a QR
  /// code or copy/paste into their signer app (Amber, nsecBunker, etc.).
  ///
  /// Returns a [NostrConnectSession] that can be used to:
  /// - Get the URL via [session.connectUrl]
  /// - Wait for connection via [waitForNostrConnectResponse]
  /// - Cancel via [cancelNostrConnect]
  ///
  /// The session will listen on relays for the bunker's response.
  Future<NostrConnectSession> initiateNostrConnect({
    List<String>? customRelays,
  }) async {
    Log.info(
      'Initiating nostrconnect:// session...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Cancel any existing session
    cancelNostrConnect();

    // Default relays for nostrconnect:// connections
    // Divine relay + well-known NIP-46 relay
    final relays =
        customRelays ?? ['wss://relay.divine.video', 'wss://relay.nsec.app'];

    // Create the session
    _nostrConnectSession = NostrConnectSession(
      relays: relays,
      appName: 'diVine',
      appUrl: 'https://divine.video',
      appIcon: 'https://divine.video/icon.png',
    );

    // Start the session (generates keypair and URL, connects to relays)
    await _nostrConnectSession!.start();

    Log.info(
      'NostrConnect session started, URL: ${_nostrConnectSession!.connectUrl}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    return _nostrConnectSession!;
  }

  /// Wait for the bunker to respond to a nostrconnect:// URL.
  ///
  /// Must be called after [initiateNostrConnect].
  ///
  /// Returns [AuthResult.success] if the bunker connects and we can
  /// authenticate, or [AuthResult.failure] on timeout/error.
  Future<AuthResult> waitForNostrConnectResponse({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (_nostrConnectSession == null) {
      return AuthResult.failure(
        'No active nostrconnect session. Call initiateNostrConnect first.',
      );
    }

    Log.info(
      'Waiting for nostrconnect response (timeout: ${timeout.inSeconds}s)...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);

    try {
      // Keep a local reference in case session is cancelled during await
      final session = _nostrConnectSession!;

      // Wait for the bunker to connect
      final result = await session.waitForConnection(timeout: timeout);

      // Check if session was cancelled while we were waiting
      if (_nostrConnectSession == null) {
        _setAuthState(AuthState.unauthenticated);
        return AuthResult.failure('Connection cancelled');
      }

      if (result == null) {
        // Timeout or cancelled
        final state = session.state;
        if (state == NostrConnectState.cancelled) {
          _setAuthState(AuthState.unauthenticated);
          return AuthResult.failure('Connection cancelled');
        } else if (state == NostrConnectState.timeout) {
          _setAuthState(AuthState.unauthenticated);
          return AuthResult.failure(
            'Connection timed out. Make sure you approved in your signer app.',
          );
        } else if (state == NostrConnectState.error) {
          _setAuthState(AuthState.unauthenticated);
          return AuthResult.failure(
            session.errorMessage ?? 'Connection failed',
          );
        }
        _setAuthState(AuthState.unauthenticated);
        return AuthResult.failure('Connection failed');
      }

      // Success! Create the bunker signer from the result
      Log.info(
        'NostrConnect succeeded! Bunker pubkey: ${result.remoteSignerPubkey}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // Create and connect the NostrRemoteSigner
      // Note: Don't send connect request since we're already connected via
      // nostrconnect://
      _bunkerSigner = NostrRemoteSigner(RelayMode.baseMode, result.info);
      _setupBunkerAuthCallback();
      await _bunkerSigner!.connect(sendConnectRequest: false);

      // Get user's public key from the bunker
      final userPubkey = await _bunkerSigner!.pullPubkey();
      if (userPubkey == null || userPubkey.isEmpty) {
        throw Exception('Failed to get public key from bunker');
      }

      // Update info with user pubkey for persistence
      final updatedInfo = NostrRemoteSignerInfo(
        remoteSignerPubkey: result.remoteSignerPubkey,
        relays: result.info.relays,
        optionalSecret: result.info.optionalSecret,
        nsec: result.info.nsec,
        userPubkey: userPubkey,
        isClientInitiated: true,
        clientPubkey: result.info.clientPubkey,
      );

      // Save bunker info for reconnection
      await _saveBunkerInfo(updatedInfo);

      // Set up user session
      await _setupUserSession(
        SecureKeyContainer.fromPublicKey(userPubkey),
        AuthenticationSource.bunker,
      );

      Log.info(
        'NostrConnect authentication complete for user: $userPubkey',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // Clean up session (signer is now managing connections)
      _nostrConnectSession?.dispose();
      _nostrConnectSession = null;

      return const AuthResult(success: true);
    } catch (e) {
      Log.error(
        'NostrConnect failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _bunkerSigner?.close();
      _bunkerSigner = null;
      _lastError = 'NostrConnect failed: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Cancel an active nostrconnect:// session.
  ///
  /// Safe to call even if no session is active.
  void cancelNostrConnect() {
    if (_nostrConnectSession != null) {
      Log.info(
        'Cancelling nostrconnect session',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _nostrConnectSession!.cancel();
      _nostrConnectSession!.dispose();
      _nostrConnectSession = null;
    }
  }

  /// Get the current nostrconnect:// URL if a session is active.
  ///
  /// Returns null if no session is active.
  String? get nostrConnectUrl => _nostrConnectSession?.connectUrl;

  /// Get the current nostrconnect session state.
  NostrConnectState? get nostrConnectState => _nostrConnectSession?.state;

  /// Stream of nostrconnect session state changes.
  Stream<NostrConnectState>? get nostrConnectStateStream =>
      _nostrConnectSession?.stateStream;

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

      // Run discovery for resumed sessions that haven't discovered relays yet
      // This handles the case where user logs in, closes app, and reopens
      // Run in background - don't block returning user from accessing the app
      if (isAuthenticated && currentNpub != null && _userRelays.isEmpty) {
        Log.info(
          '🔄 Running discovery in background for resumed session',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        unawaited(_performDiscovery());
      }

      await acceptTerms();

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
      'Signing in with Divine OAuth session',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
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

  /// Delete the user's Keycast account if one exists.
  ///
  /// This permanently deletes the account from the Keycast server.
  /// Should be called AFTER sending NIP-62 deletion request (which requires
  /// the signer to still be functional) but BEFORE [signOut].
  ///
  /// Returns a tuple of (success, errorMessage).
  /// Returns (true, null) if:
  /// - Account was successfully deleted
  /// - No Keycast session exists (nothing to delete)
  /// - OAuth client is not configured (local-only auth)
  ///
  /// Returns (false, errorMessage) if deletion failed.
  Future<(bool success, String? error)> deleteKeycastAccount() async {
    Log.debug(
      '🗑️ Attempting to delete Keycast account',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // No OAuth client configured - using local auth only
    if (_oauthClient == null) {
      Log.debug(
        'No OAuth client configured - skipping Keycast deletion',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return (true, null);
    }

    try {
      // Check for existing session with valid access token
      final session = await _oauthClient.getSession();
      if (session == null) {
        Log.debug(
          'No Keycast session found - nothing to delete',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return (true, null);
      }

      final accessToken = session.accessToken;
      if (accessToken == null) {
        Log.debug(
          'Keycast session has no access token - nothing to delete',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return (true, null);
      }

      // Delete the account using the session's access token
      final result = await _oauthClient.deleteAccount(accessToken);

      if (result.success) {
        Log.info(
          '✅ Keycast account deleted successfully',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return (true, null);
      } else {
        Log.warning(
          '⚠️ Keycast account deletion failed: ${result.error}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return (false, result.error);
      }
    } catch (e) {
      Log.error(
        '❌ Error deleting Keycast account: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return (false, 'Failed to delete Keycast account: $e');
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

      // Clear configured relays so next login re-discovers from NIP-65
      await prefs.remove('configured_relays');

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

      // Clean up Amber signer if active
      if (_amberSigner != null) {
        _amberSigner!.close();
        _amberSigner = null;
        await _clearAmberInfo();
      }

      try {
        if (_oauthClient != null) {
          _oauthClient.logout();
        } else {
          await KeycastSession.clear(_flutterSecureStorage);
        }
      } catch (_) {}

      // Clear any pending verification data
      // (fire-and-forget since it's best-effort)
      unawaited(_pendingVerificationService?.clear());

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
    int? createdAt,
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
        createdAt:
            createdAt ?? NostrTimestamp.now(driftTolerance: driftTolerance),
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

  Future<void> acceptTerms() async {
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
          isIdentityChange: true,
        );
        // restore the TOS acceptance since we wouldn't be here otherwise
        await acceptTerms();
      }
      await prefs.setString(
        'current_user_pubkey_hex',
        keyContainer.publicKeyHex,
      );

      await prefs.setString(_kAuthSourceKey, source.code);

      // Pre-fetch following list from REST API BEFORE setting auth state.
      // The router redirect fires synchronously on auth state change and reads
      // following_list_{pubkey} from SharedPreferences. If the cache is empty
      // (identity change cleared it, or first login), the redirect sends the
      // user to /explore instead of /home. By fetching here, we ensure the
      // cache is populated before the redirect fires.
      if (_preFetchFollowing != null) {
        try {
          await _preFetchFollowing(keyContainer.publicKeyHex);
        } catch (e) {
          Log.warning(
            'Pre-fetch following list failed (will rely on '
            'FollowRepository): $e',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        }
      }

      _setAuthState(AuthState.authenticated);

      // Run discovery in background - it's not needed for the home feed to start
      // loading. Discovery results (relay list, blossom servers) are only used
      // when editing profile or publishing content.
      unawaited(_performDiscovery());
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

  /// Perform all discovery operations using a single temporary NostrClient.
  ///
  /// This consolidates relay discovery (NIP-65) and Blossom server discovery
  /// (kind 10063) into a single temporary client to avoid wasteful reconnections.
  ///
  /// Individual operations have their own timeouts (addRelay: 5s, query: 2s).
  /// For returning users, this runs in background via unawaited().
  Future<void> _performDiscovery() async {
    if (_currentKeyContainer == null) return;

    final npub = _currentKeyContainer!.npub;

    Log.info(
      '🔍 Starting user discovery (relays + Blossom servers)...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    NostrClient? tempClient;
    try {
      // Create ONE temporary NostrClient for all indexer queries
      final tempConfig = NostrClientConfig(
        signer: AuthServiceSigner(_currentKeyContainer),
      );
      final tempRelayConfig = RelayManagerConfig(
        defaultRelayUrl: 'wss://relay.divine.video',
        storage: SharedPreferencesRelayStorage(),
      );
      tempClient = NostrClient(
        config: tempConfig,
        relayManagerConfig: tempRelayConfig,
      );

      await tempClient.initialize();

      // Run all discoveries on the same client
      await _discoverUserRelaysWithClient(npub, tempClient);
      await _discoverUserBlossomServersWithClient(npub, tempClient);
      await _checkExistingProfileWithClient(tempClient);
    } catch (e) {
      Log.warning(
        '⚠️ Discovery failed: $e - using default fallbacks',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      // Set empty defaults - will use diVine fallbacks
      _userRelays = [];
      _userBlossomServers = [];
      _hasUserBlossomServers = false;
      _hasExistingProfile = false;
    } finally {
      // Always clean up the temporary client
      tempClient?.dispose();
    }

    Log.info(
      '📊 Discovery complete: relays= (${_userRelays.length}), '
      'blossomServers=$_hasUserBlossomServers (${_userBlossomServers.length}), '
      'hasExistingProfile=$_hasExistingProfile',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }

  /// Discover user relays via NIP-65 using the provided NostrClient.
  ///
  /// Skips discovery if user has manually edited their relays to preserve
  /// user's custom configuration.
  Future<void> _discoverUserRelaysWithClient(
    String npub,
    NostrClient nostrClient,
  ) async {
    Log.info(
      '🔍 Discovering relays for user via NIP-65...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    try {
      // Use discovery method that respects user's existing relay config
      final result = await _relayDiscoveryService.discoverRelaysIfNotConfigured(
        npub,
        nostrClient: nostrClient,
      );

      if (result.success && result.hasRelays) {
        _userRelays = result.relays;

        Log.info(
          '✅ Discovered ${_userRelays.length} user relays from ${result.foundOnIndexer ?? "cache"}',
          name: 'AuthService',
          category: LogCategory.auth,
        );

        // Log relay details
        for (final relay in _userRelays) {
          Log.debug(
            '  - ${relay.url} (read: ${relay.read}, write: ${relay.write})',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        }
      } else {
        _userRelays = [];

        // Check if skip was due to existing config (not an error)
        if (result.errorMessage == 'User has configured relays') {
          Log.info(
            '✅ Using user-configured relays (manual edits preserved)',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        } else {
          Log.warning(
            '⚠️ No relay list found for user - will use diVine relay only',
            name: 'AuthService',
            category: LogCategory.auth,
          );

          if (result.errorMessage != null) {
            Log.debug(
              'Relay discovery error: ${result.errorMessage}',
              name: 'AuthService',
              category: LogCategory.auth,
            );
          }
        }
      }
    } catch (e) {
      _userRelays = [];

      Log.error(
        '❌ Relay discovery failed: $e - falling back to diVine relay only',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Discover user Blossom servers via kind 10063 using the provided NostrClient.
  Future<void> _discoverUserBlossomServersWithClient(
    String npub,
    NostrClient nostrClient,
  ) async {
    Log.info(
      '🌸 Discovering Blossom servers for user via kind 10063...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    try {
      final result = await _blossomDiscoveryService.discoverServers(
        npub,
        nostrClient: nostrClient,
      );

      if (result.success && result.hasServers) {
        _userBlossomServers = result.servers;
        _hasUserBlossomServers = true;

        Log.info(
          '✅ Discovered ${_userBlossomServers.length} Blossom servers from ${result.source ?? "cache"}',
          name: 'AuthService',
          category: LogCategory.auth,
        );

        // Log server details in priority order
        for (final server in result.serversByPriority) {
          Log.debug(
            '  ${server.priority}: ${server.url}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        }
      } else {
        _userBlossomServers = [];
        _hasUserBlossomServers = false;

        Log.info(
          '📝 No Blossom server list found - will use diVine media server',
          name: 'AuthService',
          category: LogCategory.auth,
        );

        if (result.errorMessage != null) {
          Log.debug(
            'Blossom discovery info: ${result.errorMessage}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        }
      }
    } catch (e) {
      _userBlossomServers = [];
      _hasUserBlossomServers = false;

      Log.warning(
        '⚠️ Blossom server discovery failed: $e - falling back to diVine media server',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Check if user has an existing profile (kind 0) on indexers.
  ///
  /// This is used as a guardrail to prevent accidentally overwriting
  /// existing profiles with blank data.
  Future<void> _checkExistingProfileWithClient(NostrClient nostrClient) async {
    if (_currentKeyContainer == null) {
      _hasExistingProfile = false;
      return;
    }

    Log.info(
      '👤 Checking for existing profile (kind 0)...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    try {
      final filter = Filter(
        kinds: [0],
        authors: [_currentKeyContainer!.publicKeyHex],
        limit: 1,
      );

      final events = await nostrClient
          .queryEvents([filter])
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              Log.warning(
                'Timeout checking for existing profile',
                name: 'AuthService',
                category: LogCategory.auth,
              );
              return <Event>[];
            },
          );

      _hasExistingProfile = events.isNotEmpty;

      Log.info(
        '${_hasExistingProfile ? "✅" : "📝"} Profile check: '
        'hasExistingProfile=$_hasExistingProfile',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      _hasExistingProfile = false;

      Log.warning(
        '⚠️ Profile check failed: $e - assuming no existing profile',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
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

  // ============================================================
  // BackgroundAwareService implementation
  // ============================================================

  @override
  String get serviceName => 'AuthService';

  @override
  void onAppBackgrounded() {
    // Pause bunker signer reconnection attempts when app goes to background
    if (_bunkerSigner != null) {
      Log.info(
        '📱 App backgrounded - pausing bunker signer',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _bunkerSigner!.pause();
    }
  }

  @override
  void onAppResumed() {
    // Resume bunker signer reconnection attempts when app returns
    if (_bunkerSigner != null) {
      Log.info(
        '📱 App resumed - resuming bunker signer',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _bunkerSigner!.resume();
    }
  }

  @override
  void onExtendedBackground() {
    // For extended background, we keep the signer paused
    // No additional action needed - pause() already stops reconnection attempts
    Log.debug(
      '📱 Extended background - bunker signer remains paused',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }

  @override
  void onPeriodicCleanup() {
    // No cleanup needed for auth service during periodic cleanup
  }

  Future<void> dispose() async {
    Log.debug(
      '📱️ Disposing SecureAuthService',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Unregister from BackgroundActivityManager
    BackgroundActivityManager().unregisterService(this);

    // Close bunker signer if active
    _bunkerSigner?.close();
    _bunkerSigner = null;

    // Close Amber signer if active
    _amberSigner?.close();
    _amberSigner = null;

    // Securely dispose of key container
    _currentKeyContainer?.dispose();
    _currentKeyContainer = null;

    await _authStateController.close();
    await _profileController.close();
    _keyStorage.dispose();
  }
}
