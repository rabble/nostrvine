// ABOUTME: Keycast RPC client implementing NostrSigner interface
// ABOUTME: Provides remote signing via Keycast server for Nostr events

import 'dart:async';
import 'dart:collection';
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
    http.Client Function()? httpClientFactory,
    TokenRefreshCallback? onTokenRefresh,
    this.requestTimeout = defaultRequestTimeout,
    this.batchRequestTimeout = defaultBatchRequestTimeout,
  }) : _accessToken = accessToken,
       _clientFactory = httpClientFactory ?? http.Client.new,
       _client = httpClient ?? (httpClientFactory ?? http.Client.new)(),
       _ownsClient = httpClient == null,
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
  /// ## What this bound is for
  ///
  /// It is a **dead-socket backstop**, not a latency budget. Android Doze
  /// killing a connection while backgrounded leaves a request that never
  /// completes and never errors; without a bound it wedges every caller
  /// awaiting it forever. So the number is sized from what a *live* request
  /// can cost on a bad mobile link — DNS, TCP, TLS, a retransmit or two, and
  /// the small JSON round trip — not from how slow the server might be. 20s
  /// is far above that and still recovers a wedged caller in a third less
  /// time than the previous 30s.
  ///
  /// It applies to *every* single-op RPC caller — video publish signing,
  /// likes, reposts, follows — not just the DM path.
  ///
  /// ## Why it is no longer sized against server latency (#7092)
  ///
  /// The old derivation held this at 30s to cover "production Keycast
  /// single-op latency of ~20-30s under DB-pool contention" (keycast#291).
  /// That is no longer reachable: keycast#351 bounds the `/api/nostr` handler
  /// at 8s and the tower layer behind it at 10s, both answering 504, so a
  /// request that is still alive cannot spend more than ~10s server-side.
  /// Verified live on production 2026-08-13 via the public `/api/metrics`
  /// histogram that keycast#351 itself added: across two instances and ~10k
  /// `sign_event` samples every success landed in the `le="1"` bucket, and
  /// `outcome="timeout"` had not been recorded once.
  ///
  /// That evidence is **corroboration, not the guarantee**. This bound does
  /// not assume the server keeps its ceiling, because it no longer has to:
  /// [RpcTimeoutException] makes a server 504 and a local request timeout
  /// classify identically downstream, so which side gives up first stopped
  /// being load-bearing. Sizing a client cap on an unverified server bound is
  /// what produced #6586; sizing it on the client's own transport costs, and
  /// making both give-up paths mean the same thing, is what retires that
  /// coupling.
  ///
  /// Callers that need to outlive a slow signer do not lean on this bound
  /// either: the durable outgoing queue re-drives stalled sends and
  /// `DmSendBudget.messagePublishTimeout` is the send-level backstop (#6046).
  static const Duration defaultRequestTimeout = Duration(seconds: 20);

  /// Default timeout for the multi-wrap `nip17_unwrap_batch` verb, which does
  /// materially more server-side work than a single op and legitimately runs
  /// longer. Held at the historical single-op bound so batch decrypt is not
  /// regressed by the tighter [defaultRequestTimeout] above.
  ///
  /// Left wider deliberately rather than re-derived alongside it: keycast's
  /// 8s handler bound covers this verb too, so the extra 10s can only buy
  /// transport slack, never mask a slow server.
  static const Duration defaultBatchRequestTimeout = Duration(seconds: 30);

  final String nostrApi;
  String _accessToken;
  final http.Client Function() _clientFactory;
  http.Client _client;
  bool _ownsClient;
  final Map<http.Client, int> _inFlightByClient = HashMap.identity();
  final Set<http.Client> _clientsPendingClose = HashSet.identity();
  final TokenRefreshCallback? _onTokenRefresh;
  bool _signCanonicalUnsupported = false;
  bool _isClosed = false;

  /// Maximum time to wait for a single-op RPC request before failing with a
  /// [RpcTimeoutException].
  final Duration requestTimeout;

  /// Maximum time to wait for the heavier `nip17_unwrap_batch` RPC.
  final Duration batchRequestTimeout;

  Future<T> _call<T>(
    String method,
    List<dynamic> params,
    T Function(dynamic) fromResult, {
    bool logHttpErrors = true,
    Duration? timeout,
    bool classifyLocalTimeout = true,
  }) async {
    final effectiveTimeout = timeout ?? requestTimeout;
    final stopwatch = Stopwatch()..start();

    Never throwTimeout() {
      if (!classifyLocalTimeout) {
        throw TimeoutException('$method request timed out', effectiveTimeout);
      }
      throw RpcTimeoutException(
        'Local $method request timed out after ${effectiveTimeout.inSeconds}s',
        method: method,
      );
    }

    Duration remaining() {
      final value = effectiveTimeout - stopwatch.elapsed;
      if (value <= Duration.zero) throwTimeout();
      return value;
    }

    var response = await _sendRequestWithRetry(
      method,
      params,
      timeout: remaining,
      classifyLocalTimeout: classifyLocalTimeout,
    );

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
        newToken = await _onTokenRefresh().timeout(remaining());
      } on TimeoutException {
        newToken = null;
      }
      if (newToken != null) {
        _accessToken = newToken;
        response = await _sendRequestWithRetry(
          method,
          params,
          timeout: remaining,
          classifyLocalTimeout: classifyLocalTimeout,
        );
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

  /// Sends one RPC request and, for transport-level [http.ClientException],
  /// resets the HTTP transport before retrying once.
  ///
  /// The retry is deliberately below RPC parsing and token-refresh handling:
  /// a call that also gets one 401 refresh can issue up to four POSTs in the
  /// worst case. `nip17_wrap_batch` also records a server-side audit row per
  /// call, so callers must treat the retry as transport recovery rather than
  /// proof that the first POST had no server-side effect.
  Future<http.Response> _sendRequestWithRetry(
    String method,
    List<dynamic> params, {
    Duration? Function()? timeout,
    bool classifyLocalTimeout = true,
  }) async {
    _ensureOpen();
    final attemptClient = _client;
    try {
      return await _sendRequest(
        method,
        params,
        client: attemptClient,
        timeout: timeout?.call(),
        classifyLocalTimeout: classifyLocalTimeout,
      );
    } on http.ClientException catch (error) {
      Log.warning(
        '[Keycast RPC] Socket error during $method: $error; '
        'resetting HTTP transport and retrying once',
        name: 'KeycastRpc',
        category: LogCategory.auth,
      );
      if (_isClosed) rethrow;
      _resetHttpClientAfterFailure(attemptClient);
      try {
        return await _sendRequest(
          method,
          params,
          timeout: timeout?.call(),
          classifyLocalTimeout: classifyLocalTimeout,
        );
      } on http.ClientException catch (retryError) {
        Log.warning(
          '[Keycast RPC] Socket retry failed during $method: $retryError',
          name: 'KeycastRpc',
          category: LogCategory.auth,
        );
        rethrow;
      }
    }
  }

  void _resetHttpClientAfterFailure(http.Client failedClient) {
    if (!identical(_client, failedClient)) return;
    final shouldCloseFailedClient = _ownsClient;
    _client = _clientFactory();
    _ownsClient = true;
    _retireHttpClient(failedClient, shouldClose: shouldCloseFailedClient);
  }

  void _retireHttpClient(http.Client client, {required bool shouldClose}) {
    if (!shouldClose) return;
    if ((_inFlightByClient[client] ?? 0) > 0) {
      _clientsPendingClose.add(client);
      return;
    }
    client.close();
  }

  http.Client _acquireHttpClient([http.Client? preferredClient]) {
    final client = preferredClient ?? _client;
    _inFlightByClient[client] = (_inFlightByClient[client] ?? 0) + 1;
    return client;
  }

  void _releaseHttpClient(http.Client client) {
    final inFlight = _inFlightByClient[client];
    if (inFlight == null) return;
    if (inFlight > 1) {
      _inFlightByClient[client] = inFlight - 1;
      return;
    }
    _inFlightByClient.remove(client);
    if (_clientsPendingClose.remove(client)) {
      client.close();
    }
  }

  Future<http.Response> _sendRequest(
    String method,
    List<dynamic> params, {
    http.Client? client,
    Duration? timeout,
    bool classifyLocalTimeout = true,
  }) async {
    _ensureOpen();
    Log.debug(
      '[Keycast RPC] Calling $method...',
      name: 'KeycastRpc',
      category: LogCategory.auth,
    );
    final stopwatch = Stopwatch()..start();
    final effectiveTimeout = timeout ?? requestTimeout;
    final requestClient = _acquireHttpClient(client);
    http.Response response;
    try {
      response = await requestClient
          .post(
            Uri.parse(nostrApi),
            headers: {
              'Authorization': 'Bearer $_accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'method': method, 'params': params}),
          )
          .timeout(effectiveTimeout);
    } on TimeoutException {
      if (!classifyLocalTimeout) rethrow;
      throw RpcTimeoutException(
        'Local $method request timed out after ${effectiveTimeout.inSeconds}s',
        method: method,
      );
    } finally {
      _releaseHttpClient(requestClient);
    }
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
  /// back to the per-wrap decrypt path. A local [TimeoutException] is
  /// deliberately allowed to propagate so a slow page is retried by the caller
  /// rather than being mistaken for an empty result.
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
        classifyLocalTimeout: false,
      );
    } on RpcException {
      // Older keycast without the verb, or a server-level error: degrade so the
      // caller uses the per-wrap fallback. Note: no `catch (_)` here — a
      // TimeoutException must propagate, not be swallowed into a null result.
      return null;
    }
  }

  /// Runs a batch verb under one deadline, including token refresh and retry.
  Future<T> _callBatch<T>(
    String method,
    List<dynamic> params,
    T Function(dynamic) fromResult, {
    bool logHttpErrors = true,
    bool classifyLocalTimeout = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    Never throwTimeout() {
      if (!classifyLocalTimeout) {
        throw TimeoutException(
          '$method request timed out',
          batchRequestTimeout,
        );
      }
      throw RpcTimeoutException(
        'Local $method request timed out after '
        '${batchRequestTimeout.inSeconds}s',
        method: method,
      );
    }

    Duration remaining() {
      final value = batchRequestTimeout - stopwatch.elapsed;
      if (value <= Duration.zero) throwTimeout();
      return value;
    }

    var response = await _sendRequestWithRetry(
      method,
      params,
      timeout: remaining,
      classifyLocalTimeout: classifyLocalTimeout,
    );

    if (response.statusCode == 401 && _onTokenRefresh != null) {
      Log.info(
        '[Keycast RPC] $method returned 401, attempting token refresh',
        name: 'KeycastRpc',
        category: LogCategory.auth,
      );
      String? newToken;
      try {
        newToken = await _onTokenRefresh().timeout(remaining());
      } on TimeoutException {
        throwTimeout();
      }
      if (newToken != null) {
        _accessToken = newToken;
        response = await _sendRequestWithRetry(
          method,
          params,
          timeout: remaining,
          classifyLocalTimeout: classifyLocalTimeout,
        );
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

  /// Server-side NIP-59 gift-wrap construction for the remote-signer DM send
  /// path (`nip17_wrap_batch`).
  ///
  /// Sends one shared [rumor] plus an ordered [recipientPubkeys] list and gets
  /// back index-aligned slots — each a signed kind:1059 gift wrap, or a
  /// per-recipient error code. The server NIP-44-encrypts the rumor and signs
  /// the kind:13 seal itself, so a 1:1 send (peer + the NIP-17 self copy)
  /// collapses from four round trips — `nip44Encrypt` + `signEvent` per wrap —
  /// to one. It also collapses this send's four per-request account-status DB
  /// queries and four activity-log writes into one of each, which is the part
  /// that matters under the signer's DB-pool contention.
  ///
  /// The server accepts rumor kinds 14 and 15 only; callers must not send
  /// other kinds (NIP-17 also blesses kind 7 reactions and wrapped kind 5
  /// deletes, which this verb rejects at request level).
  ///
  /// Returns `null` ONLY when the backend does not expose the verb yet, so the
  /// caller can stop asking for the rest of the session.
  ///
  /// Everything else throws — a transient 5xx, an expired token, a rejected
  /// request, or a transient [RpcTimeoutException]. This is a deliberate
  /// divergence from
  /// [nip17UnwrapBatch], which collapses every [RpcException] into `null`:
  /// there, a caller that latches off pays two decrypt RPCs per wrap; here it
  /// would pay four signing round trips per DM for the rest of the session, and
  /// a single blip is not evidence the verb is gone.
  Future<List<GiftWrapSlot>?> nip17WrapBatch(
    Map<String, dynamic> rumor,
    List<String> recipientPubkeys,
  ) async {
    try {
      return await _callBatch(
        'nip17_wrap_batch',
        [rumor, recipientPubkeys],
        (result) => [
          for (final slot in result as List)
            _parseWrapSlot(slot as Map<String, dynamic>),
        ],
        // Builds a seal + wrap per recipient server-side, so it legitimately
        // runs longer than a single op — keep it on the batch bound rather
        // than the tighter single-op [requestTimeout].
        // The unsupported-method probe is an expected outcome on an older
        // backend, not an incident; the branch below logs it at info instead.
        logHttpErrors: false,
      );
    } on RpcException catch (error) {
      if (!_isUnsupportedWrapBatch(error)) rethrow;
      Log.info(
        '[Keycast RPC] nip17_wrap_batch unsupported by backend; '
        'DM sends will use the per-wrap signing path for this session',
        name: 'KeycastRpc',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Distinguishes an absent batch verb from ordinary HTTP 400 rejections.
  bool _isUnsupportedWrapBatch(RpcException error) {
    final lower = error.message.toLowerCase();
    return lower.contains('unsupported method') ||
        lower.contains('method_not_found') ||
        lower.contains('method not found');
  }

  static GiftWrapSlot _parseWrapSlot(Map<String, dynamic> slot) {
    final error = slot['error'];
    if (error != null) return GiftWrapSlot.failure(error.toString());
    final giftWrap = slot['gift_wrap'];
    if (giftWrap is Map<String, dynamic>) {
      return GiftWrapSlot.success(giftWrap);
    }
    return const GiftWrapSlot.failure('invalid_slot');
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
  void close() {
    if (_isClosed) return;
    _isClosed = true;
    if (_ownsClient) {
      _client.close();
    }
    for (final client in _clientsPendingClose) {
      client.close();
    }
    _clientsPendingClose.clear();
    _inFlightByClient.clear();
  }

  void _ensureOpen() {
    if (_isClosed) {
      throw StateError('KeycastRpc is closed');
    }
  }
}
