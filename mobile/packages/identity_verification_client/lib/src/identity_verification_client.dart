// ABOUTME: HTTP client for divine-identify-verification-service /verify endpoint
// ABOUTME: Returns the verified subset of NIP-39 identity claims for a pubkey.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:identity_verification_client/src/exceptions.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';

/// Client wrapping `POST {baseUri}/verify` on
/// `divine-identify-verification-service`.
class IdentityVerificationClient {
  /// Creates a new [IdentityVerificationClient].
  ///
  /// [baseUri] is the root URL of the verification service.
  /// [httpClient] is an optional HTTP client; one is created if omitted.
  IdentityVerificationClient({
    required Uri baseUri,
    http.Client? httpClient,
  }) : _baseUri = baseUri,
       _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  /// POSTs [claims] for [pubkey] to the verifier and returns the verified
  /// subset.
  ///
  /// Throws [IdentityVerificationException] on non-2xx responses or
  /// transport errors.
  Future<List<NostrIdentityClaim>> verifyClaims({
    required String pubkey,
    required List<NostrIdentityClaim> claims,
  }) async {
    if (claims.isEmpty) return const [];

    final endpoint = _baseUri.resolve('/verify');
    final body = jsonEncode({
      'pubkey': pubkey,
      'claims': [
        for (final c in claims)
          {
            'platform': c.platform.name,
            'identity': c.identity,
            'proof': c.proof,
          },
      ],
    });

    http.Response response;
    try {
      response = await _httpClient.post(
        endpoint,
        headers: const {'content-type': 'application/json'},
        body: body,
      );
    } on SocketException catch (e) {
      throw IdentityVerificationException(
        'network error',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw IdentityVerificationException(
        'http client error',
        cause: e,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IdentityVerificationException(
        'verifier returned ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (json['results'] as List?) ?? const [];
    final verified = <NostrIdentityClaim>[];
    for (final raw in results) {
      final entry = raw as Map<String, dynamic>;
      if (entry['verified'] != true) continue;
      final platform = IdentityPlatform.fromTagPrefix(
        entry['platform']?.toString() ?? '',
      );
      if (platform == null) continue;
      final identity = entry['identity']?.toString() ?? '';
      if (identity.isEmpty) continue;
      final claim = claims.firstWhere(
        (c) => c.platform == platform && c.identity == identity,
        orElse: () => NostrIdentityClaim(
          platform: platform,
          identity: identity,
          proof: '',
        ),
      );
      verified.add(claim);
    }
    return verified;
  }

  /// Releases the underlying [http.Client] if owned.
  @visibleForTesting
  void close() => _httpClient.close();
}
