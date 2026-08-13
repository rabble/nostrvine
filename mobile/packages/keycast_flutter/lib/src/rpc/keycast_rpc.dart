// ABOUTME: Keycast RPC client implementing NostrSigner interface
// ABOUTME: Provides remote signing via Keycast server for Nostr events

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:keycast_flutter/src/models/exceptions.dart';
import 'package:keycast_flutter/src/models/keycast_session.dart';
import 'package:keycast_flutter/src/oauth/oauth_config.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:unified_logger/unified_logger.dart';

/// Callback invoked when a 401 response indicates the access token has
/// expired. Returns a fresh access token on success, or `null` if refresh
/// is not possible.
typedef TokenRefreshCallback = Future<String?> Function();

class KeycastRpc implements NostrSigner, GiftWrapBatchUnwrapper {
  KeycastRpc({
    required this.nostrApi,
    required String accessToken,
    http.Client? httpClient,
    TokenRefreshCallback? onTokenRefresh,
    this.requestTimeout = defaultRequestTimeout,
    this.batchRequestTimeout = defaultBatchRequestTimeout,
  }) : _accessToken = accessToken,
       _client = httpClient ?? http.Client(),
       _onTokenRefresh = onTokenRefresh;

  factory KeycastRpc.fromSession(
    OAuthConfig config,
    KeycastSession session, {
    TokenRefreshCallback? onTokenRefresh,
    Duration requestTimeout = defaultRequestTimeout,
    Duration batchRequestTimeout = defaultBatchRequestTimeout,
  }) {
    if (!session.hasRpcAccess) {
      throw SessionExpiredException();
    }
    return KeycastRpc(
      nostrApi: config.nostrApiUrl,
      accessToken: session.accessToken!,
      onTokenRefresh: onTokenRefresh,
      requestTimeout: requestTimeout,
      batchRequestTimeout: batchRequestTimeout,
    );
  }

  /// HTTP 504. Keycast's answer when it ran out of time on `/api/nostr`.
  static const int _gatewayTimeoutStatus = 504;

  /// Default timeout applied to a single signing/encryption RPC
  /// (`sign_event`, `nip44_encrypt`, `nip44_decrypt`, `nip04_*`,
  /// `get_public_key`, `sign_canonical`).
  ///
  /// Without a bound, a dead socket (e.g. Android Doze killing the
  /// connection while backgrounded) hangs the request forever and wedges
  /// every caller awaiting it.
  ///
  /// This default applies to *every* single-op RPC caller — video publish
  /// signing, likes, reposts, follows — not just the DM path, so the bound
  /// must cover production Keycast single-op latency under load. Keycast
  /// DB-pool contention has been observed to push a single op to ~20-30s;
  /// a tighter bound would turn slow-but-succeeding social actions and
  /// video publishes into hard failures. The DM send path does not depend
  /// on a shorter bound for fail-fast or durability: the durable outgoing
  /// queue re-drives stalled sends and `dm_repository`'s 90s
  /// `_messagePublishTimeout` is the send-level backstop (#6046).
  static const Duration defaultRequestTimeout = Duration(seconds: 30);

  /// Default timeout for the multi-wrap `nip17_unwrap_batch` verb, which does
  /// materially more server-side work than a single op and legitimately runs
  /// longer. Held at the historical single-op bound so batch decrypt is not
  /// regressed by the tighter [defaultRequestTimeout] above.
  static const Duration defaultBatchRequestTimeout = Duration(seconds: 30);

  final String nostrApi;
  String _accessToken;
  final http.Client _client;
  final TokenRefreshCallback? _onTokenRefresh;
  bool _signCanonicalUnsupported = false;

  /// Maximum time to wait for a single-op RPC request before failing with a
  /// [TimeoutException].
  final Duration requestTimeout;

  /// Maximum time to wait for the heavier `nip17_unwrap_batch` RPC.
  final Duration batchRequestTimeout;

  Future<T> _call<T>(
    String method,
    List<dynamic> params,
    T Function(dynamic) fromResult, {
    bool logHttpErrors = true,
    Duration? timeout,
  }) async {
    var response = await _sendRequest(method, params, timeout: timeout);

    if (response.statusCode == 401 && _onTokenRefresh != null) {
      Log.info(
        '[Keycast RPC] $method returned 401, attempting token refresh',
        name: 'KeycastRpc',
        category: LogCategory.auth,
      );
      // Bounded like the RPC itself: the refresh callback does its own HTTP
      // round-trip, and an unbounded await here would make one logical
      // signer op hang past every caller's budget despite [requestTimeout].
      // A timed-out refresh counts as a failed refresh (null), so the
      // original 401 response flows to the error handling below.
      String? newToken;
      try {
        newToken = await _onTokenRefresh().timeout(timeout ?? requestTimeout);
      } on TimeoutException {
        newToken = null;
      }
      if (newToken != null) {
        _accessToken = newToken;
        response = await _sendRequest(method, params, timeout: timeout);
      }
    }

    if (response.statusCode != 200) {
      if (logHttpErrors) {
        Log.error(
          '[Keycast RPC] Error response: ${response.body}',
          name: 'KeycastRpc',
          category: LogCategory.auth,
        );
      }
      final message = 'HTTP ${response.statusCode}: ${response.body}';
      // 504 is Keycast reporting *its own* timeout, so it classifies like one
      // rather than like a refusal. See [RpcTimeoutException].
      throw response.statusCode == _gatewayTimeoutStatus
          ? RpcTimeoutException(message, method: method)
          : RpcException(message, method: method);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json.containsKey('error') && json['error'] != null) {
      throw RpcException(json['error'].toString(), method: method);
    }

    if (!json.containsKey('result')) {
      throw RpcException('Missing result in response', method: method);
    }

    return fromResult(json['result']);
  }

  Future<http.Response> _sendRequest(
    String method,
    List<dynamic> params, {
    Duration? timeout,
  }) async {
    Log.debug(
      '[Keycast RPC] Calling $method...',
      name: 'KeycastRpc',
      category: LogCategory.auth,
    );
    final stopwatch = Stopwatch()..start();
    final response = await _client
        .post(
          Uri.parse(nostrApi),
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'method': method, 'params': params}),
        )
        .timeout(timeout ?? requestTimeout);
    stopwatch.stop();
    Log.debug(
      '[Keycast RPC] $method completed in '
      '${stopwatch.elapsedMilliseconds}ms '
      '(HTTP ${response.statusCode})',
      name: 'KeycastRpc',
      category: LogCategory.auth,
    );
    return response;
  }

  @override
  Future<String?> getPublicKey() async {
    return _call('get_public_key', [], (result) => result as String);
  }

  @override
  Future<Event?> signEvent(Event event) async {
    return _call('sign_event', [
      event.toJson(),
    ], (result) => Event.fromJson(result as Map<String, dynamic>));
  }

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async {
    return _call('nip44_encrypt', [
      pubkey,
      plaintext,
    ], (result) => result as String);
  }

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    return _call('nip44_decrypt', [
      pubkey,
      ciphertext,
    ], (result) => result as String);
  }

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async {
    return _call('nip04_encrypt', [
      pubkey,
      plaintext,
    ], (result) => result as String);
  }

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async {
    return _call('nip04_decrypt', [
      pubkey,
      ciphertext,
    ], (result) => result as String);
  }

  @override
  Future<Map<dynamic, dynamic>?> getRelays() async {
    return null;
  }

  /// Remote canonical-payload signing for C2PA creator-binding flows.
  ///
  /// Performs SHA-256 of [payload] and schnorr-signs the digest with the
  /// account's private key, returning a hex-encoded signature. Server-side
  /// MUST use deterministic auxiliary data (32 zero bytes) so repeated
  /// signing of the same payload produces the same signature, matching the
  /// local signer at `LocalKeySigner.signCanonicalPayload`.
  ///
  /// Returns `null` (rather than throwing) when:
  ///   * the backend does not yet expose `sign_canonical` (method-not-found
  ///     surfaces as [RpcException]),
  ///   * the request errors at the HTTP level,
  ///   * the response is malformed.
  ///
  /// Callers (e.g. `KeycastNostrIdentity`) treat null as "canonical signing
  /// unsupported by this identity" and skip the assertion gracefully.
  Future<String?> signCanonicalPayload(Uint8List payload) async {
    if (_signCanonicalUnsupported) {
      return null;
    }

    try {
      return await _call(
        'sign_canonical',
        [base64Encode(payload)],
        (result) => result as String,
        logHttpErrors: false,
      );
    } on RpcException catch (error) {
      if (_isUnsupportedSignCanonical(error)) {
        _signCanonicalUnsupported = true;
        Log.info(
          '[Keycast RPC] sign_canonical unsupported by backend; '
          'canonical creator-binding will be skipped for this session',
          name: 'KeycastRpc',
          category: LogCategory.auth,
        );
      } else {
        Log.warning(
          '[Keycast RPC] sign_canonical failed; '
          'canonical creator-binding will be skipped: ${error.message}',
          name: 'KeycastRpc',
          category: LogCategory.auth,
        );
      }
      return null;
    } catch (error) {
      // Network/parse error: degrade gracefully.
      Log.warning(
        '[Keycast RPC] sign_canonical request failed; '
        'canonical creator-binding will be skipped: $error',
        name: 'KeycastRpc',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Whether [error] is the backend signalling that `sign_canonical` is not
  /// implemented, as opposed to a transient or auth failure that must stay
  /// retryable.
  ///
  /// Matched against the exact wordings the login backend returns today: the
  /// HTTP `Unsupported method: sign_canonical` body and the JSON-RPC
  /// `method_not_found` error field. The match is deliberately narrow — a
  /// broader signal (e.g. caching on any 4xx) would risk permanently disabling
  /// a supported capability after a transient blip. If the backend ever rewords
  /// this, update the substrings here, otherwise canonical binding silently
  /// re-requests on every publish.
  bool _isUnsupportedSignCanonical(RpcException error) {
    final lower = error.message.toLowerCase();
    return lower.contains('unsupported method') ||
        lower.contains('method_not_found') ||
        lower.contains('method not found');
  }

  /// Server-side NIP-59 gift-wrap unwrap for the remote-signer DM history
  /// drain (`nip17_unwrap_batch`).
  ///
  /// Sends a chunk of kind:1059 gift wraps and gets back ordered, index-aligned
  /// slots — each the decrypted kind:14 rumor plus the authenticated sender, or
  /// a per-item error code. This replaces two `nip44Decrypt` round trips per
  /// wrap (gift wrap → seal, seal → rumor) with a single round trip per chunk;
  /// the server verifies both signatures and decrypts both layers.
  ///
  /// Returns `null` (rather than throwing) when the backend does not expose the
  /// verb yet — method-not-found surfaces as an [RpcException] — so callers fall
  /// back to the per-wrap decrypt path. A [TimeoutException] is deliberately
  /// allowed to propagate so a slow page is retried by the caller rather than
  /// being mistaken for an empty result.
  @override
  Future<List<GiftWrapUnwrapSlot>?> nip17UnwrapBatch(
    List<Map<String, dynamic>> giftWraps,
  ) async {
    try {
      return await _call(
        'nip17_unwrap_batch',
        giftWraps,
        (result) => [
          for (final slot in result as List)
            _parseUnwrapSlot(slot as Map<String, dynamic>),
        ],
        // The batch verb decrypts many wraps server-side and legitimately runs
        // longer than a single op, so keep it on the longer bound rather than
        // the tighter single-op [requestTimeout].
        timeout: batchRequestTimeout,
      );
    } on RpcException {
      // Older keycast without the verb, or a server-level error: degrade so the
      // caller uses the per-wrap fallback. Note: no `catch (_)` here — a
      // TimeoutException must propagate, not be swallowed into a null result.
      return null;
    }
  }

  static GiftWrapUnwrapSlot _parseUnwrapSlot(Map<String, dynamic> slot) {
    final error = slot['error'];
    if (error != null) return GiftWrapUnwrapSlot.failure(error.toString());
    final rumor = slot['rumor'];
    final sender = slot['sender'];
    if (rumor is Map<String, dynamic> && sender is String) {
      return GiftWrapUnwrapSlot.success(rumor: rumor, sender: sender);
    }
    return const GiftWrapUnwrapSlot.failure('invalid_slot');
  }

  @override
  void close() {}
}
