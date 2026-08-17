import 'dart:convert';

import 'package:divine_status_client/src/models/divine_status.dart';
import 'package:http/http.dart' as http;

/// Component ids the app asks about. Mirrors the status page's own ids.
abstract final class DivineStatusComponents {
  /// The public REST API.
  static const api = 'api';

  /// The Nostr relay.
  static const relay = 'relay';

  /// The upload and publishing path.
  static const uploads = 'uploads';

  /// Playback and public media delivery.
  static const playback = 'playback';

  /// The media CDN.
  static const cdn = 'cdn';

  /// Account login and authentication.
  static const login = 'login';
}

/// Reads component health from the Divine status page.
///
/// The status page is hosted on a different provider from the services it
/// reports on (Cloudflare vs Fastly), which is what makes asking it during an
/// outage worthwhile — it is expected to answer when the API cannot.
class DivineStatusClient {
  /// Creates a client. Both parameters exist for tests; production uses the
  /// real HTTP client and [defaultEndpoint].
  DivineStatusClient({http.Client? httpClient, Uri? endpoint})
    : _httpClient = httpClient ?? http.Client(),
      _endpoint = endpoint ?? defaultEndpoint;

  /// The status page's machine-readable endpoint.
  ///
  /// Deliberately a different host — and a different CDN — from the services
  /// it reports on, so it stays reachable when they are not.
  static final Uri defaultEndpoint = Uri.parse(
    'https://status.divine.video/api/status',
  );

  /// Short by design: this is only ever called on a path where the user is
  /// already looking at a failure, so a slow status page must not extend it.
  static const requestTimeout = Duration(seconds: 5);

  final http.Client _httpClient;
  final Uri _endpoint;

  /// Fetches the current status, or `null` when it cannot be established.
  ///
  /// Never throws: every failure — offline, timeout, non-200, HTML shell,
  /// malformed JSON — collapses to `null`, meaning "no opinion". Callers must
  /// treat `null` as "do not claim an outage" rather than as an outage.
  ///
  /// `FormatException` from a bad decode is an `Exception`, so the single
  /// catch covers it.
  Future<DivineStatus?> fetchStatus() async {
    try {
      final response = await _httpClient
          .get(_endpoint, headers: const {'Accept': 'application/json'})
          .timeout(requestTimeout);

      if (response.statusCode != 200) return null;

      return DivineStatus.tryParse(
        jsonDecode(utf8.decode(response.bodyBytes)) as Object?,
      );
    } on Exception {
      return null;
    }
  }

  /// Releases the underlying HTTP client.
  void close() => _httpClient.close();
}
