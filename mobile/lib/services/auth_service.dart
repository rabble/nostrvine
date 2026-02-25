// ABOUTME: Authentication service managing user login, key generation, and
// auth state
// ABOUTME: Handles Nostr identity creation, import, and session management
// with secure storage

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer, SecureKeyStorage;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/models/known_account.dart';
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

/// Callback invoked when NIP-65 relay discovery completes with a non-empty list.
/// Used by NostrService to add discovered relays to the current client without
/// blocking app startup.
typedef UserRelaysDiscoveredCallback = void Function(List<String> relayUrls);

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
  bool _storageErrorOccurred = false;
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

  /// Callback registered by NostrService to add discovered relays to the client
  /// when discovery completes (avoids race where client is built before discovery).
  UserRelaysDiscoveredCallback? _onUserRelaysDiscovered;

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
          // Try to load authorized session from secure storage
          Log.info(
            'initialize: restoring Divine OAuth session...',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          final session = await KeycastSession.load(_flutterSecureStorage);
          if (session != null && session.hasRpcAccess) {
            Log.info(
              'initialize: Divine OAuth session found with RPC access',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            await signInWithDivineOAuth(session);
            return;
          }
          // session not restored — fall back to unauthenticated
          Log.warning(
            'initialize: Divine OAuth session not restored '
            '(session=${session != null}, '
            'hasRpcAccess=${session?.hasRpcAccess})',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _setAuthState(AuthState.unauthenticated);
          return;

        case AuthenticationSource.importedKeys:
          // Only restore if secure keys exist
          Log.info(
            'initialize: restoring imported keys...',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          try {
            final hasKeys = await _keyStorage.hasKeys();
            if (hasKeys) {
              final keyContainer = await _keyStorage.getKeyContainer();
              if (keyContainer != null) {
                Log.info(
                  'initialize: imported keys found — '
                  'pubkey=${keyContainer.publicKeyHex}',
                  name: 'AuthService',
                  category: LogCategory.auth,
                );
                await _setupUserSession(
                  keyContainer,
                  AuthenticationSource.importedKeys,
                );
                return;
              }
              Log.error(
                'Imported keys: hasKeys() true but getKeyContainer() '
                'returned null — possible storage corruption',
                name: 'AuthService',
                category: LogCategory.auth,
              );
              _reportStorageError(
                StateError(
                  'hasKeys() true but getKeyContainer() returned null',
                ),
                StackTrace.current,
                'importedKeys storage inconsistency',
              );
            }
          } catch (e, stack) {
            Log.error(
              'Secure storage error loading imported keys: $e. '
              'User will need to re-import their key.',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            _reportStorageError(e, stack, 'importedKeys load');
            _lastError =
                "Couldn't load your saved identity from this device. "
                'Sign in with your existing account, or continue '
                'to create a new one.';
          }
          _setAuthState(AuthState.unauthenticated);
          return;

        case AuthenticationSource.automatic:
          // Default behavior: check for keys and auto-create if needed
          await _checkExistingAuth();

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
          }

        case AuthenticationSource.automatic:
        case AuthenticationSource.importedKeys:
        case AuthenticationSource.none:
          Log.debug(
            '_restoreSignerInfo: local key-based auth — '
            'no signer info to restore',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          break;
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
      appName: 'diVine',
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
    Log.info(
      'signOut: starting — '
      'authSource=${_authSource.name}, '
      'deleteKeys=$deleteKeys, '
      'currentPubkey=${_currentKeyContainer?.publicKeyHex ?? "null"}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    try {
      // Clear TOS acceptance on any logout - user must re-accept when logging
      // back in
      final prefs = await SharedPreferences.getInstance();
      // Only clear the auth source on destructive sign-out. Non-destructive
      // sign-out (switch account) preserves it so that initialize() can
      // reconnect to the same external signer (Amber/Bunker) when the user
      // returns.
      if (deleteKeys) {
        await prefs.remove(_kAuthSourceKey);
      }
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
      await _relayDiscoveryService.clearCache(_currentKeyContainer?.npub ?? '');

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
        await _keyStorage.deleteKeys();
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
      _currentKeyContainer?.dispose();
      _currentKeyContainer = null;
      _currentProfile = null;
      _lastError = null;

      // Unregister relay-discovery callback so we don't hold a client reference
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
          _oauthClient.logout();
        } else {
          await KeycastSession.clear(_flutterSecureStorage);
        }
      } catch (_) {}

      // Clear any pending verification data
      // (fire-and-forget since it's best-effort)
      unawaited(_pendingVerificationService?.clear());

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
        Log.info(
          '🚀 Signing kind $kind via Remote RPC '
          '(authSource=${_authSource.name}, '
          'eventPubkey=${event.pubkey})',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        signedEvent = await rpcSigner.signEvent(event);
      } else {
        Log.info(
          '🔐 Signing kind $kind via Local Secure Storage '
          '(authSource=${_authSource.name}, '
          'eventPubkey=${event.pubkey})',
          name: 'AuthService',
          category: LogCategory.auth,
        );
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
          '❌ Event signature validation FAILED! '
          'kind=$kind, eventPubkey=${signedEvent.pubkey}, '
          'authSource=${_authSource.name}, '
          'currentPubkey=${_currentKeyContainer?.publicKeyHex}',
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
    // If storage already failed once, the user saw the error and chose to
    // continue anyway. Skip the storage check and create a new identity
    // (same as a fresh install).
    if (_storageErrorOccurred) {
      Log.info(
        'Storage previously failed — user chose to continue. '
        'Creating new identity as fresh install.',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _storageErrorOccurred = false;
      _lastError = null;
      // Fall through to step 3 (create new identity) below
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

    // Step 3: Genuinely no keys — fresh install, create new identity
    Log.info(
      'No existing secure keys found, creating new identity automatically...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    try {
      final result = await createNewIdentity();
      if (result.success && result.keyContainer != null) {
        Log.info(
          'Auto-created NEW secure Nostr identity: '
          '${NostrKeyUtils.maskKey(result.keyContainer!.npub)}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } else {
        Log.error(
          'Failed to auto-create identity: ${result.errorMessage}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        _setAuthState(AuthState.unauthenticated);
      }
    } catch (e) {
      Log.error(
        'Error creating new identity: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _setAuthState(AuthState.unauthenticated);
    }
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
    // This prevents a Keycast RPC signer from a previous divine OAuth session
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

      // Pre-fetch following list from REST API BEFORE setting auth state.
      // The router redirect fires synchronously on auth state change and reads
      // following_list_{pubkey} from SharedPreferences. If the cache is empty
      // (identity change cleared it, or first login), the redirect sends the
      // user to /explore instead of /home. By fetching here, we ensure the
      // cache is populated before the redirect fires.
      if (_preFetchFollowing != null) {
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
          '⚠️ No relay list found for user on any indexer',
          name: 'AuthService',
          category: LogCategory.auth,
        );
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
      final indexerUrl = IndexerRelayConfig.defaultIndexers.first;

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
    _keyStorage.dispose();
  }
}
