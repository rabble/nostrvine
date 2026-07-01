// ABOUTME: Authentication service managing user login, key generation, and
// auth state
// ABOUTME: Handles Nostr identity creation, import, and session management
// with secure storage

import 'dart:async';
import 'dart:convert';

import 'package:cache_sync/cache_sync.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_client/nostr_client.dart' show Nip89ClientTag;
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer, SecureKeyStorage, SecureKeyStorageException;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/local_key_signer.dart';
import 'package:openvine/services/nip07_service.dart';
import 'package:openvine/services/nip07_signer_adapter.dart';
import 'package:openvine/services/nostr_identity.dart';
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

// Key for the session recovery anchor: the npub that was actively signed in at
// the time of the most recent sign-out. Written at the start of signOut() so
// the welcome screen can detect cross-account cold-start restores and surface
// a confirmation banner before silently completing a switch. Cleared by
// _setupUserSession() once the user has explicitly signed back in.
const _kSessionRecoveryAnchorKey = 'session_recovery_anchor_npub';

// Keys for bunker connection persistence
const _kBunkerInfoKey = 'bunker_info';

// Keys for Amber (NIP-55) connection persistence
const _kAmberPubkeyKey = 'amber_pubkey';
const _kAmberPackageKey = 'amber_package';

// Keys for Keycast OAuth persistence
const _kKeycastRefreshTokenKey = 'keycast_refresh_token';
const _kKeycastAuthHandleKey = 'keycast_auth_handle';
String _keycastSessionKey(String pubkeyHex) => 'keycast_session_$pubkeyHex';

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

/// Thrown when a signer returns an event whose author public key does not
/// match the active identity.
///
/// A signing-layer invariant violation: a signer must never produce an event
/// for a different account than the one that requested signing. Reported to
/// Crashlytics via [Reportable] (YES on the error-handling matrix), and the
/// caller fails the publish closed. Carries hex pubkeys only (no npub/nsec),
/// so it is safe for the [Reportable] sanitizer.
class EventSignerAccountMismatchException implements Exception {
  const EventSignerAccountMismatchException({
    required this.expectedPubkey,
    required this.actualPubkey,
  });

  /// The active identity's public key (hex) the event was created with.
  final String expectedPubkey;

  /// The public key (hex) the signer returned on the signed event.
  final String actualPubkey;

  @override
  String toString() =>
      'EventSignerAccountMismatchException: signer returned an event for '
      '$actualPubkey but the active identity is $expectedPubkey';
}

/// Thrown by [AuthService.signInForAccount] when a returning-user sign-in
/// does not restore the requested account — for example when an
/// `importedKeys`/`automatic` account's identity keys are missing from secure
/// storage, when a fallback authenticates a different primary account, or when
/// [AuthService] lands in [AuthState.awaitingTosAcceptance] after an internal
/// session-setup failure.
///
/// Previously these paths returned normally, leaving the caller (WelcomeBloc)
/// believing the sign-in succeeded while the router kept the user pinned to
/// `/welcome` — an invisible login loop. Throwing lets the caller route the
/// user to the full login flow instead. See #5195.
class AccountRestoreFailedException implements Exception {
  const AccountRestoreFailedException(
    this.pubkeyHex,
    this.resolvedState, {
    this.resolvedPubkeyHex,
  });

  /// The account (hex pubkey) whose restore was attempted.
  final String pubkeyHex;

  /// The [AuthState] the service resolved to.
  final AuthState resolvedState;

  /// The account (hex pubkey) that became active, if any.
  final String? resolvedPubkeyHex;

  @override
  String toString() =>
      'AccountRestoreFailedException: sign-in for $pubkeyHex resolved to '
      '$resolvedState'
      '${resolvedPubkeyHex == null ? '' : ' as $resolvedPubkeyHex'} '
      'instead of the requested account';
}

/// Result of authentication operations
class AuthResult {
  const AuthResult({
    required this.success,
    this.errorMessage,
    this.keyContainer,
    this.nostrConnectFailureReason,
  });

  factory AuthResult.success(SecureKeyContainer keyContainer) =>
      AuthResult(success: true, keyContainer: keyContainer);

  factory AuthResult.failure(String errorMessage) =>
      AuthResult(success: false, errorMessage: errorMessage);

  /// Failure result for the nostrconnect:// flow, carrying a localizable
  /// reason code instead of a raw English string. The UI maps the reason to a
  /// `context.l10n.*` string.
  factory AuthResult.nostrConnectFailure(NostrConnectFailureReason reason) =>
      AuthResult(success: false, nostrConnectFailureReason: reason);

  final bool success;
  final String? errorMessage;
  final SecureKeyContainer? keyContainer;

  /// Set only by the nostrconnect:// failure path; `null` for every other flow.
  final NostrConnectFailureReason? nostrConnectFailureReason;
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
        displayName: keyContainer.npub,
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
typedef UserRelaysDiscoveredCallback =
    void Function(String pubkey, List<String> relayUrls);

/// Callback invoked when AuthService wants to publish a bootstrap kind:10002
/// relay list on behalf of the user (because indexer discovery returned empty).
///
/// The event is already signed. The implementer publishes it through the
/// active [NostrClient] to [targetRelays] and reports success/failure via the
/// returned future.
typedef BootstrapRelayListCallback =
    Future<bool> Function(Event event, List<String> targetRelays);

/// Callback invoked before AuthService clears the outgoing session identity.
typedef BeforeSessionTeardownCallback = Future<void> Function();

/// Factory for NIP-46 remote signers. Injected in tests so startup restore can
/// exercise unreachable signer behavior without opening relay sockets.
typedef RemoteSignerFactory =
    NostrRemoteSigner Function(int relayMode, NostrRemoteSignerInfo info);

/// SharedPreferences key prefix for the per-pubkey one-shot flag that records
/// whether we have already published a bootstrap kind:10002 on this device.
const _kBootstrapKind10002Prefix = 'bootstrap_kind10002_published_';

/// Upper bound on how long to wait for the signer when producing the
/// bootstrap kind:10002 event. If the signer does not respond within this
/// window (hung Keycast RPC, unreachable Amber, etc.) we abandon the publish
/// and leave the flag unset so the next login retries. See #3174 / #3162.
const _kBootstrapSignTimeout = Duration(seconds: 10);

/// Total time budget for pre-teardown callbacks during sign-out.
const _kBeforeSessionTeardownTimeout = Duration(seconds: 5);

/// Main authentication service for the Divine app
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via
/// Riverpod
class AuthService implements BackgroundAwareService, BlockListSigner {
  AuthService({
    required UserDataCleanupService userDataCleanupService,
    SecureKeyStorage? keyStorage,
    KeycastOAuth? oauthClient,
    FlutterSecureStorage? flutterSecureStorage,
    OAuthConfig? oauthConfig,
    PreFetchFollowingCallback? preFetchFollowing,
    String? profileCheckIndexerUrl,
    List<String>? indexerRelays,
    String? primaryRelayUrl,
    RelayDiscoveryService? relayDiscoveryService,
    Nip07Service? nip07ServiceForTest,
    RemoteSignerFactory? remoteSignerFactory,
    Duration oauthRefreshTimeout = defaultOAuthRefreshTimeout,
    Duration expiredSessionRefreshTimeout = defaultExpiredSessionRefreshTimeout,
    Duration? startupNetworkOperationTimeout,
  }) : _keyStorage = keyStorage ?? SecureKeyStorage(),
       _userDataCleanupService = userDataCleanupService,
       _oauthClient = oauthClient,
       _flutterSecureStorage = flutterSecureStorage,
       _preFetchFollowing = preFetchFollowing,
       _profileCheckIndexerUrl = profileCheckIndexerUrl,
       _primaryRelayUrl = primaryRelayUrl ?? AppConstants.defaultRelayUrl,
       _relayDiscoveryService =
           relayDiscoveryService ??
           RelayDiscoveryService(indexerRelays: indexerRelays),
       _oauthConfig =
           oauthConfig ??
           const OAuthConfig(serverUrl: '', clientId: '', redirectUri: ''),
       _injectedNip07ServiceForTest = nip07ServiceForTest,
       _remoteSignerFactory = remoteSignerFactory ?? NostrRemoteSigner.new,
       _oauthRefreshTimeout = oauthRefreshTimeout,
       _expiredSessionRefreshTimeout = expiredSessionRefreshTimeout,
       _startupNetworkOperationTimeout =
           startupNetworkOperationTimeout ??
           defaultStartupNetworkOperationTimeout;
  final SecureKeyStorage _keyStorage;
  final UserDataCleanupService _userDataCleanupService;
  final KeycastOAuth? _oauthClient;
  final FlutterSecureStorage? _flutterSecureStorage;
  final PreFetchFollowingCallback? _preFetchFollowing;
  final String? _profileCheckIndexerUrl;
  final RemoteSignerFactory _remoteSignerFactory;
  final Duration _startupNetworkOperationTimeout;

  /// Bound applied to the single-flight OAuth token refresh stored in
  /// [_pendingOAuthRefresh]. Injectable so tests can use a short bound.
  final Duration _oauthRefreshTimeout;

  /// Bound applied to the full expired-session refresh flow stored in
  /// [_pendingRefresh]. Injectable so tests can use a short bound.
  final Duration _expiredSessionRefreshTimeout;

  /// Test seam: when supplied, bypasses the [Nip07Service] singleton and the
  /// [kIsWeb] guard so unit tests can exercise the full NIP-07 flow on the VM
  /// target.
  final Nip07Service? _injectedNip07ServiceForTest;

  /// Relay URL used when self-publishing the bootstrap kind:10002 event for
  /// accounts whose indexer discovery returned empty. Injected from
  /// [EnvironmentConfig.relayUrl] at the provider so non-prod builds do not
  /// advertise the production relay. Falls back to
  /// [AppConstants.defaultRelayUrl] when unset. See #3183.
  final String _primaryRelayUrl;

  AuthState _authState = AuthState.checking;
  SecureKeyContainer? _currentKeyContainer;
  UserProfile? _currentProfile;
  String? _lastError;
  bool _storageErrorOccurred = false;
  bool _hasExpiredOAuthSession = false;
  bool _isRpcUpgradeInProgress = false;
  Future<bool>? _pendingRefresh;
  Future<KeycastSession?>? _pendingOAuthRefresh;
  KeycastRpc? _keycastSigner;

  // RPC capability state — separate from AuthState so the router doesn't
  // need to know about remote signer warmup.
  AuthRpcCapability _authRpcCapability = AuthRpcCapability.unavailable;

  // NIP-46 bunker signer state
  NostrRemoteSigner? _bunkerSigner;

  // NIP-55 Android signer (Amber) state
  AndroidNostrSigner? _amberSigner;

  // NIP-07 browser extension signer state (nullable; null when no session active)
  Nip07Service? _nip07Service;

  // NIP-46 nostrconnect:// session state (for client-initiated connections)
  NostrConnectSession? _nostrConnectSession;
  Future<AuthResult>? _nostrConnectWaitFuture;
  Timer? _nostrConnectCallbackHandoffTimer;
  Timer? _nostrConnectCallbackHandoffCancelTimer;
  bool _isNostrConnectCallbackHandoffActive = false;

  // Atomic signing identity — couples pubkey with signing mechanism
  NostrIdentity? _currentIdentity;

  // Relay discovery state (NIP-65)
  List<DiscoveredRelay> _userRelays = [];
  bool _hasExistingProfile = false;
  final RelayDiscoveryService _relayDiscoveryService;

  /// Callback registered by NostrService to add discovered relays to the client
  /// when discovery completes (avoids race where client is built before discovery).
  UserRelaysDiscoveredCallback? _onUserRelaysDiscovered;

  /// Callback registered by NostrService to publish a bootstrap kind:10002
  /// event when indexer discovery returns empty for the signed-in user.
  ///
  /// See [registerBootstrapRelayListCallback].
  BootstrapRelayListCallback? _onBootstrapRelayListRequested;

  final List<BeforeSessionTeardownCallback> _beforeSessionTeardownCallbacks =
      [];

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

  /// Check if user is authenticated
  @override
  bool get isAuthenticated => _authState == AuthState.authenticated;

  /// Authentication source used for current session
  AuthenticationSource _authSource = AuthenticationSource.none;

  /// Get the current authentication source
  AuthenticationSource get authenticationSource => _authSource;

  /// Check if user has registered with Divine (email/password)
  /// Returns true if authenticated via Divine OAuth, false for anonymous/imported keys
  bool get isRegistered => _authSource == AuthenticationSource.divineOAuth;

  /// Whether the active account has a local private key that can be exported.
  bool get canExportLocalNsec {
    if (!isAuthenticated) return false;
    if (_currentKeyContainer?.hasPrivateKey != true) return false;
    return switch (_authSource) {
      AuthenticationSource.automatic ||
      AuthenticationSource.importedKeys ||
      AuthenticationSource.divineOAuth => true,
      _ => false,
    };
  }

  /// Check if user is using an anonymous auto-generated identity
  bool get isAnonymous => _authSource == AuthenticationSource.automatic;

  /// True only on web targets where `window.nostr` (a NIP-07 extension) is
  /// reachable. Used by the welcome screen to decide whether to surface the
  /// browser-extension sign-in button.
  bool get isNip07Available {
    if (!kIsWeb && _injectedNip07ServiceForTest == null) return false;
    return (_injectedNip07ServiceForTest ?? Nip07Service()).isAvailable;
  }

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
    return switch (_currentIdentity) {
      null => false,
      LocalNostrIdentity() => true,
      KeycastNostrIdentity() => true,
      AmberNostrIdentity() => true,
      BunkerNostrIdentity() => true,
      Nip07NostrIdentity() => true,
    };
  }

  /// True when a divineOAuth user's session expired and refresh failed.
  /// The user's identity is intact but remote signing is unavailable.
  /// UI should prompt re-login instead of "Secure Your Account".
  bool get hasExpiredOAuthSession => _hasExpiredOAuthSession;

  /// True while a background OAuth RPC upgrade is in progress during startup.
  /// The session-expired sheet should be suppressed until this resolves so the
  /// UI does not prompt re-login before the silent refresh has definitively failed.
  bool get isRpcUpgradeInProgress => _isRpcUpgradeInProgress;

  /// Legacy test-friendly short bound for background RPC refresh.
  @visibleForTesting
  static const rpcRefreshTimeout = Duration(seconds: 10);

  /// Default bound for the single-flight OAuth token refresh. It is longer
  /// than KeycastOAuth's own HTTP bound so production code does not abandon
  /// a slow-but-still-live request before the client has resolved it.
  @visibleForTesting
  static const defaultOAuthRefreshTimeout = Duration(seconds: 35);

  /// Default bound for the full expired-session refresh flow (token refresh
  /// plus session re-integration). This stays longer than the OAuth refresh
  /// bound so the outer flow does not detach from a live refresh.
  @visibleForTesting
  static const defaultExpiredSessionRefreshTimeout = Duration(seconds: 40);

  /// Default upper bound for one startup network operation while restoring a
  /// saved remote auth session. A bunker restore can do connect + pubkey pull,
  /// so callers that need an end-to-end budget should use
  /// [startupAuthRestoreTimeout].
  @visibleForTesting
  static const defaultStartupNetworkOperationTimeout = Duration(seconds: 10);

  /// Worst-case auth restore budget used by app startup splash handling.
  static const startupAuthRestoreTimeout = Duration(seconds: 21);

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

    var session = await KeycastSession.load(_flutterSecureStorage);
    SecureKeyContainer? localKey;
    try {
      if (await _keyStorage.hasKeys()) {
        localKey = await _keyStorage.getKeyContainer();
      }
    } catch (e, stack) {
      _reportStorageError(e, stack, 'divineOAuth local key load');
    }

    // Detect and resolve diverged state: the global OAuth session and
    // local PRIMARY key belong to different accounts. This can happen
    // from pre-fix cross-contamination (Bug 2 corruption) OR from a
    // user adding a Keycast account originally registered on another
    // device (their local PRIMARY has a different device-only key).
    //
    // Use _kLastUsedNpubKey as the tiebreaker to decide which side is
    // authoritative. Whichever matches last-used wins. If neither
    // matches, safe default: clear the session.
    //
    // In all branches, the local nsec in secure key storage is never
    // deleted (Daniel rule: no silent key loss).
    if (session != null && localKey != null) {
      final sessionPubkey = session.userPubkey;
      final diverged =
          sessionPubkey == null || sessionPubkey != localKey.publicKeyHex;
      if (diverged) {
        final prefs = await SharedPreferences.getInstance();
        final lastUsedNpub = prefs.getString(_kLastUsedNpubKey);
        final localNpub = NostrKeyUtils.encodePubKey(localKey.publicKeyHex);
        final sessionNpub = sessionPubkey != null
            ? NostrKeyUtils.encodePubKey(sessionPubkey)
            : null;

        final sessionAuthoritative =
            sessionNpub != null && sessionNpub == lastUsedNpub;
        final localAuthoritative = localNpub == lastUsedNpub;

        if (sessionAuthoritative && !localAuthoritative) {
          // Session wins. The local PRIMARY key is stale (e.g., from
          // an older device-only account). Preserve the session,
          // force the slow path with null localKey, and archive the
          // stale local key into its per-identity slot so the user
          // can switch back to it via the welcome screen.
          Log.warning(
            'initialize: local key ${localKey.publicKeyHex} is stale — '
            'last-used=$lastUsedNpub matches session '
            'userPubkey=$sessionPubkey. Forcing slow path with '
            'session; archiving stale local key to $localNpub.',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          try {
            await _keyStorage.storeIdentityKeyContainer(localNpub, localKey);
          } catch (e) {
            Log.warning(
              'initialize: failed to archive stale local key: $e',
              name: 'AuthService',
              category: LogCategory.auth,
            );
          }
          localKey = null;
        } else if (localAuthoritative && !sessionAuthoritative) {
          // Local key wins. Clear the stale OAuth session.
          Log.warning(
            'initialize: global OAuth session pubkey='
            '${sessionPubkey ?? "null (legacy)"} is stale — '
            'last-used=$lastUsedNpub matches local key '
            '${localKey.publicKeyHex}. Clearing stale session.',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _clearKeycastSessionAndTokens();
          session = null;
        } else {
          // Ambiguous: neither (or both, impossible since diverged)
          // matches last-used. Safe default — clear the session. The
          // local key stays put and the fast path uses it.
          Log.warning(
            'initialize: divergence with ambiguous last-used npub — '
            'session=${sessionPubkey ?? "null"}, '
            'local=${localKey.publicKeyHex}, last-used=$lastUsedNpub. '
            'Clearing global session (safe default).',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _clearKeycastSessionAndTokens();
          session = null;
        }
      }
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
        _keycastSigner = KeycastRpc.fromSession(
          _oauthConfig,
          session,
          onTokenRefresh: _refreshAccessToken,
        );
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
    KeycastSession? session, {
    String? expectedOwnerPubkey,
  }) async {
    Log.info(
      'initialize: starting background RPC refresh...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // The refresh below runs unawaited across an async gap. If the user
    // signs out or switches accounts while it is in flight, applying the
    // result would attach the previous account's RPC signer to whichever
    // identity is active by then.
    final upgradeOwnerPubkey =
        expectedOwnerPubkey ?? session?.userPubkey ?? currentPublicKeyHex;
    bool upgradeContextStillCurrent() =>
        _authState == AuthState.authenticated &&
        currentPublicKeyHex == upgradeOwnerPubkey;

    _isRpcUpgradeInProgress = true;
    try {
      if (_oauthClient == null) {
        _setRpcCapability(AuthRpcCapability.unavailable);
        return;
      }

      // The shared refresh future is internally bounded by
      // [_oauthRefreshTimeout] (see _refreshOAuthSession), so this await
      // cannot block startup indefinitely.
      final refreshed = await _refreshOAuthSession(
        expectedOwnerPubkey: expectedOwnerPubkey ?? session?.userPubkey,
      );

      if (!upgradeContextStillCurrent()) {
        Log.warning(
          'initialize: discarding stale background RPC refresh — '
          'signed out or switched accounts while it was in flight',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }

      if (refreshed != null) {
        Log.info(
          'initialize: background RPC refresh succeeded',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        await _clearDismissedDivineLoginBannerForCurrentUser();
        _keycastSigner = KeycastRpc.fromSession(
          _oauthConfig,
          refreshed,
          onTokenRefresh: _refreshAccessToken,
        );
        _currentIdentity = _buildIdentity();
        _setRpcCapability(AuthRpcCapability.rpcReady);
        return;
      }
    } catch (e) {
      Log.error(
        'initialize: background RPC refresh failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } finally {
      _isRpcUpgradeInProgress = false;
      // Nudge the auth stream so widgets re-evaluate whether the
      // session-expired sheet should be shown now that the upgrade has resolved.
      _authStateController.add(_authState);
    }

    // A late failure must not downgrade whichever account is active now.
    if (!upgradeContextStillCurrent()) {
      return;
    }

    _setRpcCapability(AuthRpcCapability.unavailable);
  }

  /// Synchronous fallback for Divine OAuth when no local key is available.
  ///
  /// Attempts RPC refresh, then falls back to unauthenticated.
  Future<void> _restoreDivineRpcOrFallbackUnauthenticated(
    KeycastSession? session,
  ) async {
    // Read the session recovery anchor once. Both the direct-restore and the
    // refresh paths below use it to detect cross-account cold-start restores.
    final prefs = await SharedPreferences.getInstance();
    final anchorNpub = prefs.getString(_kSessionRecoveryAnchorKey);

    // If session is valid with RPC access, check whether it belongs to the
    // same account the user was signed into when they last signed out.
    //
    // If a session-recovery anchor exists and the session belongs to a
    // DIFFERENT account (cross-account cold-start restore), do NOT silently
    // complete the sign-in. Instead route to unauthenticated so the welcome
    // screen can surface a confirmation banner — the user gets to decide
    // explicitly which account they want. If no anchor exists (fresh install,
    // or first sign-out after the fix) we fall through to the original
    // behaviour to avoid breaking the normal single-account flow.
    if (session != null && session.hasRpcAccess) {
      if (_isCrossAccountRestore(
        candidatePubkey: session.userPubkey,
        anchorNpub: anchorNpub,
      )) {
        _setAuthState(AuthState.unauthenticated);
        return;
      }

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
      final KeycastSession? refreshed;
      try {
        refreshed = await _refreshOAuthSession(
          expectedOwnerPubkey: session?.userPubkey,
        ).timeout(_startupNetworkOperationTimeout);
      } on TimeoutException {
        Log.warning(
          'initialize: synchronous refresh timed out '
          '(${_startupNetworkOperationTimeout.inSeconds}s)',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        _hasExpiredOAuthSession = true;
        _setAuthState(AuthState.unauthenticated);
        return;
      }

      if (refreshed != null) {
        // Apply the same cross-account guard to the refreshed session.
        // The OAuth server is authoritative about which account a token
        // belongs to, but we must not silently complete a sign-in as a
        // different account than the one the user was on at sign-out.
        if (_isCrossAccountRestore(
          candidatePubkey: refreshed.userPubkey,
          anchorNpub: anchorNpub,
        )) {
          // Do NOT consume the refresh or set _hasExpiredOAuthSession=false
          // here — leave the user unauthenticated and let the welcome screen
          // handle the confirmation. The refreshed token is discarded; the
          // user will go through a full re-auth for whichever account they
          // confirm.
          _setAuthState(AuthState.unauthenticated);
          return;
        }

        Log.info(
          'initialize: refresh succeeded',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        await _clearDismissedDivineLoginBannerForCurrentUser();
        await signInWithDivineOAuth(refreshed);
        return;
      }
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

  /// Returns true when [candidatePubkey] belongs to a different account than
  /// the one recorded in [anchorNpub] at sign-out time.
  ///
  /// Returns false (no block) when either side is absent — if there is no
  /// anchor (fresh install, pre-fix first run) or the session has no bound
  /// pubkey, the cross-account guard degrades gracefully rather than breaking
  /// the normal single-account flow.
  bool _isCrossAccountRestore({
    required String? candidatePubkey,
    required String? anchorNpub,
  }) {
    if (anchorNpub == null || candidatePubkey == null) return false;
    final candidateNpub = NostrKeyUtils.encodePubKey(candidatePubkey);
    if (anchorNpub == candidateNpub) return false;

    Log.warning(
      'initialize: cross-account session restore blocked — '
      'anchor=$anchorNpub, candidate=$candidateNpub. '
      'Routing to unauthenticated for explicit confirmation.',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    return true;
  }

  /// Attempt to silently refresh an expired OAuth session.
  ///
  /// Returns true if the refresh succeeded and the user is now fully
  /// authenticated. Returns false if no expired session exists or if
  /// the refresh fails (caller should navigate to login).
  ///
  /// Concurrent callers share a single in-flight refresh to avoid
  /// consuming one-time-use refresh tokens in a race. The shared future is
  /// bounded by [_expiredSessionRefreshTimeout] so a hung attempt always
  /// releases the slot and the next call starts a fresh refresh (#4942).
  Future<bool> tryRefreshExpiredSession() {
    if (!_hasExpiredOAuthSession || _oauthClient == null) {
      return Future.value(false);
    }
    final pending = _pendingRefresh;
    if (pending != null) return pending;

    late final Future<bool> refresh;
    refresh = _doRefreshExpiredSession()
        .timeout(
          _expiredSessionRefreshTimeout,
          onTimeout: () {
            Log.warning(
              'tryRefreshExpiredSession: timed out after '
              '${_expiredSessionRefreshTimeout.inMilliseconds}ms — '
              'treating as failed',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            return false;
          },
        )
        .whenComplete(() {
          // Only release the slot if it still holds this attempt — signOut
          // may have detached it and a fresh attempt may already be in
          // flight.
          if (identical(_pendingRefresh, refresh)) {
            _pendingRefresh = null;
          }
        });
    return _pendingRefresh = refresh;
  }

  Future<bool> _doRefreshExpiredSession() async {
    Log.info(
      'tryRefreshExpiredSession: attempting silent refresh',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    return _tryRefreshOAuthSession(caller: 'tryRefreshExpiredSession');
  }

  /// Returns the npub that was actively signed in at the time of the most
  /// recent sign-out, or null if no anchor has been recorded.
  ///
  /// The welcome screen uses this to detect when a cold-start session restore
  /// would land on a different account than the one the user was just using,
  /// and surfaces a confirmation banner before the switch completes silently.
  ///
  /// The anchor is written at the start of [signOut] and cleared by
  /// [_setupUserSession] once the user has explicitly signed back in.
  Future<String?> getSessionRecoveryAnchorNpub() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSessionRecoveryAnchorKey);
  }

  /// Shared OAuth session refresh logic used by both [initialize] and
  /// [tryRefreshExpiredSession]. Returns true if refresh succeeded.
  Future<bool> _tryRefreshOAuthSession({
    required String caller,
    String? expectedOwnerPubkey,
  }) async {
    final refreshed = await _refreshOAuthSession(
      expectedOwnerPubkey: expectedOwnerPubkey,
    );
    if (refreshed != null) {
      Log.info(
        '$caller: refresh succeeded',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      await _clearDismissedDivineLoginBannerForCurrentUser();
      await signInWithDivineOAuth(refreshed);
      return true;
    }
    return false;
  }

  /// Single-flight OAuth session refresh. Every code path that needs a
  /// fresh [KeycastSession] MUST call this instead of
  /// `_oauthClient.refreshSession()` directly.
  ///
  /// Guarantees:
  /// - Only one `refreshSession()` call in flight at a time (concurrent
  ///   callers share the same [Future]).
  /// - The shared future is bounded by [_oauthRefreshTimeout] and ALWAYS
  ///   releases the single-flight slot, even if the underlying request
  ///   hangs on a dead socket — so the next attempt gets a fresh refresh
  ///   instead of joining a poisoned one (#4942).
  /// - `userPubkey` is bound before the session is persisted, so
  ///   ownership checks on restore stay valid.
  /// - `_hasExpiredOAuthSession` is cleared on success.
  ///
  /// [expectedOwnerPubkey] binds the refreshed session to a specific
  /// account. Callers that hold a stored session should pass its
  /// `userPubkey`; mid-session callers (401 retry, app resume) may omit
  /// it — the method falls back to [_currentProfile].
  ///
  /// Returns the refreshed session on success, or `null` on failure.
  Future<KeycastSession?> _refreshOAuthSession({String? expectedOwnerPubkey}) {
    final pending = _pendingOAuthRefresh;
    if (pending != null) return pending;

    late final Future<KeycastSession?> refresh;
    refresh = _doRefreshOAuthSession(expectedOwnerPubkey: expectedOwnerPubkey)
        .timeout(
          _oauthRefreshTimeout,
          onTimeout: () {
            Log.warning(
              '_refreshOAuthSession: timed out after '
              '${_oauthRefreshTimeout.inMilliseconds}ms — '
              'treating as failed',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            return null;
          },
        )
        .whenComplete(() {
          // Only release the slot if it still holds this attempt —
          // signOut may have detached it and a fresh attempt may
          // already be in flight.
          if (identical(_pendingOAuthRefresh, refresh)) {
            _pendingOAuthRefresh = null;
          }
        });
    return _pendingOAuthRefresh = refresh;
  }

  Future<KeycastSession?> _doRefreshOAuthSession({
    String? expectedOwnerPubkey,
  }) async {
    if (_oauthClient == null) return null;
    try {
      final pubkey = expectedOwnerPubkey ?? _currentProfile?.publicKeyHex;
      final refreshed = await _oauthClient.refreshSession(userPubkey: pubkey);
      if (refreshed == null || !refreshed.hasRpcAccess) return null;

      _hasExpiredOAuthSession = false;
      Log.info(
        '_refreshOAuthSession: succeeded '
        '(userPubkey=${refreshed.userPubkey != null ? "bound" : "unbound"})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return refreshed;
    } catch (e) {
      Log.error(
        '_refreshOAuthSession: failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// [TokenRefreshCallback] passed to [KeycastRpc] so it can recover
  /// from mid-session 401s without caller involvement.
  ///
  /// Delegates to [_refreshOAuthSession] which deduplicates concurrent
  /// callers — multiple in-flight RPC 401s and app-resume refresh all
  /// share a single refresh token exchange.
  Future<String?> _refreshAccessToken() async {
    final refreshed = await _refreshOAuthSession();
    return refreshed?.accessToken;
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

  /// Register a callback to publish a bootstrap kind:10002 on behalf of the
  /// signed-in user when indexer discovery returns empty. Pass [null] to
  /// unregister.
  ///
  /// AuthService builds + signs the event; the callback owner is expected to
  /// broadcast it via the current [NostrClient]. See
  /// [_publishBootstrapRelayList] and #3174.
  void registerBootstrapRelayListCallback(
    BootstrapRelayListCallback? callback,
  ) {
    _onBootstrapRelayListRequested = callback;
  }

  /// Register work that must run with the outgoing session still available.
  ///
  /// The returned disposer unregisters [callback]. AuthService runs remaining
  /// callbacks sequentially at sign-out before clearing [currentIdentity],
  /// signers, or Nostr callbacks.
  ///
  /// All callbacks share a single 5 second sign-out budget. A timeout is
  /// warning-only: sign-out continues and later callbacks still get a chance to
  /// run if budget remains. Dart [Future.timeout] does not cancel the
  /// underlying future, so callbacks must tolerate late completion after the
  /// outgoing identity/signers have been cleared.
  VoidCallback registerBeforeSessionTeardownCallback(
    BeforeSessionTeardownCallback callback,
  ) {
    _beforeSessionTeardownCallbacks.add(callback);
    var registered = true;
    return () {
      if (!registered) return;
      registered = false;
      _beforeSessionTeardownCallbacks.remove(callback);
    };
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
  void _reportStorageError(Object error, StackTrace stack, String reason) {
    _reportAuthError(
      error,
      stack,
      reason: reason,
      logMessage: 'Storage error during auth: $reason',
    );
  }

  void _reportAuthError(
    Object error,
    StackTrace stack, {
    required String reason,
    required String logMessage,
  }) {
    final crashlytics = CrashReportingService.instance;
    crashlytics.log(logMessage);
    unawaited(crashlytics.setCustomKey('auth_source', _authSource.code));
    unawaited(crashlytics.recordError(error, stack, reason: reason));
  }

  void _reportNonFatalAuthCleanupError(
    Object error,
    StackTrace stack,
    String reason,
  ) {
    _reportAuthError(error, stack, reason: reason, logMessage: reason);
  }

  /// Clears any persisted Divine OAuth session that was created before an
  /// invite consume completed.
  ///
  /// Invite flows can exchange OAuth tokens before invite activation runs.
  /// If activation then fails, startup must not restore that partial session
  /// and bypass the invite gate on the next launch.
  Future<void> clearPendingDivineOAuthSession() async {
    try {
      await _clearKeycastSessionAndTokens();
    } catch (e) {
      Log.warning(
        'Failed to clear pending Divine OAuth session: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      // Invite activation failures can legitimately leave no session to clear.
      // Keep local visibility without sending expected cleanup noise upstream.
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
            await _reconnectBunker(bunkerInfo, boundedByStartupTimeout: true);
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

        case AuthenticationSource.nip07:
          Log.info(
            'initialize: restoring NIP-07 session...',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          if (kIsWeb) {
            await _reconnectNip07();
            return;
          }
          Log.warning(
            'initialize: persisted nip07 source on non-web platform — '
            'falling back to unauthenticated',
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
        '📱 Public key: ${keyContainer.npub}',
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

        case AuthenticationSource.nip07:
          // NIP-07 was introduced after the legacy migration; no archived
          // hint to recover. Leave pubkeyHex null so this path is skipped.
          break;

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

      // Archive OAuth session — only if it has a bound userPubkey
      // matching this account. Null userPubkey means the session was
      // created before pubkey binding (legacy) and cannot be verified
      // as belonging to any specific account; archiving an unverifiable
      // session risks cross-contamination (Bug 2). A fresh OAuth
      // sign-in via signInWithDivineOAuth always binds userPubkey.
      final oauthSession = await KeycastSession.load(_flutterSecureStorage);
      final oauthOwnerMatches =
          oauthSession?.userPubkey != null &&
          oauthSession?.userPubkey == pubkeyHex;
      final archiveOauth = oauthSession != null && oauthOwnerMatches;
      if (archiveOauth) {
        await _flutterSecureStorage.write(
          key: _keycastSessionKey(pubkeyHex),
          value: jsonEncode(oauthSession.toJson()),
        );
      } else if (oauthSession != null) {
        Log.warning(
          '_archiveSignerInfo: skipping OAuth archive for $pubkeyHex — '
          'global session pubkey='
          '${oauthSession.userPubkey ?? "null (legacy)"} '
          '(cannot verify ownership, not archiving to avoid corruption)',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      Log.info(
        '_archiveSignerInfo: archived for $pubkeyHex — '
        'amber=${amberInfo != null}, '
        'bunker=${bunkerUrl != null && bunkerUrl.isNotEmpty}, '
        'oauth=$archiveOauth',
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
            key: _keycastSessionKey(pubkeyHex),
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

            // Validate archive ownership. If the archive's userPubkey
            // is set and does NOT match the requested account, the
            // archive is corrupt (e.g., from pre-fix cross-contamination).
            // Delete it so Bug 1's recovery cascade can handle the
            // fallback via SessionExpiredException → login options.
            // Corrupt if userPubkey is null (legacy, unverifiable) or
            // mismatches the requested account (cross-contamination).
            final archivePubkey = session.userPubkey;
            final corrupt = archivePubkey == null || archivePubkey != pubkeyHex;
            if (corrupt) {
              Log.warning(
                '_restoreSignerInfo: corrupt OAuth archive for '
                '$pubkeyHex — archive pubkey='
                '${archivePubkey ?? "null (legacy)"}. '
                'Deleting corrupt archive.',
                name: 'AuthService',
                category: LogCategory.auth,
              );
              await _flutterSecureStorage.delete(
                key: _keycastSessionKey(pubkeyHex),
              );
            } else {
              await session.save(_flutterSecureStorage);
              // Also restore the refresh token and auth handle to
              // their standalone keys — KeycastOAuth.refreshSession()
              // reads these separately from the session JSON, and
              // _oauthClient.logout() clears them. Without this,
              // expired restored sessions can never be refreshed.
              if (session.refreshToken != null) {
                await _flutterSecureStorage.write(
                  key: _kKeycastRefreshTokenKey,
                  value: session.refreshToken,
                );
              }
              if (session.authorizationHandle != null) {
                await _flutterSecureStorage.write(
                  key: _kKeycastAuthHandleKey,
                  value: session.authorizationHandle,
                );
              }
            }
          }

        case AuthenticationSource.automatic:
        case AuthenticationSource.importedKeys:
        case AuthenticationSource.none:
        case AuthenticationSource.nip07:
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
      await _flutterSecureStorage.delete(key: _keycastSessionKey(pubkeyHex));
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

      case AuthenticationSource.nip07:
        Log.info(
          'signInForAccount: restoring NIP-07 session...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        if (kIsWeb) {
          await _reconnectNip07();
        } else {
          Log.error(
            'signInForAccount: persisted nip07 source on non-web platform',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          throw Exception('NIP-07 sign-in is only available on the web.');
        }

      case AuthenticationSource.divineOAuth:
        Log.info(
          'signInForAccount: loading OAuth session for reconnect...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final session = await KeycastSession.load(_flutterSecureStorage);
        // Verify the loaded session belongs to the requested account.
        // After sign-out, the global slot may still hold a different
        // account's session if _restoreSignerInfo found no archive.
        final sessionMatchesAccount =
            session != null &&
            session.hasRpcAccess &&
            session.userPubkey == pubkeyHex;
        if (sessionMatchesAccount) {
          await signInWithDivineOAuth(session);
        } else {
          // Session is expired, missing, wrong account, or has no
          // RPC access. Try to refresh, then fall back to local
          // keys — same recovery strategy as _initializeDivineOAuth.
          Log.info(
            'signInForAccount: OAuth session not usable for $pubkeyHex '
            '(session=${session != null}, '
            'hasRpcAccess=${session?.hasRpcAccess}, '
            'isExpired=${session?.isExpired}, '
            'sessionPubkey=${session?.userPubkey}, '
            'requestedPubkey=$pubkeyHex), attempting refresh...',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          // Only attempt refresh if the global slot belongs to the
          // requested account — refreshing a different account's token
          // would sign in as the wrong identity.
          final canRefresh =
              _oauthClient != null && session?.userPubkey == pubkeyHex;
          if (canRefresh) {
            final refreshed = await _tryRefreshOAuthSession(
              caller: 'signInForAccount',
              expectedOwnerPubkey: pubkeyHex,
            );
            if (refreshed) break;
          }

          // Refresh failed — try local keys so the user can at least
          // read their feed while RPC catches up in the background.
          final npub = NostrKeyUtils.encodePubKey(pubkeyHex);
          SecureKeyContainer? localKey;
          try {
            localKey = await _keyStorage.getIdentityKeyContainer(npub);
            if (localKey == null && await _keyStorage.hasKeys()) {
              final primary = await _keyStorage.getKeyContainer();
              if (primary?.publicKeyHex == pubkeyHex) {
                localKey = primary;
              }
            }
          } catch (e) {
            Log.warning(
              'signInForAccount: local key lookup failed: $e',
              name: 'AuthService',
              category: LogCategory.auth,
            );
          }

          if (localKey != null) {
            Log.info(
              'signInForAccount: using local keys for $pubkeyHex '
              'with expired OAuth session flag',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            _hasExpiredOAuthSession = true;
            _setRpcCapability(AuthRpcCapability.upgrading);
            await _setupUserSession(localKey, AuthenticationSource.divineOAuth);
            unawaited(
              _upgradeDivineRpcInBackground(
                session,
                expectedOwnerPubkey: pubkeyHex,
              ),
            );
          } else {
            Log.warning(
              'signInForAccount: no refresh, no local keys for '
              '$pubkeyHex — session expired',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            throw SessionExpiredException();
          }
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
          // Fall back to current PRIMARY keys only when they belong to the
          // requested account. `_checkExistingAuth` intentionally restores
          // whatever PRIMARY account is present, which is correct for app
          // startup but unsafe for an explicit account-switch request.
          Log.warning(
            'signInForAccount: no saved identity keys for $npub — '
            'checking PRIMARY key for same-account fallback',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          SecureKeyContainer? primary;
          try {
            if (await _keyStorage.hasKeys()) {
              primary = await _keyStorage.getKeyContainer();
            }
          } catch (e, stack) {
            Log.error(
              'signInForAccount: failed to inspect PRIMARY key fallback: $e',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            _reportStorageError(e, stack, 'signInForAccount primary fallback');
          }

          if (primary?.publicKeyHex == pubkeyHex) {
            Log.info(
              'signInForAccount: PRIMARY key matches requested account — '
              'using same-account fallback',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            await _setupUserSession(primary!, authSource);
          } else {
            Log.warning(
              'signInForAccount: no restorable local keys for $pubkeyHex '
              '(primaryPubkey=${primary?.publicKeyHex})',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            _setAuthState(AuthState.unauthenticated);
          }
        }

      case AuthenticationSource.none:
        Log.error(
          'signInForAccount: cannot sign in with authSource=none',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        throw Exception('Cannot sign in with auth source "none"');
    }

    // Guard against silent restore failures. Several branches above can resolve
    // normally without restoring the requested account:
    //   - importedKeys/automatic whose identity keys are missing and no
    //     matching PRIMARY key exists resolve unauthenticated.
    //   - `_setupUserSession` swallows internal failures into
    //     `awaitingTosAcceptance`.
    // These previously left the caller believing the sign-in succeeded while
    // the router kept the user on `/welcome`, or worse, authenticated the wrong
    // local account. Surface the failure so the caller can route to the full
    // login flow instead. See #5195.
    final resolvedPubkeyHex = currentPublicKeyHex;
    if (_authState != AuthState.authenticated ||
        resolvedPubkeyHex != pubkeyHex) {
      Log.warning(
        'signInForAccount: resolved to $_authState '
        '(resolvedPubkey=$resolvedPubkeyHex) for '
        '$pubkeyHex — surfacing AccountRestoreFailedException',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      throw AccountRestoreFailedException(
        pubkeyHex,
        _authState,
        resolvedPubkeyHex: resolvedPubkeyHex,
      );
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

  /// Clears the global Keycast session, refresh token, and auth handle.
  ///
  /// Used when a stale or ambiguous OAuth session must be discarded
  /// (e.g., during initialization tiebreaker branches).
  Future<void> _clearKeycastSessionAndTokens() async {
    Object? firstError;
    StackTrace? firstStack;

    Future<void> deleteKey(Future<void> Function() delete) async {
      try {
        await delete();
      } catch (e, stack) {
        firstError ??= e;
        firstStack ??= stack;
      }
    }

    await deleteKey(() => KeycastSession.clear(_flutterSecureStorage));
    await deleteKey(() async {
      await _flutterSecureStorage?.delete(key: _kKeycastRefreshTokenKey);
    });
    await deleteKey(() async {
      await _flutterSecureStorage?.delete(key: _kKeycastAuthHandleKey);
    });

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
  }

  Future<void> _runSignOutCleanupWithRetry(
    String operation,
    Future<void> Function() cleanup,
  ) async {
    try {
      await cleanup();
      return;
    } catch (e, stack) {
      Log.warning(
        'signOut: $operation failed; retrying once: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _reportNonFatalAuthCleanupError(
        e,
        stack,
        'signOut $operation failed before retry',
      );
    }

    try {
      await cleanup();
    } catch (e, stack) {
      Log.error(
        'signOut: $operation failed after retry: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _reportNonFatalAuthCleanupError(
        e,
        stack,
        'signOut $operation failed after retry',
      );
    }
  }

  Future<void> _clearOAuthSessionForSignOut() async {
    if (_oauthClient != null) {
      await _runSignOutCleanupWithRetry('OAuth logout', _oauthClient.logout);
    }

    await _runSignOutCleanupWithRetry(
      'Keycast OAuth token cleanup',
      _clearKeycastSessionAndTokens,
    );
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
  Future<void> _reconnectBunker(
    NostrRemoteSignerInfo info, {
    bool boundedByStartupTimeout = false,
  }) async {
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
      _bunkerSigner = _remoteSignerFactory(RelayMode.baseMode, info);
      _setupBunkerAuthCallback();
      final connect = _bunkerSigner!.connect(sendConnectRequest: false);
      if (boundedByStartupTimeout) {
        await connect.timeout(_startupNetworkOperationTimeout);
      } else {
        await connect;
      }

      // Use saved public key if available, otherwise request it from bunker
      var userPubkey = info.userPubkey;
      if (userPubkey == null || userPubkey.isEmpty) {
        Log.info(
          'No saved userPubkey, requesting from bunker...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final pullPubkey = _bunkerSigner!.pullPubkey();
        userPubkey = boundedByStartupTimeout
            ? await pullPubkey.timeout(_startupNetworkOperationTimeout)
            : await pullPubkey;
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
        displayName: npub,
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
      _bunkerSigner?.close();
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

  /// Connect using a NIP-07 browser extension (Alby, nos2x, Nostore, etc.)
  ///
  /// Only valid on the web platform. On non-web targets this returns an
  /// [AuthResult.failure] immediately without touching auth state.
  Future<AuthResult> connectWithNip07() async {
    Log.info(
      'Connecting with NIP-07 browser extension...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    if (!kIsWeb && _injectedNip07ServiceForTest == null) {
      return AuthResult.failure(
        'NIP-07 browser extensions are only available on the web platform.',
      );
    }

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      final service = _injectedNip07ServiceForTest ?? Nip07Service();

      if (!service.isAvailable) {
        throw Exception(
          'No NIP-07 extension found. '
          'Please install Alby, nos2x, or another compatible extension.',
        );
      }

      final result = await service.connect();
      if (!result.success || result.publicKey == null) {
        throw Exception(result.errorMessage ?? 'NIP-07 authentication failed.');
      }

      final pubkey = result.publicKey!;
      _nip07Service = service;

      await _setupUserSession(
        SecureKeyContainer.fromPublicKey(pubkey),
        AuthenticationSource.nip07,
      );

      Log.info(
        'NIP-07 connection successful for user: $pubkey',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return const AuthResult(success: true);
    } catch (e) {
      Log.error(
        'NIP-07 connection failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _nip07Service = null;
      _lastError = 'NIP-07 connection failed: $e';
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

  /// Silent NIP-07 reconnect at startup.
  ///
  /// Browser extensions remember per-origin grants, so we can hydrate the
  /// session by calling getPublicKey() again. If the extension is no
  /// longer present or refuses, fall back to unauthenticated.
  Future<void> _reconnectNip07() async {
    if (!kIsWeb && _injectedNip07ServiceForTest == null) {
      _setAuthState(AuthState.unauthenticated);
      return;
    }
    final service = _injectedNip07ServiceForTest ?? Nip07Service();
    if (!service.isAvailable) {
      Log.info(
        'NIP-07 extension no longer available — falling back to '
        'unauthenticated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _setAuthState(AuthState.unauthenticated);
      return;
    }
    try {
      final result = await service.connect();
      if (!result.success || result.publicKey == null) {
        Log.info(
          'NIP-07 silent reconnect failed — falling back to '
          'unauthenticated: ${result.errorMessage}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        _setAuthState(AuthState.unauthenticated);
        return;
      }
      _nip07Service = service;
      await _setupUserSession(
        SecureKeyContainer.fromPublicKey(result.publicKey!),
        AuthenticationSource.nip07,
      );
    } catch (e, stackTrace) {
      Log.error(
        'NIP-07 reconnect failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
        stackTrace: stackTrace,
      );
      _nip07Service = null;
      _setAuthState(AuthState.unauthenticated);
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
        displayName: npub,
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
        '📱 Public key: ${keyContainer.npub}',
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
        '📱 Public key: ${keyContainer.npub}',
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

      _bunkerSigner = _remoteSignerFactory(RelayMode.baseMode, bunkerInfo);
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
  }) {
    if (_nostrConnectSession == null) {
      return Future.value(
        AuthResult.failure(
          'No active nostrconnect session. Call initiateNostrConnect first.',
        ),
      );
    }

    final activeWait = _nostrConnectWaitFuture;
    if (activeWait != null) return activeWait;

    final waitFuture = _waitForNostrConnectResponse(timeout: timeout);
    _nostrConnectWaitFuture = waitFuture;
    waitFuture.whenComplete(() {
      if (identical(_nostrConnectWaitFuture, waitFuture)) {
        _nostrConnectWaitFuture = null;
      }
    });
    return waitFuture;
  }

  Future<AuthResult> _waitForNostrConnectResponse({
    required Duration timeout,
  }) async {
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
        return AuthResult.nostrConnectFailure(
          NostrConnectFailureReason.cancelled,
        );
      }

      if (result == null) {
        // Timeout, cancellation, or a terminal session error.
        final state = session.state;
        _setAuthState(AuthState.unauthenticated);
        final reason = switch (state) {
          NostrConnectState.cancelled => NostrConnectFailureReason.cancelled,
          NostrConnectState.timeout => NostrConnectFailureReason.timedOut,
          NostrConnectState.error =>
            session.failureReason ??
                NostrConnectFailureReason.postConnectFailed,
          _ => NostrConnectFailureReason.postConnectFailed,
        };
        // `noExpectedSecret` is a programmer-invariant violation that "should
        // never happen": the response handler was reached with no secret to
        // validate against. Surface it to Crashlytics so a real break is
        // visible instead of reading as a routine "link expired" to the user.
        if (reason == NostrConnectFailureReason.noExpectedSecret) {
          _reportAuthError(
            StateError(
              'nostrconnect response handling reached with no expected secret',
            ),
            StackTrace.current,
            reason: 'NostrConnect.noExpectedSecret',
            logMessage:
                'nostrconnect invariant violated: no expected secret to validate',
          );
        }
        return AuthResult.nostrConnectFailure(reason);
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
      _bunkerSigner = _remoteSignerFactory(RelayMode.baseMode, result.info);
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

      return AuthResult.nostrConnectFailure(
        NostrConnectFailureReason.postConnectFailed,
      );
    }
  }

  /// Cancel an active nostrconnect:// session.
  ///
  /// Safe to call even if no session is active.
  void cancelNostrConnect() {
    _nostrConnectWaitFuture = null;
    _isNostrConnectCallbackHandoffActive = false;
    _nostrConnectCallbackHandoffTimer?.cancel();
    _nostrConnectCallbackHandoffTimer = null;
    _nostrConnectCallbackHandoffCancelTimer?.cancel();
    _nostrConnectCallbackHandoffCancelTimer = null;

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

  /// True while Android/iOS custom-scheme routing is handing control back
  /// from a NIP-46 signer app to Divine.
  bool get isNostrConnectCallbackHandoffActive =>
      _isNostrConnectCallbackHandoffActive;

  /// Preserve the active session for the replacement NostrConnect screen.
  ///
  /// If no replacement screen claims the handoff quickly, cancel the session so
  /// backing out during the callback route handoff cannot orphan relay sockets.
  void preserveNostrConnectForCallbackHandoff() {
    if (!_isNostrConnectCallbackHandoffActive ||
        _nostrConnectSession?.state != NostrConnectState.listening) {
      return;
    }

    _nostrConnectCallbackHandoffCancelTimer?.cancel();
    _nostrConnectCallbackHandoffCancelTimer = Timer(
      const Duration(seconds: 5),
      () {
        _nostrConnectCallbackHandoffCancelTimer = null;
        if (_isNostrConnectCallbackHandoffActive &&
            _nostrConnectSession?.state == NostrConnectState.listening) {
          Log.info(
            'NostrConnect callback handoff was not resumed - cancelling',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          cancelNostrConnect();
        }
      },
    );
  }

  /// Marks the callback handoff as claimed by a mounted NostrConnect screen.
  ///
  /// The short handoff flag is left to expire on its own so an old route that
  /// disposes after the replacement screen mounts still preserves the session.
  void claimNostrConnectCallbackHandoff() {
    _nostrConnectCallbackHandoffCancelTimer?.cancel();
    _nostrConnectCallbackHandoffCancelTimer = null;
  }

  /// Called when a divine:// signer callback deep link is received.
  ///
  /// Ensures the nostrconnect session relay connections are alive so we
  /// don't miss the bunker's response event after being brought back
  /// from background.
  void onSignerCallbackReceived({String? relayUrl}) {
    if (_nostrConnectSession?.state != NostrConnectState.listening) {
      return;
    }

    _isNostrConnectCallbackHandoffActive = true;
    _nostrConnectCallbackHandoffTimer?.cancel();
    _nostrConnectCallbackHandoffTimer = Timer(const Duration(seconds: 5), () {
      _isNostrConnectCallbackHandoffActive = false;
    });

    if (relayUrl != null) {
      Log.info(
        'Signer callback supplied relay $relayUrl - connecting',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      unawaited(_nostrConnectSession!.addRelay(relayUrl));
    }
    Log.info(
      'Signer callback received - ensuring nostrconnect relays are connected',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    unawaited(_nostrConnectSession!.ensureConnected());
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
      _keycastSigner = KeycastRpc.fromSession(
        _oauthConfig,
        session,
        onTokenRefresh: _refreshAccessToken,
      );

      // Prefer the pubkey stored in the session over an RPC call.
      // session.userPubkey is ground truth once populated — it is
      // bound to the session at the first sign-in, so subsequent
      // reads get a pubkey that cannot mismatch the token.
      String? publicKeyHex = session.userPubkey;
      if (publicKeyHex == null || publicKeyHex.isEmpty) {
        publicKeyHex = await _keycastSigner?.getPublicKey();
      }
      if (publicKeyHex == null) {
        throw Exception('Could not retrieve public key from server');
      }

      // If the session was created before userPubkey was populated
      // (legacy or fresh from fromTokenResponse), bind the pubkey now
      // and re-save. This is the fix for Bug 2: every saved session
      // must carry its owning pubkey so subsequent archive/restore
      // operations can validate ownership.
      if (session.userPubkey == null || session.userPubkey!.isEmpty) {
        final boundSession = session.copyWith(userPubkey: publicKeyHex);
        await boundSession.save(_flutterSecureStorage);
        Log.debug(
          'signInWithDivineOAuth: bound userPubkey=$publicKeyHex to '
          'session and re-saved',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      _currentProfile = UserProfile(
        npub: NostrKeyUtils.encodePubKey(publicKeyHex),
        publicKeyHex: publicKeyHex,
        displayName: 'Divine User',
      );

      // Do not pre-write current_user_pubkey_hex here: _setupUserSession
      // calls shouldClearDataForUser which compares the stored pubkey
      // against the incoming one. Writing the new value first would
      // mask identity changes. _setupUserSession writes it after the
      // check.
      await _clearDismissedDivineLoginBannerForCurrentUser(publicKeyHex);

      Log.info(
        '✅ Divine oauth listener setting auth state to authenticated.',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _profileController.add(_currentProfile);

      // Load the locally-stored nsec matching publicKeyHex so
      // _buildIdentity can attach a LocalKeySigner to the KeycastNostrIdentity.
      // Without this, every signEvent / nip44Decrypt round-trips through
      // Keycast RPC (200-500ms) even though the nsec is on device. Mirrors
      // the local-first restore path used during cold start.
      final npub = NostrKeyUtils.encodePubKey(publicKeyHex);
      SecureKeyContainer? localKey;
      try {
        localKey = await _keyStorage.getIdentityKeyContainer(npub);
        if (localKey == null && await _keyStorage.hasKeys()) {
          final primary = await _keyStorage.getKeyContainer();
          if (primary != null &&
              primary.hasPrivateKey &&
              primary.publicKeyHex == publicKeyHex) {
            localKey = primary;
          }
        }
      } catch (e) {
        Log.warning(
          'signInWithDivineOAuth: local key lookup failed: $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      final SecureKeyContainer keyContainer;
      if (localKey != null && localKey.hasPrivateKey) {
        keyContainer = localKey;
        Log.info(
          'signInWithDivineOAuth: using local nsec for fast signing '
          '(pubkey=$publicKeyHex)',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } else {
        keyContainer = SecureKeyContainer.fromPublicKey(publicKeyHex);
        Log.info(
          'signInWithDivineOAuth: no matching local nsec — '
          'signing via RPC (pubkey=$publicKeyHex)',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
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
  /// When [deleteKeys] is true, the current account's local login material is
  /// removed from the device.
  ///
  /// When [deleteLocalUserData] is true, owner-scoped local rows for the
  /// current account are also deleted. Keep this false for "Remove this account
  /// from this device" so device-local drafts/clips survive re-login. Use true
  /// only for flows that explicitly delete the account and its local data.
  ///
  /// When [abortOnKeyDeletionFailure] is true (only meaningful with
  /// [deleteKeys]), platform key deletion is attempted **before** any
  /// session cleanup. If deletion fails the method throws immediately and
  /// no cleanup happens — the user stays signed in and can retry.
  /// Use this for the "Remove this account from this device" flow where
  /// signing out without actually removing local login material is
  /// counter-productive.
  ///
  /// When [abortOnKeyDeletionFailure] is false (default), key deletion
  /// failure is captured and rethrown **after** all cleanup completes.
  /// Use this for "Delete Account" where sign-out must finish regardless.
  Future<void> signOut({
    bool deleteKeys = false,
    bool abortOnKeyDeletionFailure = false,
    bool deleteLocalUserData = false,
  }) async {
    final pubkeyAtSignOutStart = _currentKeyContainer?.publicKeyHex;
    final npubAtSignOutStart = _currentKeyContainer?.npub;
    Log.info(
      'signOut: starting — '
      'authSource=${_authSource.name}, '
      'deleteKeys=$deleteKeys, '
      'abortOnKeyDeletionFailure=$abortOnKeyDeletionFailure, '
      'deleteLocalUserData=$deleteLocalUserData, '
      'currentPubkey=${_currentKeyContainer?.publicKeyHex ?? "null"}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Pre-flight: when the caller needs key deletion to succeed before
    // sign-out proceeds, attempt it now. If this throws, no cleanup has
    // happened and the user stays signed in.
    if (deleteKeys && abortOnKeyDeletionFailure) {
      await _deleteStoredLoginForAccount(npubAtSignOutStart);
    }

    Object? keyDeletionError;
    Object? userDataCleanupError;

    await _runBeforeSessionTeardownCallbacks();

    try {
      // Clear TOS acceptance on any logout - user must re-accept when logging
      // back in
      final prefs = await SharedPreferences.getInstance();
      final currentPubkey = _currentKeyContainer?.publicKeyHex;

      // Capture the leaving account as the session recovery anchor BEFORE any
      // teardown — but only for non-destructive sign-out (account switch).
      //
      // The welcome screen reads this after sign-out to detect when a cold-
      // start restore would land on a different account, and surfaces a
      // confirmation banner so the user can redirect the switch explicitly.
      //
      // On DESTRUCTIVE sign-out (deleteKeys=true), the user is intentionally
      // removing the account. Clear any stale anchor so the next app start
      // returns to the welcome/account-picker surface instead of treating the
      // removal as an interrupted account switch.
      //
      // The anchor is cleared by _setupUserSession() after a successful sign-in.
      final leavingNpub = _currentKeyContainer?.npub;
      if (!deleteKeys && leavingNpub != null) {
        await prefs.setString(_kSessionRecoveryAnchorKey, leavingNpub);
        Log.debug(
          'signOut: recorded session recovery anchor=$leavingNpub',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } else {
        // Destructive sign-out: clear any stale anchor so the remaining
        // account's automatic restore is not blocked by the guard in
        // _restoreDivineRpcOrFallbackUnauthenticated.
        await prefs.remove(_kSessionRecoveryAnchorKey);
        Log.debug(
          'signOut: cleared session recovery anchor '
          '(deleteKeys=$deleteKeys)',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      // On destructive sign-out, remove this device's local login for the
      // current account and then return to the welcome/account-picker surface.
      // Deferred: remaining-account cleanup runs after _removeFromKnownAccounts
      // so the deleted account is excluded from the remaining list.
      // Non-destructive sign-out (switch account) preserves these so that
      // initialize() can reconnect to the same external signer.
      await prefs.remove('age_verified_16_plus');
      await prefs.remove('terms_accepted_at');

      // Clear user-specific cached data on explicit logout.
      // Owner-scoped local rows (drafts, clips, uploads, etc.) are only
      // deleted when the caller explicitly opts in. Removing local login
      // material from the device is not enough reason to destroy local work.
      if (deleteKeys && !deleteLocalUserData && currentPubkey != null) {
        await _userDataCleanupService.markOwnerScopedLegacyDataForUser(
          currentPubkey,
        );
      }
      try {
        await _userDataCleanupService.clearUserSpecificData(
          reason: 'explicit_logout',
          userPubkey: currentPubkey,
          deleteUserData: deleteLocalUserData,
        );
      } catch (e) {
        userDataCleanupError = e;
        Log.error(
          'User data cleanup failed during signOut: $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      // Clear configured relays so next login re-discovers from NIP-65
      await prefs.remove('configured_relays');

      // Clear relay discovery cache so next login re-queries indexers
      // (even for same-user re-login, relays may have changed)
      await _relayDiscoveryService.clearCache(_currentKeyContainer?.npub ?? '');

      // Clear the stored pubkey tracking so next login is treated as new
      await prefs.remove('current_user_pubkey_hex');

      // Multi-account: archive or remove this account's signer info
      // Account-scoped CacheSync invalidation. Cache keys follow
      // `${pubkey}:${operation}` (RFC #4244), so this clears the
      // leaving account only and leaves other accounts intact.
      // Wrapped in try/catch so a cache-layer failure does not abort
      // the rest of signOut; the failure is forwarded to Crashlytics
      // so a silent disk-residency regression is visible.
      if (currentPubkey != null) {
        try {
          await CacheSync.invalidatePrefix(currentPubkey);
        } catch (e, stack) {
          Log.error(
            'CacheSync.invalidatePrefix failed during signOut: $e',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _reportStorageError(e, stack, 'signOut cache invalidation');
        }
      }

      if (deleteKeys) {
        // Destructive sign-out: remove from known accounts and clean up
        if (currentPubkey != null) {
          await _removeFromKnownAccounts(currentPubkey);
          await _clearArchivedSignerInfo(currentPubkey);
        }

        Log.debug(
          '📱️ Deleting local login material',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        // Isolate key deletion so that a failure does not short-circuit
        // the remaining cleanup (session, signers, auth state). The error
        // is rethrown after cleanup completes so callers can warn the user.
        // Skip if already handled by the pre-flight check above.
        if (!abortOnKeyDeletionFailure) {
          try {
            await _deleteStoredLoginForAccount(leavingNpub);
          } catch (e) {
            keyDeletionError = e;
            Log.error(
              'Local login deletion failed during signOut: $e',
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
      _onBootstrapRelayListRequested = null;
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
      _setRpcCapability(AuthRpcCapability.unavailable);

      // Detach any in-flight token refresh so post-signout logins start a
      // fresh attempt instead of joining one issued for the outgoing
      // session. The futures cannot be cancelled, but their completion
      // handlers only release the slot they still own (identical check),
      // so a late completion cannot clobber a newer attempt.
      _pendingOAuthRefresh = null;
      _pendingRefresh = null;

      await _clearOAuthSessionForSignOut();

      // Reset recovery prefs AFTER all signer cleanup so removed accounts
      // cannot silently recover. Any remaining restorable accounts stay in the
      // known-account picker instead of being auto-restored.
      if (deleteKeys) {
        await _resetRecoveryAfterLocalAccountRemoval(prefs);
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

      // In the Remove Keys flow, key deletion has already succeeded before
      // cleanup starts. Do not leave the app in an authenticated in-memory
      // state with no keys on disk if a secondary cleanup step fails.
      if (deleteKeys && abortOnKeyDeletionFailure) {
        await _completeDestructiveSignOutAfterDeletedKeys(
          removedPubkey: pubkeyAtSignOutStart,
          failure: e,
        );
      }
    }

    // After all cleanup, propagate key deletion failure so callers can
    // warn the user that keys may still be on the device.
    if (keyDeletionError != null) {
      throw SecureKeyStorageException(
        'Signed out but key deletion failed: $keyDeletionError',
      );
    }
    if (userDataCleanupError != null && deleteLocalUserData) {
      throw UserDataCleanupException(
        'Signed out but local user data cleanup failed',
        userDataCleanupError,
      );
    }
  }

  Future<void> _deleteStoredLoginForAccount(String? npub) async {
    if (npub == null) {
      await _keyStorage.deleteKeys();
      return;
    }

    await _keyStorage.deleteIdentityKeyContainer(npub);

    final primaryContainer = await _keyStorage.getKeyContainer();
    if (primaryContainer == null || primaryContainer.npub == npub) {
      await _keyStorage.deleteKeys();
      return;
    }

    Log.info(
      'Preserving PRIMARY key while removing account-local login material: '
      'removedNpub=$npub primaryNpub=${primaryContainer.npub}',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }

  Future<void> _runBeforeSessionTeardownCallbacks() async {
    if (_beforeSessionTeardownCallbacks.isEmpty) return;

    final callbacks = List<BeforeSessionTeardownCallback>.of(
      _beforeSessionTeardownCallbacks,
    );
    final deadline = DateTime.now().add(_kBeforeSessionTeardownTimeout);

    for (final callback in callbacks) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        Log.warning(
          'Before-session teardown callbacks timed out',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }

      try {
        await callback().timeout(remaining);
      } on TimeoutException catch (e) {
        Log.warning(
          'Before-session teardown callback timed out: $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        continue;
      } catch (e) {
        Log.warning(
          'Before-session teardown callback failed: $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    }
  }

  Future<void> _completeDestructiveSignOutAfterDeletedKeys({
    required String? removedPubkey,
    required Object failure,
  }) async {
    Log.warning(
      'signOut: completing destructive sign-out after cleanup failure: $failure',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    final prefs = await SharedPreferences.getInstance();

    if (removedPubkey != null) {
      try {
        await _removeFromKnownAccounts(removedPubkey);
        await _clearArchivedSignerInfo(removedPubkey);
      } catch (e) {
        Log.warning(
          'signOut: failed to remove deleted account from known accounts: $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    }

    _currentIdentity = null;
    _currentKeyContainer?.dispose();
    _currentKeyContainer = null;
    _currentProfile = null;
    _lastError = null;
    _onUserRelaysDiscovered = null;
    _onBootstrapRelayListRequested = null;
    _userRelays = [];
    _bunkerSigner?.close();
    _bunkerSigner = null;
    try {
      await _clearBunkerInfo();
    } catch (_) {}
    _amberSigner?.close();
    _amberSigner = null;
    try {
      await _clearAmberInfo();
    } catch (_) {}
    _keycastSigner = null;
    _setRpcCapability(AuthRpcCapability.unavailable);
    _keyStorage.clearCache();

    await _clearOAuthSessionForSignOut();

    await prefs.remove(_kSessionRecoveryAnchorKey);
    await prefs.remove('age_verified_16_plus');
    await prefs.remove('terms_accepted_at');
    await prefs.remove('configured_relays');
    await prefs.remove('current_user_pubkey_hex');
    await _resetRecoveryAfterLocalAccountRemoval(prefs);

    _setAuthState(AuthState.unauthenticated);
  }

  /// After removing the active account from this device, keep only known
  /// accounts that still have restorable local login material and reset
  /// automatic recovery. This returns the app to the welcome screen:
  /// fresh-login when no accounts remain, or the returning-user picker when
  /// other local accounts are still available.
  Future<void> _resetRecoveryAfterLocalAccountRemoval(
    SharedPreferences prefs,
  ) async {
    try {
      final remaining = await getKnownAccounts();
      final restorableAccounts = await _restorableAccounts(remaining);

      _authSource = AuthenticationSource.none;
      await prefs.setString(_kAuthSourceKey, AuthenticationSource.none.code);
      await prefs.remove(_kLastUsedNpubKey);

      if (restorableAccounts.isEmpty) {
        await prefs.setString(kKnownAccountsKey, jsonEncode(<Object>[]));
        Log.info(
          'signOut: no restorable local accounts — reset to fresh welcome',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }

      restorableAccounts.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      await prefs.setString(
        kKnownAccountsKey,
        jsonEncode(restorableAccounts.map((a) => a.toJson()).toList()),
      );

      Log.info(
        'signOut: kept ${restorableAccounts.length} restorable local '
        'account(s) for the welcome picker',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      // Best-effort: if this fails, the fallback scan in
      // _restoreLastUsedAccountOrFallback will still find the account.
      Log.warning(
        'signOut: failed to reset local-account recovery prefs: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _authSource = AuthenticationSource.none;
      await prefs.setString(_kAuthSourceKey, AuthenticationSource.none.code);
      await prefs.remove(_kLastUsedNpubKey);
      await prefs.setString(kKnownAccountsKey, jsonEncode(<Object>[]));
    }
  }

  Future<List<KnownAccount>> _restorableAccounts(
    List<KnownAccount> accounts,
  ) async {
    final restorable = <KnownAccount>[];
    for (final account in accounts) {
      switch (account.authSource) {
        case AuthenticationSource.automatic:
        case AuthenticationSource.importedKeys:
          if (await _hasRestorableLocalKey(account)) {
            restorable.add(account);
          }
        case AuthenticationSource.amber:
        case AuthenticationSource.bunker:
        case AuthenticationSource.divineOAuth:
          if (await _hasRestorableSignerArchive(account)) {
            restorable.add(account);
          }
        case AuthenticationSource.none:
        case AuthenticationSource.nip07:
          break;
      }
    }
    return restorable;
  }

  Future<bool> _hasRestorableLocalKey(KnownAccount account) async {
    final npub = NostrKeyUtils.encodePubKey(account.pubkeyHex);
    try {
      final identityContainer = await _keyStorage.getIdentityKeyContainer(npub);
      if (identityContainer?.publicKeyHex == account.pubkeyHex) {
        return true;
      }

      if (await _keyStorage.hasKeys()) {
        final primaryContainer = await _keyStorage.getKeyContainer();
        if (primaryContainer?.publicKeyHex == account.pubkeyHex) {
          return true;
        }
      }
    } catch (e) {
      Log.warning(
        'signOut: failed to verify local nsec for ${account.pubkeyHex}: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
    return false;
  }

  Future<bool> _hasRestorableSignerArchive(KnownAccount account) async {
    if (_flutterSecureStorage == null) return false;
    try {
      switch (account.authSource) {
        case AuthenticationSource.amber:
          final pubkey = await _flutterSecureStorage.read(
            key: '${_kAmberPubkeyKey}_${account.pubkeyHex}',
          );
          return pubkey != null && pubkey.isNotEmpty;
        case AuthenticationSource.bunker:
          final bunkerUrl = await _flutterSecureStorage.read(
            key: '${_kBunkerInfoKey}_${account.pubkeyHex}',
          );
          return bunkerUrl != null && bunkerUrl.isNotEmpty;
        case AuthenticationSource.divineOAuth:
          final sessionJson = await _flutterSecureStorage.read(
            key: _keycastSessionKey(account.pubkeyHex),
          );
          if (sessionJson == null || sessionJson.isEmpty) return false;
          final sessionMap = jsonDecode(sessionJson) as Map<String, dynamic>;
          final session = KeycastSession.fromJson(sessionMap);
          return session.userPubkey == account.pubkeyHex;
        case AuthenticationSource.automatic:
        case AuthenticationSource.importedKeys:
        case AuthenticationSource.none:
        case AuthenticationSource.nip07:
          return false;
      }
    } catch (e) {
      Log.warning(
        'signOut: failed to verify signer archive for '
        '${account.pubkeyHex}: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return false;
    }
  }

  /// Export nsec for backup purposes
  Future<String?> exportNsec({String? biometricPrompt}) async {
    if (!isAuthenticated) return null;

    if (authenticationSource != AuthenticationSource.automatic &&
        authenticationSource != AuthenticationSource.importedKeys &&
        authenticationSource != AuthenticationSource.divineOAuth) {
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

      if (authenticationSource == AuthenticationSource.divineOAuth) {
        Log.warning(
          'Exporting nsec for divineOAuth requires a local private key',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return null;
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
  @override
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

      if (!Nip89ClientTag.shouldSkipKind(kind) &&
          !Nip89ClientTag.hasClientTag(eventTags) &&
          await Nip89ClientTag.isEnabled()) {
        eventTags.add(Nip89ClientTag.tag);
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
        Log.error('Signing failed: Signer returned null', name: 'AuthService');
        return null;
      }

      // Guard against a signer returning an event bound to a different
      // account than the active identity (e.g. a remote signer whose
      // backend swapped the authorized key). isSigned/isValid only prove
      // the signature and id are self-consistent for the event's own
      // pubkey — not that it is the account we intended to sign as. Cheap
      // string compare; runs for every signer, local or remote. Throwing
      // (rather than returning null) keeps this off the frozen sentinel
      // ceiling and surfaces the invariant violation via Reportable in the
      // catch below. #5450.
      if (signedEvent.pubkey != identity.pubkey) {
        throw EventSignerAccountMismatchException(
          expectedPubkey: identity.pubkey,
          actualPubkey: signedEvent.pubkey,
        );
      }

      // Re-verifying a signature we just produced with our own in-process
      // key only exercises the crypto library and costs a full schnorr
      // verification per event (hot on the feed-scroll signing path). Skip
      // it for local signers; remote/external signers cross a trust
      // boundary, so their returned signature is still verified. The cheap
      // structural check (isValid: id == hash) below always runs.
      if (!identity.signsWithLocalKey && !signedEvent.isSigned) {
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
    } catch (e, stackTrace) {
      Log.error(
        'Failed to create or sign event: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      // An event signed for a different account is an invariant violation
      // (YES on the Reportable matrix), not an expected domain/network
      // failure — surface it to Crashlytics. Other errors keep the existing
      // log-only behavior to avoid flooding the dashboard.
      if (e is EventSignerAccountMismatchException) {
        _reportAuthError(
          Reportable(e, context: 'createAndSignEvent'),
          stackTrace,
          reason: 'Signer returned an event for a different account',
          logMessage: 'Signer account mismatch during createAndSignEvent',
        );
      }
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
        final cachedPrimaryIdentity = await _restoreFromLoadedPrimaryIdentity(
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
  Future<bool> _tryRestoreFromKnownAccounts(AuthenticationSource source) async {
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

  /// Fast path: reuse the PRIMARY key when it matches the last-used npub,
  /// avoiding a redundant per-identity storage read.
  ///
  /// Reads the primary container from [SecureKeyStorage] — a cache hit when it
  /// was already loaded during init, otherwise a single platform read. The
  /// npub guard keeps the reuse correct.
  Future<SecureKeyContainer?> _restoreFromLoadedPrimaryIdentity(
    String lastNpub,
  ) async {
    final SecureKeyContainer? primary;
    try {
      primary = await _keyStorage.getKeyContainer();
    } catch (e) {
      Log.warning(
        '_restoreFromLoadedPrimaryIdentity: failed to load primary identity: '
        '$e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }

    if (primary == null || !primary.hasPrivateKey) {
      return null;
    }

    final primaryNpub = NostrKeyUtils.encodePubKey(primary.publicKeyHex);
    if (primaryNpub != lastNpub) {
      return null;
    }

    String? privateKeyHex;
    primary.withPrivateKey<void>((hex) => privateKeyHex = hex);
    if (privateKeyHex == null || privateKeyHex!.isEmpty) {
      return null;
    }

    try {
      return SecureKeyContainer.fromPrivateKeyHex(privateKeyHex!);
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

    // Priority: Amber > NIP-07 > Bunker > Keycast > Local
    if (_amberSigner case final signer?) {
      return AmberNostrIdentity(pubkey: pubkey, amberSigner: signer);
    }
    if (_nip07Service case final service?) {
      return Nip07NostrIdentity(
        pubkey: pubkey,
        nip07Signer: Nip07SignerAdapter(service),
      );
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
      _setRpcCapability(AuthRpcCapability.unavailable);
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
    if (source != AuthenticationSource.nip07 && _nip07Service != null) {
      Log.info(
        '_setupUserSession: clearing stale NIP-07 service '
        '(new source=${source.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _nip07Service = null;
    }

    // Build atomic identity AFTER stale signers are cleared.
    _currentIdentity = _buildIdentity();

    // Create user profile
    _currentProfile = UserProfile(
      npub: keyContainer.npub,
      publicKeyHex: keyContainer.publicKeyHex,
      displayName: keyContainer.npub,
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
        final oldPubkey = prefs.getString('current_user_pubkey_hex');
        Log.info(
          '_setupUserSession: identity change detected — '
          'clearing shared caches for old pubkey '
          '${oldPubkey ?? "unknown"} '
          '(owner-scoped drafts/clips/uploads preserved)',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        // Do NOT pass deleteUserData: true here. Owner-scoped rows (drafts,
        // clips, pending uploads) are already invisible to the incoming account
        // because every query filters by ownerPubkey. Deleting them here would
        // cause permanent data loss on account switch and mismatched re-login.
        // Destructive per-user DAO deletion is reserved for account deletion
        // (signOut(deleteKeys: true, deleteLocalUserData: true)).
        await _userDataCleanupService.clearUserSpecificData(
          reason: 'identity_change',
          isIdentityChange: true,
          userPubkey: oldPubkey,
          // deleteUserData omitted — defaults to false. Owner-scoped rows
          // (drafts, clips, uploads) are already invisible to the incoming
          // account via ownerPubkey filtering; no deletion is needed here.
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

      // Claim legacy database rows (NULL ownerPubkey) for this user so
      // pre-multi-account drafts/clips are attributed and no longer
      // visible to other accounts.
      await _userDataCleanupService.claimLegacyRows(keyContainer.publicKeyHex);

      await prefs.setString(_kAuthSourceKey, source.code);

      await prefs.setString(_kLastUsedNpubKey, keyContainer.npub);

      // Clear the session recovery anchor now that the user has explicitly
      // signed in. A stale anchor must not persist to interfere with future
      // welcome-screen mismatch detection after the next sign-out.
      await prefs.remove(_kSessionRecoveryAnchorKey);

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
      final targetPubkey =
          _currentIdentity?.pubkey ?? _currentKeyContainer?.publicKeyHex;
      await Future.wait([
        _discoverUserRelays(npub, targetPubkey),
        _checkExistingProfile(),
      ]);
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
  Future<void> _discoverUserRelays(String npub, String? targetPubkey) async {
    try {
      final result = await _relayDiscoveryService.discoverRelays(npub);
      if (!_isRelayDiscoveryCurrent(targetPubkey)) {
        Log.info(
          'Ignoring relay discovery result for stale session',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }

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
        _onUserRelaysDiscovered?.call(targetPubkey ?? npub, urls);
      } else {
        _userRelays = [];

        Log.warning(
          '⚠️ No relay list found for user on any indexer — '
          'connecting to safe DM-friendly fallback relay set',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        _connectToFallbackRelays(targetPubkey ?? npub);
        await _publishBootstrapRelayList();
      }
    } catch (e) {
      if (!_isRelayDiscoveryCurrent(targetPubkey)) {
        Log.info(
          'Ignoring relay discovery failure for stale session',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }
      _userRelays = [];

      Log.error(
        '❌ Relay discovery failed: $e — '
        'connecting to safe DM-friendly fallback relay set',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _connectToFallbackRelays(targetPubkey ?? npub);
      await _publishBootstrapRelayList();
    }
  }

  bool _isRelayDiscoveryCurrent(String? targetPubkey) =>
      targetPubkey == null || _currentIdentity?.pubkey == targetPubkey;

  /// Publish a bootstrap kind:10002 relay list for the signed-in user when
  /// indexer discovery returned empty.
  ///
  /// Divine/Keycast-provisioned accounts are created without a published
  /// NIP-65 relay list, which leaves them invisible to the indexers the
  /// mobile client queries (`purplepag.es`, `user.kindpag.es`,
  /// `relay.nos.social`). That in turn degrades reachability for every
  /// downstream publish operation (profile save, likes, comments) because
  /// the client can only connect to the fallback relay set. This method
  /// self-publishes a minimal kind:10002 pointing at [_primaryRelayUrl] (the
  /// current environment's primary relay, injected from
  /// [EnvironmentConfig.relayUrl]) so subsequent logins on this or any other
  /// client can discover it.
  ///
  /// Guards:
  /// - fires at most once per (device, pubkey): tracked via
  ///   [SharedPreferences] flag `bootstrap_kind10002_published_<hexpubkey>`.
  /// - no-op if no [currentIdentity] (read-only / unauthenticated sessions).
  /// - no-op if no bootstrap callback has been registered.
  /// - flag is set ONLY on callback success, so failures (signer unreachable,
  ///   publish rejected) remain retriable on next login.
  ///
  /// The proper server-side fix lives in divinevideo/keycast#94; this is a
  /// client-side safety net + backfill for pre-existing accounts. See
  /// divinevideo/divine-mobile#3174.
  Future<void> _publishBootstrapRelayList() async {
    final identity = _currentIdentity;
    if (identity == null) {
      return;
    }
    final callback = _onBootstrapRelayListRequested;
    if (callback == null) {
      return;
    }
    final pubkeyHex = identity.pubkey;
    final flagKey = '$_kBootstrapKind10002Prefix$pubkeyHex';

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(flagKey) ?? false) {
        return;
      }

      final unsigned = Event(
        pubkeyHex,
        EventKind.relayListMetadata,
        <List<String>>[
          <String>['r', _primaryRelayUrl],
        ],
        '',
      );

      // Cap how long we wait for the signer. A hung Keycast RPC would
      // otherwise block first-login past the existing NIP-65 discovery
      // timeout. On timeout we leave the flag unset so the next login retries.
      final Event? signed;
      try {
        signed = await identity
            .signEvent(unsigned)
            .timeout(_kBootstrapSignTimeout);
      } on TimeoutException {
        Log.warning(
          'Bootstrap kind:10002: signer timed out after '
          '${_kBootstrapSignTimeout.inSeconds}s — will retry on next login',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }

      if (signed == null || signed.sig.isEmpty) {
        Log.warning(
          'Bootstrap kind:10002: signer returned null / unsigned — will retry '
          'on next login',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }

      final targetRelays = <String>[
        _primaryRelayUrl,
        ...IndexerRelayConfig.defaultIndexers,
      ];

      final published = await callback(signed, targetRelays);
      if (!published) {
        Log.warning(
          'Bootstrap kind:10002: NostrClient reported no relay accepted the '
          'event — will retry on next login',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }

      await prefs.setBool(flagKey, true);
      Log.info(
        '✅ Published bootstrap kind:10002 for $pubkeyHex to '
        '${targetRelays.length} relays',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Bootstrap kind:10002 publish failed: $e — will retry on next login',
        name: 'AuthService',
        category: LogCategory.auth,
      );
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
  void _connectToFallbackRelays(String targetPubkey) {
    Log.info(
      'Fallback relays: '
      '${IndexerRelayConfig.safeFallbackRelays.join(', ')}',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    _onUserRelaysDiscovered?.call(
      targetPubkey,
      IndexerRelayConfig.safeFallbackRelays,
    );
  }

  /// Test seam exposing the private NIP-65 discovery routine so unit
  /// tests can drive the fallback path with a mocked discovery service.
  /// Production callers should not invoke this — discovery runs as part
  /// of the normal sign-in flow via [_setupUserSession].
  @visibleForTesting
  Future<void> debugDiscoverUserRelays(String npub) =>
      _discoverUserRelays(npub, _currentIdentity?.pubkey);

  /// Test seam that lets unit tests install a [NostrIdentity] without
  /// going through the full sign-in pipeline. Used by tests that exercise
  /// code paths (e.g. [_publishBootstrapRelayList]) which depend on
  /// [currentIdentity] being set.
  @visibleForTesting
  void debugSetIdentity(NostrIdentity? identity) {
    _currentIdentity = identity;
  }

  /// Test seam that lets unit tests install a [SecureKeyContainer] so
  /// `signOut`'s account-scoped invalidation (and any other code path
  /// keyed on the current pubkey) can be exercised without driving the
  /// full sign-in pipeline.
  ///
  /// **Scope warning**: this only sets `_currentKeyContainer`. It does
  /// not touch `_authSource`, `_currentIdentity`, signer wiring, auth
  /// state, or any other field that real sign-in initialises. Safe for
  /// tests that exercise branches keyed solely on `_currentKeyContainer`
  /// (e.g. the pubkey-capture step in `signOut`); using it as a general
  /// "pretend to be signed in" shim will produce inconsistent state.
  @visibleForTesting
  void debugSetCurrentKeyContainer(SecureKeyContainer? container) {
    _currentKeyContainer = container;
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
    'npub': currentNpub,
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

    unawaited(_refreshOAuthTokenOnResume());
  }

  Future<void> _refreshOAuthTokenOnResume() async {
    try {
      if (_oauthClient == null || _keycastSigner == null) return;

      final resumeOwnerPubkey = currentPublicKeyHex;
      if (resumeOwnerPubkey == null) return;
      bool resumeContextStillCurrent() =>
          _authState == AuthState.authenticated &&
          currentPublicKeyHex == resumeOwnerPubkey;

      final session = await _oauthClient.getSession();
      if (!resumeContextStillCurrent()) return;
      if (session != null) return;

      Log.info(
        '📱 App resumed - OAuth token expired, refreshing',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      final refreshed = await _refreshOAuthSession(
        expectedOwnerPubkey: resumeOwnerPubkey,
      );
      if (!resumeContextStillCurrent()) {
        Log.warning(
          '📱 App resumed - discarding stale OAuth refresh result',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }
      if (refreshed != null) {
        _keycastSigner = KeycastRpc.fromSession(
          _oauthConfig,
          refreshed,
          onTokenRefresh: _refreshAccessToken,
        );
        _currentIdentity = _buildIdentity();
        _setRpcCapability(AuthRpcCapability.rpcReady);
      }
    } catch (e) {
      Log.error(
        '📱 App resumed - OAuth refresh failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
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

    _nostrConnectCallbackHandoffTimer?.cancel();
    _nostrConnectCallbackHandoffTimer = null;
    _nostrConnectCallbackHandoffCancelTimer?.cancel();
    _nostrConnectCallbackHandoffCancelTimer = null;

    // Securely dispose of key container
    _currentKeyContainer?.dispose();
    _currentKeyContainer = null;

    await _authStateController.close();
    await _profileController.close();
    await _rpcCapabilityController.close();
    _keyStorage.dispose();
  }
}
