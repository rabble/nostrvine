// ABOUTME: State machine for managing client-initiated NIP-46 nostrconnect://
// ABOUTME: connections. Handles keypair generation, relay listening, and
// ABOUTME: bunker response validation.

import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../event.dart';
import '../event_kind.dart';
import '../filter.dart';
import '../nip19/nip19.dart';
import '../relay/client_connected.dart';
import '../relay/relay.dart';
import '../relay/relay_base.dart';
import '../relay/relay_mode.dart';
import '../relay/relay_status.dart';
import '../signer/local_nostr_signer.dart';
import '../utils/string_util.dart';
import 'nostr_remote_response.dart';
import 'nostr_remote_signer_info.dart';

/// State of a nostrconnect:// session.
enum NostrConnectState {
  /// Session not started.
  idle,

  /// Generating keypair and URL.
  generating,

  /// Listening on relays for bunker response.
  listening,

  /// Bunker responded and connection successful.
  connected,

  /// Connection timed out waiting for bunker.
  timeout,

  /// Session was cancelled by user.
  cancelled,

  /// An error occurred.
  error,
}

/// Result of a successful nostrconnect:// connection.
class NostrConnectResult {
  const NostrConnectResult({
    required this.remoteSignerPubkey,
    required this.userPubkey,
    required this.info,
  });

  /// The bunker's pubkey (learned from response event).
  final String remoteSignerPubkey;

  /// The user's pubkey (if returned by bunker, may need get_public_key call).
  final String? userPubkey;

  /// The complete NostrRemoteSignerInfo for creating NostrRemoteSigner.
  final NostrRemoteSignerInfo info;
}

/// State machine for managing client-initiated NIP-46 nostrconnect:// connections.
///
/// Usage:
/// ```dart
/// final session = NostrConnectSession(
///   relays: ['wss://relay.divine.video', 'wss://relay.nsec.app'],
///   appName: 'OpenVine',
/// );
///
/// // Start the session - generates keypair and URL
/// await session.start();
///
/// // Display session.connectUrl as QR code
/// print(session.connectUrl);
///
/// // Wait for bunker to connect
/// final result = await session.waitForConnection(timeout: Duration(minutes: 2));
/// if (result != null) {
///   // Success! Create NostrRemoteSigner with result.info
/// }
/// ```
class NostrConnectSession {
  NostrConnectSession({
    required this.relays,
    this.appName,
    this.appUrl,
    this.appIcon,
    this.permissions,
    this.callback,
    this.relayMode = RelayMode.baseMode,
  });

  /// Relays to use for the connection.
  final List<String> relays;

  /// App name for bunker's approval dialog.
  final String? appName;

  /// App URL for bunker's approval dialog.
  final String? appUrl;

  /// App icon URL for bunker's approval dialog.
  final String? appIcon;

  /// Requested permissions (defaults to standard video app permissions).
  final String? permissions;

  /// Callback URL scheme for signer app to redirect back after approval.
  final String? callback;

  /// Relay mode to use (base or isolate).
  final int relayMode;

  /// Current session state.
  NostrConnectState _state = NostrConnectState.idle;
  NostrConnectState get state => _state;

  /// Stream of state changes.
  Stream<NostrConnectState> get stateStream => _stateController.stream;
  final _stateController = StreamController<NostrConnectState>.broadcast();

  /// The generated nostrconnect:// URL. Available after start().
  String? get connectUrl => _connectUrl;
  String? _connectUrl;

  /// The generated info. Available after start().
  NostrRemoteSignerInfo? get info => _info;
  NostrRemoteSignerInfo? _info;

  /// Error message if state is error.
  String? get errorMessage => _errorMessage;
  String? _errorMessage;

  // Internal state
  LocalNostrSigner? _localSigner;
  final List<Relay> _relays = [];
  Completer<NostrConnectResult?>? _connectionCompleter;
  Timer? _timeoutTimer;
  bool _isClosed = false;

  /// The since timestamp used for subscriptions, captured once at session start
  /// so reconnections use the same timestamp.
  int? _subscriptionSinceTimestamp;

  /// Start the session - generates keypair and begins listening on relays.
  Future<void> start() async {
    if (_state != NostrConnectState.idle) {
      throw StateError('Session already started. Create a new session.');
    }

    _setState(NostrConnectState.generating);

    try {
      // Generate the nostrconnect:// URL with ephemeral keypair
      _info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: relays,
        appName: appName,
        appUrl: appUrl,
        appIcon: appIcon,
        permissions: permissions,
      );

      // Generate the URL
      _connectUrl = _info!.toNostrConnectUrl(
        permissions: permissions,
        callback: callback,
      );

      // Create local signer from the ephemeral keypair
      _localSigner = LocalNostrSigner(Nip19.decode(_info!.nsec!));

      log('[NostrConnectSession] Generated URL: $_connectUrl');

      // Connect to relays and start listening
      await _connectToRelays();

      _setState(NostrConnectState.listening);
      log('[NostrConnectSession] Now listening for bunker response...');
    } catch (e) {
      _errorMessage = 'Failed to start session: $e';
      _setState(NostrConnectState.error);
      rethrow;
    }
  }

  /// Wait for the bunker to connect and respond.
  ///
  /// Returns [NostrConnectResult] on success, null on timeout/cancel.
  Future<NostrConnectResult?> waitForConnection({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (_state != NostrConnectState.listening) {
      throw StateError(
        'Session must be in listening state. Call start() first.',
      );
    }

    _connectionCompleter = Completer<NostrConnectResult?>();

    // Start timeout timer
    _timeoutTimer = Timer(timeout, () {
      if (!_connectionCompleter!.isCompleted) {
        log('[NostrConnectSession] Connection timed out');
        _setState(NostrConnectState.timeout);
        _connectionCompleter!.complete(null);
      }
    });

    return _connectionCompleter!.future;
  }

  /// Cancel the session.
  void cancel() {
    if (_isClosed) return;

    log('[NostrConnectSession] Session cancelled');
    _setState(NostrConnectState.cancelled);

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete(null);
    }

    _cleanup();
  }

  /// Ensure all relay connections are alive. Reconnects any that dropped.
  ///
  /// Call this when the app returns from background to recover connections
  /// that Android may have killed.
  Future<void> ensureConnected() async {
    if (_isClosed || _state != NostrConnectState.listening) return;

    log(
      '[NostrConnectSession] ensureConnected: checking ${_relays.length} '
      'relays + ${relays.length} configured',
    );

    // Reconnect any disconnected relays
    final disconnected = _relays
        .where((r) => r.relayStatus.connected != ClientConnected.connected)
        .toList();

    for (final relay in disconnected) {
      await _reconnectRelay(relay);
    }

    // If all relays were lost, try to reconnect from scratch
    if (_relays.isEmpty) {
      log('[NostrConnectSession] All relays lost, reconnecting from scratch');
      await _connectToRelays();
    }
  }

  /// Clean up resources.
  void dispose() {
    _cleanup();
    _stateController.close();
  }

  void _cleanup() {
    _isClosed = true;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    for (final relay in _relays) {
      try {
        relay.disconnect();
      } catch (_) {}
    }
    _relays.clear();
  }

  void _setState(NostrConnectState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  Future<void> _connectToRelays() async {
    // Connect to all relays in parallel for speed
    final futures = relays.map((url) async {
      try {
        return await _connectToRelay(url);
      } catch (e) {
        log('[NostrConnectSession] Failed to connect to $url: $e');
        return null;
      }
    });
    final results = await Future.wait(futures.toList());
    for (final relay in results) {
      if (relay != null) _relays.add(relay);
    }
    if (_relays.isEmpty) {
      throw StateError('Failed to connect to any relay');
    }
  }

  Future<Relay> _connectToRelay(String relayAddr) async {
    final relayStatus = RelayStatus(relayAddr);
    final relay = RelayBase(relayAddr, relayStatus);

    relay.onMessage = _onMessage;
    relay.relayStatusCallback = () {
      if (_isClosed) return;
      if (relayStatus.connected == ClientConnected.disconnect) {
        log('[NostrConnectSession] Relay $relayAddr disconnected');
      }
    };

    // Add subscription for listening to responses
    await _addSubscription(relay);

    await relay.connect();
    log('[NostrConnectSession] Connected to $relayAddr');

    return relay;
  }

  Future<void> _reconnectRelay(Relay relay) async {
    final addr = relay.relayStatus.addr;
    log('[NostrConnectSession] Reconnecting to $addr');

    try {
      // Re-add the subscription filter so it is sent on connect
      await _addSubscription(relay);
      final connected = await relay.connect();
      if (connected) {
        log('[NostrConnectSession] Reconnected to $addr');
      } else {
        log('[NostrConnectSession] Failed to reconnect to $addr');
      }
    } catch (e) {
      log('[NostrConnectSession] Reconnection error for $addr: $e');
    }
  }

  Future<void> _addSubscription(Relay relay) async {
    final pubkey = await _localSigner!.getPublicKey();
    if (pubkey == null) {
      throw StateError('Failed to get client pubkey');
    }

    // Capture the since timestamp once at session start so reconnections
    // use the same value and don't miss events sent while disconnected.
    _subscriptionSinceTimestamp ??=
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 30;

    final filter = Filter(
      since: _subscriptionSinceTimestamp!,
      p: [pubkey],
      kinds: [EventKind.nostrRemoteSigning],
    );

    final subscriptionId = StringUtil.rndNameStr(12);
    final queryMsg = ['REQ', subscriptionId, filter.toJson()];

    relay.pendingMessages.add(queryMsg);
    log(
      '[NostrConnectSession] Added subscription $subscriptionId for pubkey $pubkey',
    );
  }

  Future<void> _onMessage(Relay relay, List<dynamic> json) async {
    final messageType = json[0];

    if (messageType == 'EVENT') {
      try {
        relay.relayStatus.noteReceive();
        final event = Event.fromJson(json[2]);

        log(
          '[NostrConnectSession] Received event kind=${event.kind} '
          'from ${event.pubkey}',
        );

        if (event.kind == EventKind.nostrRemoteSigning) {
          await _handleResponse(event);
        }
      } catch (e, stack) {
        log('[NostrConnectSession] Error handling event: $e\n$stack');
      }
    } else if (messageType == 'EOSE') {
      log('[NostrConnectSession] EOSE from ${relay.relayStatus.addr}');
    } else if (messageType == 'NOTICE') {
      log('[NostrConnectSession] NOTICE: ${json.length > 1 ? json[1] : ""}');
    }
  }

  Future<void> _handleResponse(Event event) async {
    // Decrypt the response
    final response = await NostrRemoteResponse.decrypt(
      event.content,
      _localSigner!,
      event.pubkey,
    );

    if (response == null) {
      log('[NostrConnectSession] Failed to decrypt response');
      return;
    }

    log(
      '[NostrConnectSession] Decrypted response: id=${response.id}, '
      'hasResult=${response.result.isNotEmpty}, '
      'hasError=${(response.error ?? '').isNotEmpty}',
    );

    // Validate the secret per NIP-46. Accept ONLY an exact match;
    // "ack"/"connect" belong to the bunker:// flow's connect method
    // and are not valid for nostrconnect://. Non-matching, non-error
    // responses are dropped silently — treating them as terminal would
    // let any pubkey on the listening relays DoS pairing by racing
    // a junk response in front of the legitimate signer's reply.
    final validation = validateConnectResponse(
      response: response,
      expectedSecret: _info?.optionalSecret,
    );

    switch (validation) {
      case NostrConnectResponseValidation.invalidSession:
        log('[NostrConnectSession] No expected secret - cannot validate');
        _errorMessage = 'Invalid session state: no secret to validate';
        _setState(NostrConnectState.error);
        return;

      case NostrConnectResponseValidation.rejectedByBunker:
        log(
          '[NostrConnectSession] Bunker rejected connection from '
          '${event.pubkey}',
        );
        _errorMessage = 'Bunker rejected connection';
        _setState(NostrConnectState.error);
        if (_connectionCompleter != null &&
            !_connectionCompleter!.isCompleted) {
          _connectionCompleter!.complete(null);
        }
        return;

      case NostrConnectResponseValidation.ignore:
        // Drop silently and keep listening; the hard timeout in
        // waitForConnection terminates the wait if no valid response
        // ever arrives.
        log(
          '[NostrConnectSession] Ignoring response from ${event.pubkey}: '
          'result did not match the expected secret',
        );
        return;

      case NostrConnectResponseValidation.match:
        break; // fall through to the success path below
    }

    // Success! Extract remote signer pubkey from the event
    final remoteSignerPubkey = event.pubkey;
    log('[NostrConnectSession] Connected to bunker: $remoteSignerPubkey');

    // Update info with the remote signer pubkey
    _info = NostrRemoteSignerInfo(
      remoteSignerPubkey: remoteSignerPubkey,
      relays: _info!.relays,
      optionalSecret: _info!.optionalSecret,
      nsec: _info!.nsec,
      userPubkey: null, // Will be fetched via get_public_key
      isClientInitiated: true,
      clientPubkey: _info!.clientPubkey,
      appName: _info!.appName,
      appUrl: _info!.appUrl,
      appIcon: _info!.appIcon,
    );

    _timeoutTimer?.cancel();
    _setState(NostrConnectState.connected);

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete(
        NostrConnectResult(
          remoteSignerPubkey: remoteSignerPubkey,
          userPubkey: null,
          info: _info!,
        ),
      );
    }

    // Clean up relays - NostrRemoteSigner will create its own connections
    _cleanup();
  }
}

/// Outcome of validating a `nostrconnect://` connect response per NIP-46.
@visibleForTesting
enum NostrConnectResponseValidation {
  /// `response.result` exactly matches the expected secret. Proceed to
  /// bind the session.
  match,

  /// `response.error` is set; the signer explicitly rejected the
  /// connection. Surface a terminal error to the user.
  rejectedByBunker,

  /// Programmer error: the session is missing an expected secret.
  /// Surface a terminal error.
  invalidSession,

  /// `response.result` did not match and `response.error` is empty.
  /// Drop silently per the policy decision in #3355 — treating this
  /// as terminal would let any pubkey on the listening relays DoS
  /// pairing by racing junk responses in front of the legitimate
  /// signer's reply.
  ignore,
}

/// Pure validation of a NIP-46 nostrconnect:// connect response against
/// the expected secret. Public-by-test so the security-critical decision
/// is exhaustively unit-testable.
@visibleForTesting
NostrConnectResponseValidation validateConnectResponse({
  required NostrRemoteResponse response,
  required String? expectedSecret,
}) {
  if (expectedSecret == null || expectedSecret.isEmpty) {
    return NostrConnectResponseValidation.invalidSession;
  }
  final error = response.error;
  if (error != null && error.isNotEmpty) {
    return NostrConnectResponseValidation.rejectedByBunker;
  }
  if (_constantTimeEqual(response.result, expectedSecret)) {
    return NostrConnectResponseValidation.match;
  }
  return NostrConnectResponseValidation.ignore;
}

bool _constantTimeEqual(String a, String b) {
  // This still leaks length, which is acceptable here because the
  // compared value is an ephemeral per-session secret. We only need
  // to avoid content-dependent early exit for equal-length strings.
  if (a.length != b.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
