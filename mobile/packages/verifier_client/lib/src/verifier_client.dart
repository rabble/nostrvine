// ABOUTME: VerifierClient — HTTP client over verifier.divine.video.
// ABOUTME: Stateless: every call hits the network; caching lives above.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:verifier_client/src/exceptions.dart';
import 'package:verifier_client/src/models/identity_claim.dart';
import 'package:verifier_client/src/models/verification_result.dart';
import 'package:verifier_client/src/models/verifier_platform.dart';

/// HTTP client for `https://verifier.divine.video`.
///
/// Stateless: every call hits the network — intentionally no cache, retry,
/// or rechecking at this layer. The verifier owns server-side freshness via
/// Cloudflare KV; the client-side verdict cache lives one layer up, in
/// `IdentityClaimsRepository` (#3936).
class VerifierClient {
  /// Creates a [VerifierClient] pointed at [baseUrl].
  ///
  /// Pass an [httpClient] to inject a [http.Client] for testing. Pass
  /// [timeout] to override the per-request timeout (default 10 seconds).
  VerifierClient({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  /// Server-side cap from
  /// `divine-identify-verification-service/src/routes/verify.ts:12`.
  /// Keep this in sync if the service raises it.
  static const int maxBatchSize = 10;

  final String _baseUrl;
  final http.Client _httpClient;
  final Duration _timeout;

  /// Re-verifies a batch of claims. Returns one result per input claim in the
  /// order the verifier responds (typically input order).
  ///
  /// Returns an empty list when [claims] is empty without hitting the network.
  ///
  /// Throws:
  /// * [ArgumentError] if [claims] has more than [maxBatchSize] items.
  /// * [VerifierApiException] for any non-2xx response.
  /// * [VerifierTimeoutException] if the request does not complete within the
  ///   configured timeout.
  /// * [VerifierNetworkException] for transport-level failures.
  Future<List<VerificationResult>> verifyBatch(
    List<IdentityClaim> claims,
  ) async {
    if (claims.isEmpty) return const [];
    if (claims.length > maxBatchSize) {
      throw ArgumentError.value(
        claims.length,
        'claims',
        'must contain at most $maxBatchSize items',
      );
    }
    final body = jsonEncode(<String, dynamic>{
      'claims': claims.map((c) => c.toJson()).toList(),
    });
    final json = await _post('/verify', body);
    final results = (json['results'] as List).cast<Map<String, dynamic>>();
    return results.map(VerificationResult.fromJson).toList();
  }

  /// Re-verifies a single claim via `/verify/single`.
  ///
  /// Throws the same exceptions as [verifyBatch].
  Future<VerificationResult> verifySingle(IdentityClaim claim) async {
    final body = jsonEncode(claim.toJson());
    final json = await _post('/verify/single', body);
    return VerificationResult.fromJson(json);
  }

  /// Lists the platforms the verifier currently accepts claims for.
  ///
  /// Entries the service reports as unsupported are returned as-is; callers
  /// decide whether to hide or disable them.
  ///
  /// Throws the same exceptions as [verifyBatch].
  Future<List<VerifierPlatform>> fetchPlatforms() async {
    final json = await _get('/platforms');
    final platforms = json['platforms'] as Map<String, dynamic>? ?? const {};
    return [
      for (final entry in platforms.entries)
        VerifierPlatform.fromJson(
          entry.key,
          entry.value as Map<String, dynamic>,
        ),
    ];
  }

  /// Builds the verifier URL that starts the OAuth flow for [platform].
  ///
  /// Purely local; fetching it is what actually starts the flow, which
  /// [resolveOAuthLaunchUri] does exactly once. The verifier then redirects to
  /// [returnUrl] with `oauth_verified`, `platform` and `identity` query
  /// parameters on success, or `oauth_error` on failure.
  ///
  /// [returnUrl] must be an origin the verifier allowlists
  /// (`divine-identify-verification-service/src/routes/auth.ts`), otherwise
  /// the start endpoint rejects the request with HTTP 400.
  ///
  /// [handle] is required for `bluesky`, which resolves the user's PDS before
  /// it can start the flow, and ignored for every other platform.
  ///
  /// Throws [ArgumentError] if [platform] has no OAuth flow.
  Uri oauthStartUri({
    required String platform,
    required String pubkey,
    required String returnUrl,
    String? handle,
  }) {
    if (!VerifierPlatform.oauthPlatforms.contains(platform)) {
      throw ArgumentError.value(
        platform,
        'platform',
        'has no OAuth flow; supported: '
            '${VerifierPlatform.oauthPlatforms.join(', ')}',
      );
    }
    if (platform == 'bluesky' && (handle == null || handle.trim().isEmpty)) {
      throw ArgumentError.value(
        handle,
        'handle',
        'is required to start the bluesky OAuth flow',
      );
    }
    return Uri.parse('$_baseUrl/auth/$platform/start').replace(
      queryParameters: <String, String>{
        'pubkey': pubkey,
        'return_url': returnUrl,
        if (handle != null && handle.trim().isNotEmpty) 'handle': handle.trim(),
      },
    );
  }

  /// Starts [platform]'s OAuth flow and returns the URL to open in a browser.
  ///
  /// [oauthStartUri] answers with a 302 to the provider's authorization
  /// endpoint. Resolving that redirect here and launching the session on its
  /// target — rather than on the start URL again — keeps one tap to one start
  /// request. A start request is not free: it mints server-side OAuth state,
  /// spends the deployment's per-IP budget and, for Bluesky, resolves the PDS
  /// and pushes a PAR to it.
  ///
  /// Returns null when this deployment cannot start the flow. A platform
  /// having an OAuth route in the code does not mean the credentials are
  /// configured: without them the endpoint answers 503
  /// `{"error":"… OAuth not configured"}` instead of redirecting, and a
  /// browser session opened on that page strands the user on a JSON error
  /// with no way back.
  ///
  /// Falls back to the start URL when the verifier could not be reached at
  /// all — a request that never landed is not evidence the flow is
  /// unavailable, and the browser session reports the problem better than
  /// refusing here would.
  ///
  /// Throws the same [ArgumentError]s as [oauthStartUri].
  Future<Uri?> resolveOAuthLaunchUri({
    required String platform,
    required String pubkey,
    required String returnUrl,
    String? handle,
  }) async {
    final startUri = oauthStartUri(
      platform: platform,
      pubkey: pubkey,
      returnUrl: returnUrl,
      handle: handle,
    );
    final request = http.Request('GET', startUri)..followRedirects = false;
    final http.StreamedResponse response;
    try {
      response = await _httpClient.send(request).timeout(_timeout);
    } on Object {
      return startUri;
    }
    try {
      await response.stream.drain<void>();
    } on Object {
      // Only the status line and Location matter; a body that fails to drain
      // does not change what the redirect said.
    }
    if (response.statusCode < 300 || response.statusCode >= 400) return null;
    final location = response.headers['location'];
    if (location == null || location.isEmpty) return null;
    final Uri target;
    try {
      target = startUri.resolveUri(Uri.parse(location));
    } on FormatException {
      return null;
    }
    // The session has to land on the provider, not on whatever scheme a
    // malformed Location happens to name.
    return target.scheme == 'https' ? target : null;
  }

  /// Drops the verifier's cached OAuth verification for a claim.
  ///
  /// [nip98Event] must be a signed NIP-98 (kind 27235) event whose `u` tag is
  /// this endpoint's URL — available as [oauthRevokeUrl] — and whose `method`
  /// tag is `POST`. The verifier validates it through `login.divine.video`
  /// before honouring the revoke.
  ///
  /// Removing the claim's `i` tag is a separate step: the tag lives in the
  /// user's own identity event, which only they can rewrite.
  ///
  /// Throws the same exceptions as [verifyBatch].
  Future<void> revokeOAuth({
    required String platform,
    required String identity,
    required String pubkey,
    required Map<String, dynamic> nip98Event,
  }) async {
    final body = jsonEncode(<String, dynamic>{
      'platform': platform,
      'identity': identity,
      'pubkey': pubkey,
      'event': nip98Event,
    });
    await _post('/auth/oauth/revoke', body);
  }

  /// Absolute URL of the OAuth revoke endpoint.
  ///
  /// The NIP-98 event passed to [revokeOAuth] must carry this exact string in
  /// its `u` tag, so it is exposed rather than rebuilt at the call site.
  String get oauthRevokeUrl => '$_baseUrl/auth/oauth/revoke';

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    return _send(() => _httpClient.get(uri));
  }

  Future<Map<String, dynamic>> _post(String path, String body) {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(
      () => _httpClient.post(
        uri,
        headers: const {'content-type': 'application/json'},
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      final res = await request().timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw VerifierApiException(
          res.statusCode,
          'verifier returned ${res.statusCode}: ${res.body}',
        );
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on VerifierClientException {
      rethrow;
    } on TimeoutException catch (e) {
      throw VerifierTimeoutException(e.toString());
    } on SocketException catch (e) {
      throw VerifierNetworkException(e.toString());
    } on http.ClientException catch (e) {
      throw VerifierNetworkException(e.toString());
    }
  }

  /// Test hook returning the underlying [http.Client]. Do not use in
  /// production code.
  @visibleForTesting
  http.Client get debugHttpClient => _httpClient;
}
