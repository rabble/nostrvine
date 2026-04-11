// ABOUTME: Authentication service managing user login, key generation, and
// auth state
// ABOUTME: Handles Nostr identity creation, import, and session management
// with secure storage

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show
        NostrKeyManager,
        SecureKeyContainer,
        SecureKeyStorage,
        SecureKeyStorageException;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/local_key_signer.dart';
import 'package:openvine/services/nostr_identity.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/utils/divine_login_banner_dismissal.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/nostr_timestamp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:openvine/models/authentication_source.dart';

// Key for persisted authentication source
const _kAuthSourceKey = 'authentication_source';

// Key for the last-used account npub (used to restore the correct identity on restart)
const _kLastUsedNpubKey = 'last_used_npub';

// Keys for bunker connection persistence
const _kBunkerInfoKey = 'bunker_info';

// Keys for Amber (NIP-55) connection persistence
const _kAmberPubkeyKey = 'amber_pubkey';
const _kAmberPackageKey = 'amber_package';

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

/// Callback invoked when NIP-65 relay discovery completes with a non-empty list.
/// Used by NostrService to add discovered relays to the current client without
/// blocking app startup.
typedef UserRelaysDiscoveredCallback = void Function(List<String> relayUrls);

/// Main authentication service for the Divine app
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via
/// Riverpod
class AuthService implements BackgroundAwareService {
  AuthService({
    required UserDataCleanupService userDataCleanupService,
    SecureKeyStorage? keyStorage,
    NostrKeyManager? nostrKeyManager,
    KeycastOAuth? oauthClient,
    FlutterSecureStorage? flutterSecureStorage,
    OAuthConfig? oauthConfig,
    PendingVerificationService? pendingVerificationService,
    PreFetchFollowingCallback? preFetchFollowing,
    String? profileCheckIndexerUrl,
    List<String>? indexerRelays,
    RelayDiscoveryService? relayDiscoveryService,
  }) : _keyStorage = keyStorage ?? SecureKeyStorage(),
       _nostrKeyManager = nostrKeyManager,
       _userDataCleanupService = userDataCleanupService,
       _oauthClient = oauthClient,
       _flutterSecureStorage = flutterSecureStorage,
       _pendingVerificationService = pendingVerificationService,
       _preFetchFollowing = preFetchFollowing,
       _profileCheckIndexerUrl = profileCheckIndexerUrl,
       _relayDiscoveryService =
           relayDiscoveryService ??
           RelayDiscoveryService(indexerRelays: indexerRelays),
       _oauthConfig =
           oauthConfig ??
           const OAuthConfig(serverUrl: '', clientId: '', redirectUri: '');
  final SecureKeyStorage _keyStorage;
  final NostrKeyManager? _nostrKeyManager;
  final UserDataCleanupService _userDataCleanupService;
  final KeycastOAuth? _oauthClient;
  final FlutterSecureStorage? _flutterSecureStorage;
  final PendingVerificationService? _pendingVerificationService;
  final PreFetchFollowingCallback? _preFetchFollowing;
  final String? _profileCheckIndexerUrl;

  AuthState _authState = AuthState.checking;
  SecureKeyContainer? _currentKeyContainer;
  UserProfile? _currentProfile;
  String? _lastError;
  bool _storageErrorOccurred = false;
  bool _hasExpiredOAuthSession = false;
  Future<bool>? _pendingRefresh;
  KeycastRpc? _keycastSigner;

  // RPC capability state — separate from AuthState so the router doesn't
  // need to know about remote signer warmup.
  AuthRpcCapability _authRpcCapability = AuthRpcCapability.unavailable;

  // NIP-46 bunker signer state
  NostrRemoteSigner? _bunkerSigner;

  // NIP-55 Android signer (Amber) state
  AndroidNostrSigner? _amberSigner;

  // NIP-46 nostrconnect:// session state (for client-initiated connections)
  NostrConnectSession? _nostrConnectSession;

  // Atomic signing identity — couples pubkey with signing mechanism
  NostrIdentity? _currentIdentity;

  // Relay discovery state (NIP-65)
  List<DiscoveredRelay> _userRelays = [];
  bool _hasExistingProfile = false;
  final RelayDiscoveryService _relayDiscoveryService;

  /// Callback registered by NostrService to add discovered relays to the client
  /// when discovery completes (avoids race where client is built before discovery).
  UserRelaysDiscoveredCallback? _onUserRelaysDiscovered;

  /// The current user's atomic signing identity, or null if not authenticated.
  ///
  /// Use [requireIdentity] in code that runs only when authenticated
  /// (post-router-gate) to get a guaranteed non-null value.
  NostrIdentity? get currentIdentity => _currentIdentity;

  /// The current user's signing identity, guaranteed non-null.
  ///
  /// Throws [StateError] if called when no identity is set. This should only
  /// happen if the caller bypasses the router's authentication gate.
  /// Use this in post-authentication code instead of [currentIdentity]!.
  NostrIdentity get requireIdentity {
    final identity = _currentIdentity;
    if (identity == null) {
      throw StateError(
        'requireIdentity called with no active NostrIdentity. '
        'This code path should only execute when authenticated.',
      );
    }
    return identity;
  }

  final OAuthConfig _oauthConfig;

  // Streaming controllers for reactive auth state
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  final StreamController<UserProfile?> _profileController =
      StreamController<UserProfile?>.broadcast();
  final StreamController<AuthRpcCapability> _rpcCapabilityController =
      StreamController<AuthRpcCapability>.broadcast();

  /// Current authentication state
  AuthState get authState => _authState;

  /// Stream of authentication state changes
  Stream<AuthState> get authStateStream => _authStateController.stream;

  /// Current user profile (null if not authenticated)
  UserProfile? get currentProfile => _currentProfile;

  /// Stream of profile changes
  Stream<UserProfile?> get profileStream => _profileController.stream;

  /// Current public key (npub format).
  ///
  /// Reads from [currentIdentity] when available (post-authentication),
  /// falls back to [_currentKeyContainer] during the auth-screen lifecycle.
  String? get currentNpub =>
      _currentIdentity?.npub ?? _currentKeyContainer?.npub;

  /// Current public key (hex format).
  ///
  /// Reads from [currentIdentity] when available (post-authentication),
  /// falls back to [_currentKeyContainer] or [_currentProfile] during the
  /// auth-screen lifecycle.
  String? get currentPublicKeyHex =>
      _currentIdentity?.pubkey ??
      _currentKeyContainer?.publicKeyHex ??
      _currentProfile?.publicKeyHex;

  /// Current secure key container (null if not authenticated).
  ///
  /// Production code should use [currentIdentity] instead. This getter
  /// exists for tests that need direct access to the key container.
  @visibleForTesting
  SecureKeyContainer? get currentKeyContainer => _currentKeyContainer;

  /// Check if user is authenticated
  bool get isAuthenticated => _authState == AuthState.authenticated;

  /// Authentication source used for current session
  AuthenticationSource _authSource = AuthenticationSource.none;

  /// Get the current authentication source
  AuthenticationSource get authenticationSource => _authSource;

  /// Check if user has registered with Divine (email/password)
  /// Returns true if authenticated via Divine OAuth, false for anonymous/imported keys
  bool get isRegistered => _authSource == AuthenticationSource.divineOAuth;

  /// Check if user is using an anonymous auto-generated identity
  bool get isAnonymous => _authSource == AuthenticationSource.automatic;

  /// Current RPC capability state.
  AuthRpcCapability get authRpcCapability => _authRpcCapability;

  /// Stream of RPC capability changes.
  Stream<AuthRpcCapability> get authRpcCapabilityStream =>
      _rpcCapabilityController.stream;

  /// Whether this identity can publish Nostr writes right now.
  ///
  /// True when the identity has a local private key (can sign locally)
  /// OR when RPC is fully ready. False for pubkey-only identities that
  /// are still waiting for RPC warmup.
  bool get canPublishNostrWritesNow {
    final identity = _currentIdentity;
    if (identity == null) return false;
    // Local signing is always available if we have a private key.
    if (identity is LocalNostrIdentity) return true;
    if (identity is KeycastNostrIdentity) return true;
    // Amber and Bunker identities can always sign via their remote signer.
    if (identity is AmberNostrIdentity) return true;
    if (identity is BunkerNostrIdentity) return true;
    return false;
  }

  /// True when a divineOAuth user's session expired and refresh failed.
  /// The user's identity is intact but remote signing is unavailable.
  /// UI should prompt re-login instead of "Secure Your Account".
  bool get hasExpiredOAuthSession => _hasExpiredOAuthSession;

  /// Timeout for background RPC refresh during local-first startup.
  @visibleForTesting
  static const rpcRefreshTimeout = Duration(seconds: 10);

  /// Local-first Divine OAuth initialization.
  ///
  /// Loads the Keycast session and local keys. If a matching local private
  /// key exists, authenticates immediately and attempts RPC refresh in the
  /// background. If no local key exists, falls back to the previous
  /// synchronous refresh-or-fallback behavior.
  Future<void> _initializeDivineOAuth() async {
    Log.info(
      'initialize: restoring Divine OAuth session (local-first)...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    final session = await KeycastSession.load(_flutterSecureStorage);
    SecureKeyContainer? localKey;
    try {
      if (await _keyStorage.hasKeys()) {
        localKey = await _keyStorage.getKeyContainer();
      }
    } catch (e, stack) {
      _reportStorageError(e, stack, 'divineOAuth local key load');
    }

    final targetPubkey = session?.userPubkey ?? localKey?.publicKeyHex;

    // Fast path: matching local key → authenticate immediately.
    if (_canUseLocalDivineIdentity(localKey, targetPubkey)) {
      _hasExpiredOAuthSession = session == null || !session.hasRpcAccess;
      _setRpcCapability(
        _hasExpiredOAuthSession
            ? AuthRpcCapability.upgrading
            : AuthRpcCapability.rpcReady,
      );

      // If we already have a valid session with RPC access, set up the
      // Keycast signer before building the identity so we get a
      // KeycastNostrIdentity instead of a LocalNostrIdentity.
      if (session != null && session.hasRpcAccess) {
        _keycastSigner = KeycastRpc.fromSession(_oauthConfig, session);
      }

      await _setupUserSession(localKey!, AuthenticationSource.divineOAuth);

      Log.info(
        'initialize: local divine identity restored immediately '
        '(rpc=${_authRpcCapability.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // If RPC isn't ready yet, try to upgrade in background.
      if (_authRpcCapability != AuthRpcCapability.rpcReady) {
        unawaited(_upgradeDivineRpcInBackground(session));
      }
      return;
    }

    // Slow path: no local key — try RPC refresh synchronously.
    await _restoreDivineRpcOrFallbackUnauthenticated(session);
  }

  /// Whether [localKey] can be used for immediate Divine OAuth identity.
  bool _canUseLocalDivineIdentity(
    SecureKeyContainer? localKey,
    String? targetPubkey,
  ) {
    if (localKey == null || !localKey.hasPrivateKey) return false;
    if (targetPubkey == null) return true; // No session to compare against.
    return localKey.publicKeyHex == targetPubkey;
  }

  /// Background RPC refresh with bounded timeout.
  ///
  /// On success: rebuilds identity to [KeycastNostrIdentity] and sets
  /// [AuthRpcCapability.rpcReady]. On failure: preserves the local identity
  /// and sets capability back to [AuthRpcCapability.unavailable].
  Future<void> _upgradeDivineRpcInBackground(
    KeycastSession? session,
  ) async {
    Log.info(
      'initialize: starting background RPC refresh...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    try {
      if (_oauthClient == null) {
        _setRpcCapability(AuthRpcCapability.unavailable);
        return;
      }

      final refreshed = await _oauthClient.refreshSession().timeout(
        rpcRefreshTimeout,
      );

      if (refreshed != null && refreshed.hasRpcAccess) {
        Log.info(
          'initialize: background RPC refresh succeeded',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        await refreshed.save(_flutterSecureStorage);
        await _clearDismissedDivineLoginBannerForCurrentUser();
        _keycastSigner = KeycastRpc.fromSession(_oauthConfig, refreshed);
        _currentIdentity = _buildIdentity();
        _hasExpiredOAuthSession = false;
        _setRpcCapability(AuthRpcCapability.rpcReady);
        return;
      }
    } on TimeoutException {
      Log.warning(
        'initialize: background RPC refresh timed out '
        '(${rpcRefreshTimeout.inSeconds}s)',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'initialize: background RPC refresh failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }

    _setRpcCapability(AuthRpcCapability.unavailable);
  }

  /// Synchronous fallback for Divine OAuth when no local key is available.
  ///
  /// Attempts RPC refresh, then falls back to unauthenticated.
  Future<void> _restoreDivineRpcOrFallbackUnauthenticated(
    KeycastSession? session,
  ) async {
    // If session is valid with RPC access, sign in directly.
    if (session != null && session.hasRpcAccess) {
      Log.info(
        'initialize: Divine OAuth session found with RPC access '
        '(no local key)',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      await signInWithDivineOAuth(session);
      return;
    }

    // Try refresh.
    Log.info(
      'initialize: no local key, attempting synchronous refresh...',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    if (_oauthClient != null) {
      final refreshed = await _tryRefreshOAuthSession(
        caller: 'initialize',
      );
      if (refreshed) return;
    }

    // Refresh failed, no local keys — unauthenticated.
    _hasExpiredOAuthSession = true;
    Log.info(
      'initialize: refresh failed, no local keys — '
      'unauthenticated with expired session flag',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    _setAuthState(AuthState.unauthenticated);
  }

  /// Attempt to silently refresh an expired OAuth session.
  ///
  /// Returns true if the refresh succeeded and the user is now fully
  /// authenticated. Returns false if no expired session exists or if
  /// the refresh fails (caller should navigate to login).
  ///
  /// Concurrent callers share a single in-flight refresh to avoid
  /// consuming one-time-use refresh tokens in a race.
  Future<bool> tryRefreshExpiredSession() {
    if (!_hasExpiredOAuthSession || _oauthClient == null) {
      return Future.value(false);
    }
    return _pendingRefresh ??= _doRefreshExpiredSession().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<bool> _doRefreshExpiredSession() async {
    Log.info(
      'tryRefreshExpiredSession: attempting silent refresh',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    return _tryRefreshOAuthSession(caller: 'tryRefreshExpiredSession');
  }

  /// Shared OAuth session refresh logic used by both [initialize] and
  /// [tryRefreshExpiredSession]. Returns true if refresh succeeded.
  Future<bool> _tryRefreshOAuthSession({required String caller}) async {
    try {
      final refreshed = await _oauthClient!.refreshSession();
      if (refreshed != null && refreshed.hasRpcAccess) {
        Log.info(
          '$caller: refresh succeeded',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        await refreshed.save(_flutterSecureStorage);
        await _clearDismissedDivineLoginBannerForCurrentUser();
        await signInWithDivineOAuth(refreshed);
        return true;
      }
    } catch (e) {
      Log.error(
        '$caller: refresh failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
    return false;
  }

  Future<void> _clearDismissedDivineLoginBannerForCurrentUser([
    String? publicKeyHex,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final targetPubkey =
        publicKeyHex ?? prefs.getString('current_user_pubkey_hex');
    if (targetPubkey == null || targetPubkey.isEmpty) {
      return;
    }
    await clearDivineLoginBannerDismissal(prefs, targetPubkey);
  }

  /// Get discovered user relays (NIP-65)
  List<DiscoveredRelay> get userRelays => List.unmodifiable(_userRelays);

  /// Register a callback to be invoked when NIP-65 relay discovery completes
  /// with a non-empty list. Pass [null] to unregister.
  /// NostrService uses this to add discovered relays to the current client
  /// without blocking app startup.
  void registerUserRelaysDiscoveredCallback(
    UserRelaysDiscoveredCallback? callback,
  ) {
    _onUserRelaysDiscovered = callback;
  }

  /// Check if user has an existing profile (kind 0)
  bool get hasExistingProfile => _hasExistingProfile;

  /// Last authentication error
  String? get lastError => _lastError;

  /// Clear the last authentication error
  ///
  /// Call this when navigating away from screens that displayed the error,
  /// to prevent stale errors from being shown on other screens.
  void clearError() {
    _lastError = null;
  }

  /// Report a secure storage error to Crashlytics with auth context.
  void _reportStorageError(dynamic error, StackTrace stack, String reason) {
    final crashlytics = CrashReportingService.instance;
    crashlytics.log('Storage error during auth: $reason');
    unawaited(crashlytics.setCustomKey('auth_source', _authSource.code));
    unawaited(crashlytics.recordError(error, stack, reason: reason));
  }

  /// Check if there are saved keys on device (without authenticating)
  ///
  /// Useful for showing different UI on welcome screen when user has
  /// previously used the app vs fresh install.
  Future<bool> hasSavedKeys() async {
    try {
      return await _keyStorage.hasKeys();
    } catch (e, stack) {
      Log.error(
        'Secure storage error checking for saved keys: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _reportStorageError(e, stack, 'hasSavedKeys()');
      return false;
    }
  }

  /// Get the saved npub from storage (without authenticating)
  ///
  /// Returns null if no keys are saved. Used to show which identity
  /// will be resumed on welcome screen.
  Future<String?> getSavedNpub() async {
    try {
      final hasKeys = await _keyStorage.hasKeys();
      if (!hasKeys) return null;

      final keyContainer = await _keyStorage.getKeyContainer();
      return keyContainer?.npub;
    } catch (e, stack) {
      Log.error(
        'Secure storage error loading saved npub: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _reportStorageError(e, stack, 'getSavedNpub()');
      return null;
    }
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
          Log.info(
            'initialize: authSource=none — fresh install or explicit logout',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _setAuthState(AuthState.unauthenticated);
          return;

        case AuthenticationSource.divineOAuth:
          await _initializeDivineOAuth();
          return;

        case AuthenticationSource.importedKeys:
          await _restoreLastUsedAccountOrFallback(
            AuthenticationSource.importedKeys,
          );

        case AuthenticationSource.automatic:
          await _restoreLastUsedAccountOrFallback(
            AuthenticationSource.automatic,
          );

        case AuthenticationSource.bunker:
          // Try to restore bunker connection from secure storage
          Log.info(
            'initialize: restoring bunker connection...',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          final bunkerInfo = await _loadBunkerInfo();
          if (bunkerInfo != null) {
            await _reconnectBunker(bunkerInfo);
            return;
          }
          // Bunker info not found — fall back to unauthenticated
          Log.warning(
            'initialize: bunker info not found in secure storage',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _setAuthState(AuthState.unauthenticated);
          return;

        case AuthenticationSource.amber:
          // Try to restore Amber (NIP-55) connection from secure storage
          Log.info(
            'initialize: restoring Amber connection...',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          final amberInfo = await _loadAmberInfo();
          if (amberInfo != null) {
            Log.info(
              'initialize: Amber info found — pubkey=${amberInfo.pubkey}',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            await _reconnectAmber(amberInfo.pubkey, amberInfo.package);
            return;
          }
          // Amber info not found — fall back to unauthenticated
          Log.warning(
            'initialize: Amber info not found in secure storage',
            name: 'AuthService',
            category: LogCategory.auth,
          );
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

  /// Create a new anonymous account with a fresh identity.
  ///
  /// Always generates a brand-new keypair. Used by the "Skip for now" flow
  /// on the create-account screen so that each skip produces a distinct
  /// anonymous identity.
  ///
  /// The previous identity (if any) remains archived in per-account storage
  /// and in the known-accounts registry, so the user can switch back to it.
  ///
  /// Throws if identity creation fails.
  Future<void> createAnonymousAccount() async {
    Log.info(
      'createAnonymousAccount: starting — clearing primary key slot',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Clear the primary key slot so createNewIdentity() writes fresh keys
    // instead of _checkExistingAuth() finding and reusing old ones.
    await _keyStorage.deleteKeys();

    final result = await createNewIdentity();
    if (!result.success) {
      Log.error(
        'createAnonymousAccount: identity creation failed — '
        '${result.errorMessage}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      throw Exception(result.errorMessage ?? 'Failed to create identity');
    }

    Log.info(
      'createAnonymousAccount: identity created, accepting terms — '
      'pubkey=${result.keyContainer?.publicKeyHex}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    await acceptTerms();

    Log.info(
      'createAnonymousAccount: complete',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }

  /// Create a new anonymous account from a pre-generated key container.
  ///
  /// Used by invite-gated signup so the app can consume the invite with the
  /// new key before persisting it to secure storage.
  Future<void> createAnonymousAccountFromKeyContainer(
    SecureKeyContainer keyContainer,
  ) async {
    String? privateKeyHex;
    keyContainer.withPrivateKey<void>((privateKey) {
      privateKeyHex = privateKey;
    });

    if (privateKeyHex == null || privateKeyHex!.isEmpty) {
      throw Exception('Failed to read generated identity key');
    }

    await createAnonymousAccountFromPrivateKeyHex(privateKeyHex!);
  }

  /// Create a new anonymous account from a known private key.
  Future<void> createAnonymousAccountFromPrivateKeyHex(
    String privateKeyHex,
  ) async {
    Log.info(
      'createAnonymousAccountFromPrivateKeyHex: starting — '
      'clearing primary key slot',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      await _keyStorage.deleteKeys();
      final keyContainer = await _keyStorage.importFromHex(privateKeyHex);
      await _setupUserSession(keyContainer, AuthenticationSource.automatic);
      await acceptTerms();

      Log.info(
        'createAnonymousAccountFromPrivateKeyHex: complete',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'createAnonymousAccountFromPrivateKeyHex failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to create identity: $e';
      _setAuthState(AuthState.unauthenticated);
      rethrow;
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

  // ---------------------------------------------------------------------------
  // Known accounts registry
  // ---------------------------------------------------------------------------

  /// Reads the list of known accounts from SharedPreferences.
  ///
  /// On the first call after upgrading from the old single-account system,
  /// the `known_accounts` key will be absent (`null`). In that case we run a
  /// one-time migration that checks for a legacy session and persists the
  /// result so the migration never runs again.
  Future<List<KnownAccount>> getKnownAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kKnownAccountsKey);
      Log.info(
        'getKnownAccounts: raw=${raw == null ? 'null' : '${raw.length} chars'}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // null  → key never written → run one-time migration
      // empty → key was written but all accounts removed → no migration
      if (raw == null) {
        return _migrateLegacyAccount(prefs);
      }
      if (raw.isEmpty) return [];

      final decoded = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final accounts = decoded.map(KnownAccount.fromJson).toList()
        ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      return accounts;
    } catch (e) {
      Log.warning(
        'Failed to load known accounts: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return [];
    }
  }

  /// One-time migration from the old single-account auth system.
  ///
  /// Checks for a legacy session stored under the old `authentication_source`
  /// key and, if found, creates a [KnownAccount] entry for it.
  ///
  /// Additionally, always checks [SecureKeyStorage] for an automatic/anonymous
  /// identity. A user may have started with an automatic account and later
  /// switched to bunker/OAuth — the old automatic keys are still in storage
  /// even though `authentication_source` was overwritten.
  ///
  /// The result is persisted to [kKnownAccountsKey] so this migration never
  /// runs again.
  Future<List<KnownAccount>> _migrateLegacyAccount(
    SharedPreferences prefs,
  ) async {
    Log.info(
      'known_accounts key absent — running one-time legacy migration',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    final rawAuthSource = prefs.getString(_kAuthSourceKey);
    final source = AuthenticationSource.fromCode(rawAuthSource);
    Log.info(
      'Legacy migration: rawAuthSource=$rawAuthSource, '
      'resolved=${source.name}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    if (source == AuthenticationSource.none) {
      // Fresh install or explicit logout — still check for automatic keys.
      Log.info(
        'Legacy migration: source=none, checking automatic keys...',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      final accounts = await _migrateAutomaticKeys([]);
      Log.info(
        'Legacy migration: source=none, automatic keys check '
        'returned ${accounts.length} account(s)',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      await _persistMigrationResult(prefs, accounts);
      return accounts;
    }

    final accounts = <KnownAccount>[];

    // 1. Recover the account matching the persisted auth source.
    String? pubkeyHex;
    try {
      switch (source) {
        case AuthenticationSource.automatic:
        case AuthenticationSource.importedKeys:
          final keyContainer = await _keyStorage.getKeyContainer();
          pubkeyHex = keyContainer?.publicKeyHex;

        case AuthenticationSource.amber:
          final amberInfo = await _loadAmberInfo();
          pubkeyHex = amberInfo?.pubkey;

        case AuthenticationSource.bunker:
          final bunkerInfo = await _loadBunkerInfo();
          pubkeyHex = bunkerInfo?.userPubkey;

        case AuthenticationSource.divineOAuth:
          final session = await KeycastSession.load(_flutterSecureStorage);
          pubkeyHex = session?.userPubkey;

        case AuthenticationSource.none:
          break;
      }
    } catch (e) {
      Log.warning(
        'Legacy migration failed to read old session: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }

    if (pubkeyHex != null && pubkeyHex.length == 64) {
      final now = DateTime.now();
      accounts.add(
        KnownAccount(
          pubkeyHex: pubkeyHex,
          authSource: source,
          addedAt: now,
          lastUsedAt: now,
        ),
      );
      Log.info(
        'Legacy migration: created entry for '
        'pubkey=$pubkeyHex, source=${source.name}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }

    // 2. Always check for automatic keys that may belong to a different
    //    identity than the current auth source (e.g. user started with an
    //    anonymous account, then later logged in via bunker/OAuth).
    if (source != AuthenticationSource.automatic &&
        source != AuthenticationSource.importedKeys) {
      await _migrateAutomaticKeys(accounts);
    }

    if (accounts.isEmpty) {
      Log.info(
        'Legacy migration: no recoverable session found',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }

    await _persistMigrationResult(prefs, accounts);
    return accounts;
  }

  /// Checks [SecureKeyStorage] for automatic/anonymous keys and adds a
  /// [KnownAccount] entry if found and not already in [accounts].
  ///
  /// Returns [accounts] for convenience (mutates in place).
  Future<List<KnownAccount>> _migrateAutomaticKeys(
    List<KnownAccount> accounts,
  ) async {
    try {
      Log.info(
        'Legacy migration: _migrateAutomaticKeys — '
        'calling _keyStorage.getKeyContainer()...',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      final keyContainer = await _keyStorage.getKeyContainer();
      final hex = keyContainer?.publicKeyHex;
      Log.info(
        'Legacy migration: _migrateAutomaticKeys — '
        'keyContainer=${keyContainer != null}, '
        'hex=${hex != null ? '${hex.length} chars' : 'null'}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      if (hex != null &&
          hex.length == 64 &&
          !accounts.any((a) => a.pubkeyHex == hex)) {
        final now = DateTime.now();
        accounts.add(
          KnownAccount(
            pubkeyHex: hex,
            authSource: AuthenticationSource.automatic,
            addedAt: now,
            lastUsedAt: now,
          ),
        );
        Log.info(
          'Legacy migration: recovered automatic keys — pubkey=$hex',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    } catch (e) {
      Log.warning(
        'Legacy migration: failed to check automatic keys: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
    return accounts;
  }

  /// Persists the migration result to seal it permanently.
  Future<void> _persistMigrationResult(
    SharedPreferences prefs,
    List<KnownAccount> accounts,
  ) async {
    await prefs.setString(
      kKnownAccountsKey,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  /// Adds or updates an account in the known accounts registry.
  ///
  /// Called after successful authentication to record which pubkey was used
  /// and which [AuthenticationSource] authenticated it.
  Future<void> _addToKnownAccounts(
    String pubkeyHex,
    AuthenticationSource source,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await getKnownAccounts();
      final now = DateTime.now();

      final index = accounts.indexWhere((a) => a.pubkeyHex == pubkeyHex);
      if (index >= 0) {
        accounts[index] = accounts[index].copyWith(
          authSource: source,
          lastUsedAt: now,
        );
      } else {
        accounts.add(
          KnownAccount(
            pubkeyHex: pubkeyHex,
            authSource: source,
            addedAt: now,
            lastUsedAt: now,
          ),
        );
      }

      final json = jsonEncode(accounts.map((a) => a.toJson()).toList());
      await prefs.setString(kKnownAccountsKey, json);

      Log.info(
        'Updated known accounts registry '
        '(total=${accounts.length}, pubkey=$pubkeyHex, source=${source.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.warning(
        'Failed to update known accounts: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Removes an account from the known accounts registry.
  Future<void> _removeFromKnownAccounts(String pubkeyHex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await getKnownAccounts();
      accounts.removeWhere((a) => a.pubkeyHex == pubkeyHex);

      final json = jsonEncode(accounts.map((a) => a.toJson()).toList());
      await prefs.setString(kKnownAccountsKey, json);

      Log.info(
        'Removed $pubkeyHex from known accounts '
        '(remaining=${accounts.length})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.warning(
        'Failed to remove from known accounts: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Removes an account from the known accounts list and cleans up its
  /// archived signer info. Called from the welcome screen when the user
  /// long-presses to remove an account.
  Future<void> removeKnownAccount(String pubkeyHex) async {
    await _removeFromKnownAccounts(pubkeyHex);
    await _clearArchivedSignerInfo(pubkeyHex);
  }

  /// Pubkey to pre-select on the welcome screen after the next sign-out.
  ///
  /// Set this before calling [signOut] when the user picks a different account
  /// from the account-switcher. [WelcomeBloc] reads and clears this on start.
  String? pendingAccountSwitchPubkey;

  /// Updates [lastUsedAt] for an existing known account without signing in.
  ///
  /// Use this before [signOut] when the user explicitly selects a different
  /// account from the account-switcher, so the welcome screen presents that
  /// account as the pre-selected returning user.
  Future<void> touchKnownAccount(String pubkeyHex) async {
    final accounts = await getKnownAccounts();
    final index = accounts.indexWhere((a) => a.pubkeyHex == pubkeyHex);
    if (index < 0) return;
    final updated = accounts[index].copyWith(lastUsedAt: DateTime.now());
    accounts[index] = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kKnownAccountsKey,
        jsonEncode(accounts.map((a) => a.toJson()).toList()),
      );
    } catch (e) {
      Log.warning(
        'touchKnownAccount: failed to persist for $pubkeyHex: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Per-account signer info archival
  // ---------------------------------------------------------------------------

  /// Copies active-session signer keys to per-account archive keys.
  ///
  /// Called during non-destructive sign-out so the signer info can be
  /// restored when the user picks this account from the welcome screen.
  Future<void> _archiveSignerInfo(String pubkeyHex) async {
    if (_flutterSecureStorage == null) return;
    try {
      // Archive Amber info
      final amberInfo = await _loadAmberInfo();
      if (amberInfo != null) {
        await _flutterSecureStorage.write(
          key: '${_kAmberPubkeyKey}_$pubkeyHex',
          value: amberInfo.pubkey,
        );
        if (amberInfo.package != null) {
          await _flutterSecureStorage.write(
            key: '${_kAmberPackageKey}_$pubkeyHex',
            value: amberInfo.package,
          );
        }
      }

      // Archive Bunker info
      final bunkerUrl = await _flutterSecureStorage.read(key: _kBunkerInfoKey);
      if (bunkerUrl != null && bunkerUrl.isNotEmpty) {
        await _flutterSecureStorage.write(
          key: '${_kBunkerInfoKey}_$pubkeyHex',
          value: bunkerUrl,
        );
      }

      // Archive OAuth session
      final oauthSession = await KeycastSession.load(_flutterSecureStorage);
      if (oauthSession != null) {
        await _flutterSecureStorage.write(
          key: 'keycast_session_$pubkeyHex',
          value: jsonEncode(oauthSession.toJson()),
        );
      }

      Log.info(
        '_archiveSignerInfo: archived for $pubkeyHex — '
        'amber=${amberInfo != null}, '
        'bunker=${bunkerUrl != null && bunkerUrl.isNotEmpty}, '
        'oauth=${oauthSession != null}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.warning(
        '_archiveSignerInfo: failed for $pubkeyHex: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Restores per-account signer keys to the active-session keys.
  ///
  /// Called before sign-in when switching to a previously used account.
  Future<void> _restoreSignerInfo(
    String pubkeyHex,
    AuthenticationSource source,
  ) async {
    if (_flutterSecureStorage == null) return;
    try {
      switch (source) {
        case AuthenticationSource.amber:
          final pubkey = await _flutterSecureStorage.read(
            key: '${_kAmberPubkeyKey}_$pubkeyHex',
          );
          Log.debug(
            '_restoreSignerInfo: amber archive lookup — '
            'found=${pubkey != null}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          if (pubkey != null) {
            await _flutterSecureStorage.write(
              key: _kAmberPubkeyKey,
              value: pubkey,
            );
            final package = await _flutterSecureStorage.read(
              key: '${_kAmberPackageKey}_$pubkeyHex',
            );
            if (package != null) {
              await _flutterSecureStorage.write(
                key: _kAmberPackageKey,
                value: package,
              );
            }
          }

        case AuthenticationSource.bunker:
          final bunkerUrl = await _flutterSecureStorage.read(
            key: '${_kBunkerInfoKey}_$pubkeyHex',
          );
          Log.debug(
            '_restoreSignerInfo: bunker archive lookup — '
            'found=${bunkerUrl != null && bunkerUrl.isNotEmpty}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          if (bunkerUrl != null) {
            await _flutterSecureStorage.write(
              key: _kBunkerInfoKey,
              value: bunkerUrl,
            );
          }

        case AuthenticationSource.divineOAuth:
          final sessionJson = await _flutterSecureStorage.read(
            key: 'keycast_session_$pubkeyHex',
          );
          Log.debug(
            '_restoreSignerInfo: OAuth session archive lookup — '
            'found=${sessionJson != null}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          if (sessionJson != null) {
            final sessionMap = jsonDecode(sessionJson) as Map<String, dynamic>;
            final session = KeycastSession.fromJson(sessionMap);
            await session.save(_flutterSecureStorage);
            // Also restore the refresh token and auth handle to their
            // standalone keys — KeycastOAuth.refreshSession() reads these
            // separately from the session JSON, and _oauthClient.logout()
            // clears them. Without this, expired restored sessions can
            // never be refreshed.
            if (session.refreshToken != null) {
              await _flutterSecureStorage.write(
                key: 'keycast_refresh_token',
                value: session.refreshToken,
              );
            }
            if (session.authorizationHandle != null) {
              await _flutterSecureStorage.write(
                key: 'keycast_auth_handle',
                value: session.authorizationHandle,
              );
            }
          }

        case AuthenticationSource.automatic:
        case AuthenticationSource.importedKeys:
        case AuthenticationSource.none:
          // Clear any stale global signer keys so they don't hijack signing
          // operations for the non-bunker/non-keycast account.
          await _clearBunkerInfo();
          await _clearAmberInfo();
          await KeycastSession.clear(_flutterSecureStorage);
          Log.debug(
            '_restoreSignerInfo: local key-based auth — '
            'cleared stale signer keys',
            name: 'AuthService',
            category: LogCategory.auth,
          );
      }

      // Set the auth source so initialize() picks the right path
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAuthSourceKey, source.code);

      Log.info(
        'Restored signer info for $pubkeyHex (source=${source.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.warning(
        'Failed to restore signer info for $pubkeyHex: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Deletes all per-account archived signer keys for a given pubkey.
  Future<void> _clearArchivedSignerInfo(String pubkeyHex) async {
    if (_flutterSecureStorage == null) return;
    Log.info(
      '_clearArchivedSignerInfo: removing all archives for $pubkeyHex',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    try {
      await _flutterSecureStorage.delete(key: '${_kAmberPubkeyKey}_$pubkeyHex');
      await _flutterSecureStorage.delete(
        key: '${_kAmberPackageKey}_$pubkeyHex',
      );
      await _flutterSecureStorage.delete(key: '${_kBunkerInfoKey}_$pubkeyHex');
      await _flutterSecureStorage.delete(key: 'keycast_session_$pubkeyHex');
    } catch (e) {
      Log.warning(
        '_clearArchivedSignerInfo: failed for $pubkeyHex: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Multi-account sign-in
  // ---------------------------------------------------------------------------

  /// Signs in with a previously used account.
  ///
  /// Restores the signer info for the given [pubkeyHex] based on its
  /// [authSource], then calls the appropriate sign-in path.
  Future<void> signInForAccount(
    String pubkeyHex,
    AuthenticationSource authSource,
  ) async {
    Log.info(
      'signInForAccount: pubkey=$pubkeyHex, source=${authSource.name}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    Log.info(
      'signInForAccount: restoring signer info...',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    await _restoreSignerInfo(pubkeyHex, authSource);

    switch (authSource) {
      case AuthenticationSource.amber:
        Log.info(
          'signInForAccount: loading Amber info for reconnect...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final amberInfo = await _loadAmberInfo();
        if (amberInfo != null) {
          await _reconnectAmber(amberInfo.pubkey, amberInfo.package);
        } else {
          Log.error(
            'signInForAccount: no archived Amber info for $pubkeyHex',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          throw Exception('No archived Amber info found for $pubkeyHex');
        }

      case AuthenticationSource.bunker:
        Log.info(
          'signInForAccount: loading bunker info for reconnect...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final bunkerInfo = await _loadBunkerInfo();
        if (bunkerInfo != null) {
          await _reconnectBunker(bunkerInfo);
        } else {
          Log.error(
            'signInForAccount: no archived bunker info for $pubkeyHex',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          throw Exception('No archived Bunker info found for $pubkeyHex');
        }

      case AuthenticationSource.divineOAuth:
        Log.info(
          'signInForAccount: loading OAuth session for reconnect...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final session = await KeycastSession.load(_flutterSecureStorage);
        if (session != null && session.hasRpcAccess) {
          await signInWithDivineOAuth(session);
        } else if (session != null && session.isExpired) {
          Log.warning(
            'signInForAccount: OAuth session expired for $pubkeyHex',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          throw SessionExpiredException();
        } else {
          Log.error(
            'signInForAccount: no archived OAuth session for $pubkeyHex '
            '(session=${session != null}, '
            'hasRpcAccess=${session?.hasRpcAccess})',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          throw Exception('No archived OAuth session found for $pubkeyHex');
        }

      case AuthenticationSource.importedKeys:
      case AuthenticationSource.automatic:
        // Try to switch to saved identity keys
        final npub = NostrKeyUtils.encodePubKey(pubkeyHex);
        Log.info(
          'signInForAccount: loading identity keys for npub=$npub...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final container = await _keyStorage.getIdentityKeyContainer(npub);
        if (container != null) {
          Log.info(
            'signInForAccount: identity keys found — '
            'pubkey=${container.publicKeyHex}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _keyStorage.switchToIdentity(npub);
          await _setupUserSession(container, authSource);
        } else {
          // Fall back to current primary keys
          Log.warning(
            'signInForAccount: no saved identity keys for $npub — '
            'falling back to _checkExistingAuth',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _checkExistingAuth();
        }

      case AuthenticationSource.none:
        Log.error(
          'signInForAccount: cannot sign in with authSource=none',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        throw Exception('Cannot sign in with auth source "none"');
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
      _authSource = AuthenticationSource.bunker;
      _currentIdentity = _buildIdentity();

      // Create a minimal profile for the bunker user
      final npub = NostrKeyUtils.encodePubKey(userPubkey);
      _currentProfile = UserProfile(
        npub: npub,
        publicKeyHex: userPubkey,
        displayName: NostrKeyUtils.maskKey(npub),
      );

      _setAuthState(AuthState.authenticated);
      _profileController.add(_currentProfile);

      // Register in known accounts
      await _addToKnownAccounts(userPubkey, AuthenticationSource.bunker);

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

      // Log what's already in _keyStorage for debugging identity issues
      final existingContainer = await _keyStorage.getKeyContainer();
      Log.debug(
        'connectWithAmber: amberPubkey=$pubkey, '
        'existingStoredPubkey=${existingContainer?.publicKeyHex ?? "null"}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

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
      return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
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
      _authSource = AuthenticationSource.amber;
      _currentIdentity = _buildIdentity();

      // Create a minimal profile for the Amber user
      final npub = NostrKeyUtils.encodePubKey(pubkey);
      _currentProfile = UserProfile(
        npub: npub,
        publicKeyHex: pubkey,
        displayName: NostrKeyUtils.maskKey(npub),
      );

      _setAuthState(AuthState.authenticated);
      _profileController.add(_currentProfile);

      // Register in known accounts
      await _addToKnownAccounts(pubkey, AuthenticationSource.amber);

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

  /// Import identity from an ncryptsec1 encrypted private key (NIP-49).
  ///
  /// Decrypts [ncryptsec] with [password] using scrypt + XChaCha20-Poly1305,
  /// then imports the recovered private key via [importFromHex].
  ///
  /// Returns [AuthResult.failure] with message 'Incorrect password' if the
  /// password is wrong or the ciphertext is corrupted.
  Future<AuthResult> importFromNcryptsec(
    String ncryptsec,
    String password,
  ) async {
    Log.debug(
      'Importing identity from ncryptsec1 (NIP-49)',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    try {
      final privateKeyHex = await Nip49.decode(ncryptsec, password);
      return importFromHex(privateKeyHex);
    } on Nip49Exception {
      _setAuthState(AuthState.unauthenticated);
      return AuthResult.failure('Incorrect password');
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

    // Default relays for nostrconnect:// connections.
    // Use NIP-46 compatible relays (relay.divine.video rejects Kind 24133).
    // These are public Nostr infrastructure relays — same URLs regardless of
    // app environment (dev/staging/prod).
    final relays =
        customRelays ??
        [
          'wss://relay.nsec.app',
          'wss://relay.damus.io',
          'wss://nos.lol',
          'wss://relay.primal.net',
        ];

    // Create the session
    _nostrConnectSession = NostrConnectSession(
      relays: relays,
      appName: 'Divine',
      appUrl: 'https://divine.video',
      appIcon: 'https://divine.video/icon.png',
      callback: 'divine://nostrconnect',
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

  /// Called when a divine:// signer callback deep link is received.
  ///
  /// Ensures the nostrconnect session relay connections are alive so we
  /// don't miss the bunker's response event after being brought back
  /// from background.
  void onSignerCallbackReceived() {
    if (_nostrConnectSession != null &&
        _nostrConnectSession!.state == NostrConnectState.listening) {
      Log.info(
        'Signer callback received - ensuring nostrconnect relays are connected',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _nostrConnectSession!.ensureConnected();
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
    _hasExpiredOAuthSession = false;

    try {
      _keycastSigner = KeycastRpc.fromSession(_oauthConfig, session);

      final publicKeyHex = await _keycastSigner?.getPublicKey();
      if (publicKeyHex == null) {
        throw Exception('Could not retrieve public key from server');
      }

      _currentProfile = UserProfile(
        npub: NostrKeyUtils.encodePubKey(publicKeyHex),
        publicKeyHex: publicKeyHex,
        displayName: 'Divine User',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_pubkey_hex', publicKeyHex);
      await _clearDismissedDivineLoginBannerForCurrentUser(publicKeyHex);

      Log.info(
        '✅ Divine oauth listener setting auth state to authenticated.',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _profileController.add(_currentProfile);

      final keyContainer = SecureKeyContainer.fromPublicKey(publicKeyHex);
      await _setupUserSession(keyContainer, AuthenticationSource.divineOAuth);
      _setRpcCapability(AuthRpcCapability.rpcReady);

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
      // Get session, refreshing if expired (token may have expired during
      // the NIP-62 deletion step that runs before this call)
      final session = await _oauthClient.getSessionOrRefresh();
      if (session == null || session.accessToken == null) {
        Log.warning(
          'Cannot delete Keycast account: '
          'session unavailable after refresh attempt',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return (false, 'Session expired and could not be refreshed');
      }

      final accessToken = session.accessToken!;

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

  /// Sign out the current user.
  ///
  /// When [deleteKeys] is true, stored keys are removed from the device.
  ///
  /// When [abortOnKeyDeletionFailure] is true (only meaningful with
  /// [deleteKeys]), platform key deletion is attempted **before** any
  /// session cleanup. If deletion fails the method throws immediately and
  /// no cleanup happens — the user stays signed in and can retry.
  /// Use this for the "Remove Keys" flow where signing out without
  /// actually removing keys is counter-productive.
  ///
  /// When [abortOnKeyDeletionFailure] is false (default), key deletion
  /// failure is captured and rethrown **after** all cleanup completes.
  /// Use this for "Delete Account" where sign-out must finish regardless.
  Future<void> signOut({
    bool deleteKeys = false,
    bool abortOnKeyDeletionFailure = false,
  }) async {
    Log.info(
      'signOut: starting — '
      'authSource=${_authSource.name}, '
      'deleteKeys=$deleteKeys, '
      'abortOnKeyDeletionFailure=$abortOnKeyDeletionFailure, '
      'currentPubkey=${_currentKeyContainer?.publicKeyHex ?? "null"}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Pre-flight: when the caller needs key deletion to succeed before
    // sign-out proceeds, attempt it now. If this throws, no cleanup has
    // happened and the user stays signed in.
    if (deleteKeys && abortOnKeyDeletionFailure) {
      await _keyStorage.deleteKeys();
    }

    Object? keyDeletionError;

    try {
      // Clear TOS acceptance on any logout - user must re-accept when logging
      // back in
      final prefs = await SharedPreferences.getInstance();
      // On destructive sign-out, redirect recovery prefs to the next
      // remaining account so initialize() can restore it. Only clear when
      // no accounts remain — otherwise the user loses access to account A
      // after deleting account B.
      // Deferred: the actual redirect runs after _removeFromKnownAccounts
      // so the deleted account is excluded from the remaining list.
      // Non-destructive sign-out (switch account) preserves these so that
      // initialize() can reconnect to the same external signer.
      await prefs.remove('age_verified_16_plus');
      await prefs.remove('terms_accepted_at');

      // Clear user-specific cached data on explicit logout
      await _userDataCleanupService.clearUserSpecificData(
        reason: 'explicit_logout',
      );

      // Clear configured relays so next login re-discovers from NIP-65
      await prefs.remove('configured_relays');

      // Clear relay discovery cache so next login re-queries indexers
      // (even for same-user re-login, relays may have changed)
      await _relayDiscoveryService.clearCache(
        _currentKeyContainer?.npub ?? '',
      );

      // Clear the stored pubkey tracking so next login is treated as new
      await prefs.remove('current_user_pubkey_hex');

      // Multi-account: archive or remove this account's signer info
      final currentPubkey = _currentKeyContainer?.publicKeyHex;
      if (deleteKeys) {
        // Destructive sign-out: remove from known accounts and clean up
        if (currentPubkey != null) {
          await _removeFromKnownAccounts(currentPubkey);
          await _clearArchivedSignerInfo(currentPubkey);
        }

        Log.debug(
          '📱️ Deleting stored keys',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        // Isolate key deletion so that a failure does not short-circuit
        // the remaining cleanup (session, signers, auth state). The error
        // is rethrown after cleanup completes so callers can warn the user.
        // Skip if already handled by the pre-flight check above.
        if (!abortOnKeyDeletionFailure) {
          try {
            await _keyStorage.deleteKeys();
          } catch (e) {
            keyDeletionError = e;
            Log.error(
              'Key deletion failed during signOut: $e',
              name: 'AuthService',
              category: LogCategory.auth,
            );
          }
        }
      } else {
        // Non-destructive sign-out: archive signer info for later restoration
        if (currentPubkey != null) {
          await _archiveSignerInfo(currentPubkey);
        }
        // When the current session used an external signer (Amber/Bunker),
        // local key storage may contain stale keys from a previous identity
        // (e.g., auto-created keys before the user connected Amber).
        // Delete these stale keys to prevent _checkExistingAuth() from
        // auto-signing in with the wrong identity.
        if (_authSource == AuthenticationSource.amber ||
            _authSource == AuthenticationSource.bunker) {
          final storedContainer = await _keyStorage.getKeyContainer();
          Log.debug(
            'signOut: external signer check — '
            'storedKeyPubkey=${storedContainer?.publicKeyHex ?? "null"}, '
            'currentPubkey=${_currentKeyContainer?.publicKeyHex ?? "null"}, '
            'match=${storedContainer?.publicKeyHex == _currentKeyContainer?.publicKeyHex}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          if (storedContainer != null &&
              storedContainer.publicKeyHex !=
                  _currentKeyContainer?.publicKeyHex) {
            Log.debug(
              'signOut: deleting stale local keys from previous identity',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            await _keyStorage.deleteKeys();
          } else {
            Log.debug(
              'signOut: no stale keys detected, clearing cache only',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            _keyStorage.clearCache();
          }
        } else {
          Log.debug(
            'signOut: authSource=${_authSource.name}, clearing cache only',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _keyStorage.clearCache();
        }
      }

      // Clear session
      _currentIdentity = null;
      _currentKeyContainer?.dispose();
      _currentKeyContainer = null;
      _currentProfile = null;
      _lastError = null;

      // Unregister relay-discovery callback so we don't hold a client
      // reference
      _onUserRelaysDiscovered = null;
      _userRelays = [];

      // Clean up bunker signer if active
      if (_bunkerSigner != null) {
        _bunkerSigner!.close();
        _bunkerSigner = null;
        // Only clear persisted connection info on destructive sign-out.
        // Non-destructive sign-out (switch account) preserves it so
        // "Log back in" can reconnect.
        if (deleteKeys) {
          await _clearBunkerInfo();
        }
      }

      // Clean up Amber signer if active
      if (_amberSigner != null) {
        _amberSigner!.close();
        _amberSigner = null;
        // Only clear persisted connection info on destructive sign-out.
        // Non-destructive sign-out (switch account) preserves it so
        // "Log back in" can reconnect.
        if (deleteKeys) {
          await _clearAmberInfo();
        }
      }

      // Clean up Keycast RPC signer if active
      _keycastSigner = null;

      try {
        if (_oauthClient != null) {
          await _oauthClient.logout();
        } else {
          await KeycastSession.clear(_flutterSecureStorage);
        }
      } catch (_) {}

      // Clear any pending verification data
      // (fire-and-forget since it's best-effort)
      unawaited(_pendingVerificationService?.clear());

      // Redirect recovery prefs AFTER all signer cleanup so that
      // _restoreSignerInfo can re-stage the remaining account's archived
      // session without it being wiped by _oauthClient.logout() above.
      if (deleteKeys) {
        await _redirectRecoveryToRemainingAccount(prefs);
      }

      _setAuthState(AuthState.unauthenticated);

      // Post-signout verification: confirm key storage state
      try {
        final postSignOutHasKeys = await _keyStorage.hasKeys();
        Log.info(
          'signOut complete — '
          'keyStorageHasKeys=$postSignOutHasKeys, '
          'authSource=${_authSource.name}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } catch (_) {
        Log.info(
          'signOut complete',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    } catch (e) {
      Log.error(
        'Error during sign out: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Sign out failed: $e';
    }

    // After all cleanup, propagate key deletion failure so callers can
    // warn the user that keys may still be on the device.
    if (keyDeletionError != null) {
      throw SecureKeyStorageException(
        'Signed out but key deletion failed: $keyDeletionError',
      );
    }
  }

  /// After destructive sign-out, point [_kLastUsedNpubKey] and
  /// [_kAuthSourceKey] at the most recently used remaining known account
  /// so that [initialize] can restore it on next launch.  If no accounts
  /// remain, both prefs are cleared (fresh-install behaviour).
  ///
  /// For OAuth/bunker/amber accounts this also calls [_restoreSignerInfo]
  /// to pre-stage the archived session into the active slot. This must
  /// run AFTER [_oauthClient.logout()] / [KeycastSession.clear()] so the
  /// restored session is not immediately wiped.
  Future<void> _redirectRecoveryToRemainingAccount(
    SharedPreferences prefs,
  ) async {
    try {
      final remaining = await getKnownAccounts();
      if (remaining.isEmpty) {
        await prefs.remove(_kAuthSourceKey);
        await prefs.remove(_kLastUsedNpubKey);
        Log.info(
          'signOut: no remaining accounts — cleared recovery prefs',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }

      // Pick the most recently used account.
      remaining.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      final next = remaining.first;
      final nextNpub = NostrKeyUtils.encodePubKey(next.pubkeyHex);

      await prefs.setString(_kLastUsedNpubKey, nextNpub);
      await prefs.setString(_kAuthSourceKey, next.authSource.code);

      // Pre-stage the remaining account's archived signer info into the
      // active slots so initialize() can find it.  For divineOAuth this
      // restores the KeycastSession, for bunker/amber the connection info.
      await _restoreSignerInfo(next.pubkeyHex, next.authSource);

      Log.info(
        'signOut: redirected recovery to remaining account '
        'pubkey=${next.pubkeyHex}, source=${next.authSource.name}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      // Best-effort: if this fails, the fallback scan in
      // _restoreLastUsedAccountOrFallback will still find the account.
      Log.warning(
        'signOut: failed to redirect recovery prefs: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      await prefs.remove(_kAuthSourceKey);
      await prefs.remove(_kLastUsedNpubKey);
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

      // Use the in-memory key container when available to avoid re-reading
      // from platform storage. iOS keychain can fail transiently, causing
      // "Unable to access your keys" errors even though the key is in RAM.
      // Falls back to storage read if the container isn't loaded yet.
      final container = _currentKeyContainer;
      if (container != null && container.hasPrivateKey) {
        return container.withNsec((nsec) => nsec);
      }

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
    final identity = _currentIdentity;
    if (!isAuthenticated || identity == null) {
      Log.error(
        'Cannot sign event - user not authenticated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }

    try {
      // 1. Prepare event metadata and tags
      // CRITICAL: Divine relays require specific tags for storage
      final eventTags = List<List<String>>.from(tags ?? []);

      // CRITICAL: Kind 0 events require expiration tag FIRST (matching Python
      // script order)
      if (kind == 0) {
        final expirationTimestamp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
            (72 * 60 * 60); // 72 hours
        eventTags.add(['expiration', expirationTimestamp.toString()]);
      }

      // Create the unsigned event with the identity's pubkey — both the
      // pubkey and the signing key come from the same identity instance,
      // structurally preventing the PRIMARY-slot desync bug (#2233).
      final driftTolerance = NostrTimestamp.getDriftToleranceForKind(kind);
      final event = Event(
        identity.pubkey,
        kind,
        eventTags,
        content,
        createdAt:
            createdAt ?? NostrTimestamp.now(driftTolerance: driftTolerance),
      );

      // 2. Sign via the identity — delegates to the correct signer
      Log.info(
        'Signing kind $kind via ${identity.runtimeType} '
        '(authSource=${_authSource.name}, '
        'eventPubkey=${event.pubkey})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      final signedEvent = await identity.signEvent(event);

      // 3. Post-Signing Validation
      if (signedEvent == null) {
        Log.error(
          'Signing failed: Signer returned null',
          name: 'AuthService',
        );
        return null;
      }

      if (!signedEvent.isSigned) {
        Log.error(
          'Event signature validation FAILED! '
          'kind=$kind, eventPubkey=${signedEvent.pubkey}, '
          'authSource=${_authSource.name}, '
          'identityPubkey=${identity.pubkey}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return null;
      }

      if (!signedEvent.isValid) {
        Log.error(
          'Event structure validation FAILED! '
          'Event ID does not match computed hash',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return null;
      }

      Log.info(
        'Event signed and validated: ${signedEvent.id}',
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

  /// Restores the last-used account's per-identity key, falling back to
  /// [_checkExistingAuth] when the pref is absent or the key is missing.
  Future<void> _restoreLastUsedAccountOrFallback(
    AuthenticationSource source,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastNpub = prefs.getString(_kLastUsedNpubKey);

      if (lastNpub != null && lastNpub.isNotEmpty) {
        Log.info(
          '_restoreLastUsedAccountOrFallback: '
          'found last-used npub, loading identity key...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final cachedPrimaryIdentity = _restoreFromLoadedPrimaryIdentity(
          lastNpub,
        );
        if (cachedPrimaryIdentity != null) {
          Log.info(
            '_restoreLastUsedAccountOrFallback: '
            'reused already-loaded primary identity — '
            'pubkey=${cachedPrimaryIdentity.publicKeyHex}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _setupUserSession(cachedPrimaryIdentity, source);
          return;
        }
        final container = await _keyStorage.getIdentityKeyContainer(lastNpub);
        if (container != null) {
          Log.info(
            '_restoreLastUsedAccountOrFallback: '
            'identity key found — pubkey=${container.publicKeyHex}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _setupUserSession(container, source);
          return;
        }
        Log.warning(
          '_restoreLastUsedAccountOrFallback: '
          'identity key absent for last-used npub — falling back',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } else {
        Log.info(
          '_restoreLastUsedAccountOrFallback: '
          'no last-used npub stored — falling back to _checkExistingAuth',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    } catch (e, stack) {
      Log.warning(
        '_restoreLastUsedAccountOrFallback: error reading last-used npub: $e '
        '— falling back to _checkExistingAuth',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _reportStorageError(e, stack, '_restoreLastUsedAccountOrFallback');
    }

    // Before falling through to _checkExistingAuth (which only checks
    // PRIMARY storage), scan known accounts for per-identity keys.
    // This covers the case where signOut(deleteKeys:true) wiped PRIMARY
    // but another account's keys still exist in per-identity storage.
    if (await _tryRestoreFromKnownAccounts(source)) return;

    // Fall back to the original behaviour (load primary key, or create new).
    await _checkExistingAuth();
  }

  /// Scans known accounts and attempts to restore the first one that has
  /// restorable credentials.  For local-key accounts this checks per-identity
  /// key containers; for OAuth/bunker/amber it delegates to [signInForAccount]
  /// which restores archived signer info and triggers the appropriate flow.
  /// Returns true if an account was restored, false otherwise.
  Future<bool> _tryRestoreFromKnownAccounts(
    AuthenticationSource source,
  ) async {
    try {
      final accounts = await getKnownAccounts();
      if (accounts.isEmpty) return false;

      // Try most recently used first.
      accounts.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      for (final account in accounts) {
        // OAuth, bunker, and amber accounts don't store per-identity local
        // keys — they rely on archived signer info.  Use signInForAccount
        // which handles _restoreSignerInfo + the source-specific sign-in.
        if (account.authSource == AuthenticationSource.divineOAuth ||
            account.authSource == AuthenticationSource.bunker ||
            account.authSource == AuthenticationSource.amber) {
          try {
            Log.info(
              '_tryRestoreFromKnownAccounts: '
              'trying signInForAccount for ${account.pubkeyHex} '
              '(source=${account.authSource.name})',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            await signInForAccount(account.pubkeyHex, account.authSource);
            return true;
          } catch (e) {
            Log.warning(
              '_tryRestoreFromKnownAccounts: '
              'signInForAccount failed for ${account.pubkeyHex}: $e',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            continue;
          }
        }

        // Local-key accounts: look for per-identity key containers.
        final npub = NostrKeyUtils.encodePubKey(account.pubkeyHex);
        final container = await _keyStorage.getIdentityKeyContainer(npub);
        if (container != null) {
          Log.info(
            '_tryRestoreFromKnownAccounts: '
            'found keys for ${account.pubkeyHex} '
            '(source=${account.authSource.name})',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _keyStorage.switchToIdentity(npub);
          await _setupUserSession(container, account.authSource);
          return true;
        }
      }
      Log.info(
        '_tryRestoreFromKnownAccounts: '
        'no restorable account found among known accounts',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.warning(
        '_tryRestoreFromKnownAccounts: scan failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
    return false;
  }

  SecureKeyContainer? _restoreFromLoadedPrimaryIdentity(String lastNpub) {
    final keyManager = _nostrKeyManager;
    final publicKeyHex = keyManager?.publicKey;
    final privateKeyHex = keyManager?.privateKey;

    if (publicKeyHex == null || privateKeyHex == null) {
      return null;
    }

    final primaryNpub = NostrKeyUtils.encodePubKey(publicKeyHex);
    if (primaryNpub != lastNpub) {
      return null;
    }

    try {
      return SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
    } catch (e) {
      Log.warning(
        '_restoreFromLoadedPrimaryIdentity: failed to reuse loaded identity: '
        '$e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Check for existing authentication
  Future<void> _checkExistingAuth() async {
    // If storage already failed once, the user saw the error and chose to
    // continue anyway. Skip the storage check and continue as
    // unauthenticated (same as a fresh install).
    if (_storageErrorOccurred) {
      Log.info(
        'Storage previously failed — user chose to continue. '
        'Proceeding unauthenticated as fresh install.',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _storageErrorOccurred = false;
      _lastError = null;
      _setAuthState(AuthState.unauthenticated);
      return;
    } else {
      // Step 1: Check if keys exist in storage.
      // Keep this separate so storage errors don't silently fall through
      // to creating a new identity (which would overwrite the existing key).
      bool hasKeys;
      try {
        hasKeys = await _keyStorage.hasKeys();
      } catch (e, stack) {
        Log.error(
          'Secure storage error while checking for keys: $e. '
          'NOT creating a new identity to avoid overwriting existing keys. '
          'User will need to re-import their key.',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        _reportStorageError(e, stack, '_checkExistingAuth hasKeys()');
        _storageErrorOccurred = true;
        _lastError =
            "Couldn't load your saved identity from this device. "
            'Sign in with your existing account, or continue '
            'to create a new one.';
        _setAuthState(AuthState.unauthenticated);
        return;
      }

      Log.debug(
        '_checkExistingAuth: hasKeys=$hasKeys',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // Step 2: If keys exist, try to load them
      if (hasKeys) {
        Log.info(
          'Found existing secure keys, loading saved identity...',
          name: 'AuthService',
          category: LogCategory.auth,
        );

        try {
          final keyContainer = await _keyStorage.getKeyContainer();
          if (keyContainer != null) {
            Log.info(
              '_checkExistingAuth: loading identity '
              'pubkey=${keyContainer.publicKeyHex}',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            await _setupUserSession(
              keyContainer,
              AuthenticationSource.automatic,
            );
            return;
          }
        } catch (e, stack) {
          Log.error(
            'Failed to load key container from storage: $e. '
            'NOT creating a new identity to avoid overwriting existing keys.',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _reportStorageError(e, stack, '_checkExistingAuth getKeyContainer()');
          _storageErrorOccurred = true;
          _lastError =
              "Couldn't load your saved identity from this device. "
              'Sign in with your existing account, or continue '
              'to create a new one.';
          _setAuthState(AuthState.unauthenticated);
          return;
        }

        // hasKeys() true but getKeyContainer() returned null — storage
        // inconsistency. Don't overwrite, let user re-import.
        Log.error(
          'Has keys flag set but could not load secure key container. '
          'NOT creating a new identity to avoid overwriting existing keys.',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        _reportStorageError(
          StateError('hasKeys() true but getKeyContainer() returned null'),
          StackTrace.current,
          '_checkExistingAuth storage inconsistency',
        );
        _storageErrorOccurred = true;
        _lastError =
            "Couldn't load your saved identity from this device. "
            'Sign in with your existing account, or continue '
            'to create a new one.';
        _setAuthState(AuthState.unauthenticated);
        return;
      }
    } // end else (no prior storage error)

    // Step 3: Genuinely no keys — fresh install, wait for onboarding
    Log.info(
      'No existing secure keys found, staying unauthenticated for onboarding.',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    _setAuthState(AuthState.unauthenticated);
  }

  Future<void> acceptTerms() async {
    Log.debug(
      'acceptTerms: marking terms accepted and age verified',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'terms_accepted_at',
      DateTime.now().toIso8601String(),
    );
    await prefs.setBool('age_verified_16_plus', true);
  }

  /// Builds a [NostrIdentity] from the current mutable signer fields.
  ///
  /// Must be called AFTER signer fields (_keycastSigner, _bunkerSigner,
  /// _amberSigner) and _currentKeyContainer have been set for the session.
  ///
  /// Throws [StateError] if no valid identity can be constructed — this
  /// indicates a programming error in the auth flow, not a user-facing
  /// condition.
  NostrIdentity _buildIdentity() {
    final keyContainer = _currentKeyContainer;
    if (keyContainer == null) {
      throw StateError(
        '_buildIdentity called with no key container. '
        'Auth flow must set _currentKeyContainer before building identity.',
      );
    }

    final pubkey = keyContainer.publicKeyHex;

    // Priority matches rpcSigner: Amber > Bunker > Keycast > Local
    if (_amberSigner case final signer?) {
      return AmberNostrIdentity(pubkey: pubkey, amberSigner: signer);
    }
    if (_bunkerSigner case final signer?) {
      return BunkerNostrIdentity(pubkey: pubkey, remoteSigner: signer);
    }
    if (_keycastSigner case final rpc?) {
      // When a matching local nsec exists, sign locally for speed.
      LocalKeySigner? localSigner;
      if (keyContainer.hasPrivateKey) {
        localSigner = LocalKeySigner(keyContainer);
      }
      return KeycastNostrIdentity(
        pubkey: pubkey,
        rpcSigner: rpc,
        localSigner: localSigner,
      );
    }
    // Local keys only — private key required.
    if (keyContainer.hasPrivateKey) {
      if (_authSource == AuthenticationSource.divineOAuth) {
        Log.warning(
          '_buildIdentity: falling back to LocalNostrIdentity for '
          'divineOAuth source — OAuth session likely expired',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
      return LocalNostrIdentity(keyContainer: keyContainer);
    }
    // Pub-key-only container with no remote signer — cannot sign.
    throw StateError(
      '_buildIdentity: pub-key-only container with no remote signer. '
      'source=${_authSource.name}, pubkey=$pubkey',
    );
  }

  /// Set up user session after successful authentication
  Future<void> _setupUserSession(
    SecureKeyContainer keyContainer,
    AuthenticationSource source,
  ) async {
    Log.info(
      '_setupUserSession: starting — '
      'pubkey=${keyContainer.publicKeyHex}, source=${source.name}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _currentKeyContainer = keyContainer;
    _authSource = source;

    // Clear any stale remote signers that don't match the new auth source.
    // This prevents a Keycast RPC signer from a previous Divine OAuth session
    // from being used when signing events for an anonymous/imported-key account.
    if (source != AuthenticationSource.divineOAuth) {
      if (_keycastSigner != null) {
        Log.info(
          '_setupUserSession: clearing stale Keycast signer '
          '(new source=${source.name})',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        _keycastSigner = null;
      }
    }
    if (source != AuthenticationSource.bunker && _bunkerSigner != null) {
      Log.info(
        '_setupUserSession: clearing stale bunker signer '
        '(new source=${source.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _bunkerSigner!.close();
      _bunkerSigner = null;
    }
    if (source != AuthenticationSource.amber && _amberSigner != null) {
      Log.info(
        '_setupUserSession: clearing stale amber signer '
        '(new source=${source.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _amberSigner!.close();
      _amberSigner = null;
    }

    // Build atomic identity AFTER stale signers are cleared.
    _currentIdentity = _buildIdentity();

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
        Log.info(
          '_setupUserSession: identity change detected — '
          'clearing user-specific data',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        await _userDataCleanupService.clearUserSpecificData(
          reason: 'identity_change',
          isIdentityChange: true,
        );
        // restore the TOS acceptance since we wouldn't be here otherwise
        await acceptTerms();
      } else {
        Log.debug(
          '_setupUserSession: same identity — no data cleanup needed',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
      await prefs.setString(
        'current_user_pubkey_hex',
        keyContainer.publicKeyHex,
      );

      await prefs.setString(_kAuthSourceKey, source.code);

      await prefs.setString(_kLastUsedNpubKey, keyContainer.npub);

      final followingCacheKey = 'following_list_${keyContainer.publicKeyHex}';
      final hasFollowingCache = prefs.containsKey(followingCacheKey);

      // Pre-fetch following list from REST API BEFORE setting auth state.
      // The router redirect fires synchronously on auth state change and reads
      // following_list_{pubkey} from SharedPreferences. If the cache is empty
      // (identity change cleared it, or first login), the redirect sends the
      // user to /explore instead of /home. By fetching here, we ensure the
      // cache is populated before the redirect fires.
      if (_preFetchFollowing != null && !hasFollowingCache) {
        Log.debug(
          '_setupUserSession: pre-fetching following list...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        try {
          await _preFetchFollowing(keyContainer.publicKeyHex);
          Log.debug(
            '_setupUserSession: following list pre-fetched',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        } catch (e) {
          Log.warning(
            'Pre-fetch following list failed (will rely on '
            'FollowRepository): $e',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        }
      } else if (hasFollowingCache) {
        Log.debug(
          '_setupUserSession: following list already cached — '
          'skipping pre-fetch',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      Log.info(
        '_setupUserSession: setting auth state to authenticated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _setAuthState(AuthState.authenticated);

      // Register this account in the known accounts list
      await _addToKnownAccounts(keyContainer.publicKeyHex, source);

      // Store identity keys for multi-account switching
      try {
        await _keyStorage.storeIdentityKeyContainer(
          keyContainer.npub,
          keyContainer,
        );
        Log.debug(
          '_setupUserSession: identity keys stored for multi-account',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } catch (e) {
        // Best-effort — external signers may not have local keys to store
        Log.debug(
          '_setupUserSession: could not store identity keys '
          '(expected for external signers): $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

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

  /// Perform all discovery operations using direct WebSocket connections.
  ///
  /// Discovery services (relay + blossom) open their own WebSocket connections
  /// to indexer relays - no temporary NostrClient is needed. This eliminates
  /// the fragile temp client that previously caused silent failures when
  /// relay.divine.video was slow to connect or interfered with storage.
  ///
  /// For the profile check, we query indexer relays directly since they also
  /// index kind 0 events.
  ///
  /// For returning users, this runs in background via unawaited().
  Future<void> _performDiscovery() async {
    if (_currentKeyContainer == null) return;

    final npub = _currentKeyContainer!.npub;

    Log.info(
      '🔍 Starting user discovery (relays + profile)...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    try {
      // Run discoveries in parallel - each service manages its own WebSocket
      // connections to indexer relays. No temp NostrClient needed.
      await Future.wait([_discoverUserRelays(npub), _checkExistingProfile()]);
    } catch (e) {
      Log.warning(
        '⚠️ Discovery failed: $e - using default fallbacks',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _userRelays = [];
      _hasExistingProfile = false;
    }

    Log.info(
      '📊 Discovery complete: relays=${_userRelays.length}, '
      'hasExistingProfile=$_hasExistingProfile',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }

  /// Discover user relays via NIP-65 using direct WebSocket to indexers.
  ///
  /// Always runs discovery (with 24h cache to avoid redundant indexer queries).
  /// Discovered relays are ADDED to the main client's existing connections,
  /// so user's manual relay edits are preserved (addRelay skips duplicates).
  ///
  /// When discovery returns empty or fails (e.g. imported account that
  /// never published a kind 10002 list), [IndexerRelayConfig.safeFallbackRelays]
  /// is added to the client's connected pool so DM reachability degrades
  /// gracefully instead of leaving the client connected only to the Divine
  /// relay. The fallback set is NOT stored in [userRelays] — that getter
  /// continues to report only the user's own published relays so embedded
  /// Nostr apps querying via the bridge see accurate data. See #2931.
  Future<void> _discoverUserRelays(String npub) async {
    try {
      final result = await _relayDiscoveryService.discoverRelays(npub);

      if (result.success && result.hasRelays) {
        _userRelays = result.relays;

        Log.info(
          '✅ Discovered ${_userRelays.length} user relays from '
          '${result.foundOnIndexer ?? "cache"}',
          name: 'AuthService',
          category: LogCategory.auth,
        );

        // Log relay details
        for (final relay in _userRelays) {
          Log.info(
            '  - ${relay.url} (read: ${relay.read}, write: ${relay.write})',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        }

        // Notify NostrService so it can add these relays to the current client
        final urls = _userRelays.map((r) => r.url).toList();
        _onUserRelaysDiscovered?.call(urls);
      } else {
        _userRelays = [];

        Log.warning(
          '⚠️ No relay list found for user on any indexer — '
          'connecting to safe DM-friendly fallback relay set',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        _connectToFallbackRelays();
      }
    } catch (e) {
      _userRelays = [];

      Log.error(
        '❌ Relay discovery failed: $e — '
        'connecting to safe DM-friendly fallback relay set',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _connectToFallbackRelays();
    }
  }

  /// Notify the NostrService callback to connect the client to
  /// [IndexerRelayConfig.safeFallbackRelays].
  ///
  /// Used when NIP-65 discovery returns empty or fails. Without this, the
  /// client stays connected only to the Divine relay, which silently
  /// breaks NIP-17 DM delivery for peers writing on other relays.
  ///
  /// Intentionally does NOT mutate [_userRelays]: that field semantically
  /// represents the user's *own* published relay list (kind 10002) and is
  /// surfaced to embedded Nostr apps via the bridge. The fallback set is a
  /// reachability mechanism, not a relay list the user has chosen. See #2931.
  void _connectToFallbackRelays() {
    Log.info(
      'Fallback relays: '
      '${IndexerRelayConfig.safeFallbackRelays.join(', ')}',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    _onUserRelaysDiscovered?.call(IndexerRelayConfig.safeFallbackRelays);
  }

  /// Test seam exposing the private NIP-65 discovery routine so unit
  /// tests can drive the fallback path with a mocked discovery service.
  /// Production callers should not invoke this — discovery runs as part
  /// of the normal sign-in flow via [_setupUserSession].
  @visibleForTesting
  Future<void> debugDiscoverUserRelays(String npub) =>
      _discoverUserRelays(npub);

  /// Check if user has an existing profile (kind 0) on indexer relays.
  ///
  /// Uses a direct WebSocket connection to an indexer relay (purplepag.es
  /// indexes kind 0 events) to check for existing profiles.
  Future<void> _checkExistingProfile() async {
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
      final pubkeyHex = _currentKeyContainer!.publicKeyHex;
      final indexerUrl =
          _profileCheckIndexerUrl ?? IndexerRelayConfig.defaultIndexers.first;

      final relayStatus = RelayStatus(indexerUrl);
      final relay = RelayBase(indexerUrl, relayStatus);
      final completer = Completer<bool>();
      final subscriptionId = 'pc_${DateTime.now().millisecondsSinceEpoch}';

      relay.onMessage = (relay, json) async {
        if (json.isEmpty) return;
        final messageType = json[0] as String;
        if (messageType == 'EVENT' && json.length >= 3) {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        } else if (messageType == 'EOSE') {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        }
      };

      final filter = <String, dynamic>{
        'kinds': <int>[0],
        'authors': <String>[pubkeyHex],
        'limit': 1,
      };
      relay.pendingMessages.add(<dynamic>['REQ', subscriptionId, filter]);

      final connected = await relay.connect();
      if (!connected) {
        _hasExistingProfile = false;
        return;
      }

      try {
        _hasExistingProfile = await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () => false,
        );
        await relay.send(<dynamic>['CLOSE', subscriptionId]);
      } finally {
        try {
          await relay.disconnect();
        } catch (_) {}
      }

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
      final previousState = _authState;
      _authState = newState;
      _authStateController.add(newState);

      Log.info(
        'Auth state: ${previousState.name} -> ${newState.name}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  void _setRpcCapability(AuthRpcCapability capability) {
    if (_authRpcCapability != capability) {
      final previous = _authRpcCapability;
      _authRpcCapability = capability;
      _rpcCapabilityController.add(capability);

      Log.info(
        'RPC capability: ${previous.name} -> ${capability.name}',
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

    // Reconnect nostrconnect:// session relays that may have dropped
    // while the app was in the background (e.g. user switched to Primal
    // to approve the connection on Android).
    if (_nostrConnectSession != null &&
        _nostrConnectSession!.state == NostrConnectState.listening) {
      Log.info(
        '📱 App resumed - reconnecting nostrconnect session relays',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _nostrConnectSession!.ensureConnected();
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
    await _rpcCapabilityController.close();
    _keyStorage.dispose();
  }
}
