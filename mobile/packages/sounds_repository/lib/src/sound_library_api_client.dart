// ABOUTME: HTTP client for provider-backed sound library search.
// ABOUTME: Maps proxy-normalized provider results into AudioEvent models.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:models/models.dart'
    show AudioEvent, AudioExternalSource, AudioLicenseMetadata;

/// Metadata describing one sound-library proxy provider exposed by the API.
@immutable
class SoundLibraryProviderInfo {
  /// Creates a [SoundLibraryProviderInfo].
  const SoundLibraryProviderInfo({
    required this.id,
    required this.label,
    required this.enabled,
  });

  /// Parses a provider entry from the proxy `/api/sounds/providers` response.
  ///
  /// Throws [SoundLibraryApiException] when `id` or `label` is missing or
  /// non-string.
  factory SoundLibraryProviderInfo.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final label = json['label'];
    if (id is! String || label is! String) {
      throw const SoundLibraryApiException(
        'Provider entry missing id or label',
      );
    }
    return SoundLibraryProviderInfo(
      id: id,
      label: label,
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  /// Stable provider identifier (`divine`, `nostr`, `freesound`, `openverse`).
  final String id;

  /// Human-facing label for the provider (e.g. `Community`, `Freesound`).
  final String label;

  /// Whether the proxy currently has this provider routed.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is SoundLibraryProviderInfo &&
      other.id == id &&
      other.label == label &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, label, enabled);
}

/// A paged search response from the sound-library API.
@immutable
class SoundLibrarySearchResponse {
  /// Creates a [SoundLibrarySearchResponse].
  const SoundLibrarySearchResponse({
    required this.sounds,
    required this.count,
    this.nextPage,
  });

  /// Sounds returned for the requested page.
  final List<AudioEvent> sounds;

  /// Total result count (across all pages) reported by the proxy.
  final int count;

  /// Next page number to request, or `null` when there are no more pages.
  final int? nextPage;
}

/// A request to search the sound library across one provider.
@immutable
class SoundLibrarySearchRequest {
  /// Creates a [SoundLibrarySearchRequest].
  const SoundLibrarySearchRequest({
    required this.query,
    this.provider = 'divine',
    this.page = 1,
    this.pageSize = 20,
    this.licenseType,
  });

  /// User-entered search query string.
  final String query;

  /// Provider id to route the search to.
  final String provider;

  /// 1-based page number.
  final int page;

  /// Number of results per page.
  final int pageSize;

  /// Optional license-type filter (e.g. `cc0`, `by`).
  final String? licenseType;

  @override
  bool operator ==(Object other) {
    return other is SoundLibrarySearchRequest &&
        other.query == query &&
        other.provider == provider &&
        other.page == page &&
        other.pageSize == pageSize &&
        other.licenseType == licenseType;
  }

  @override
  int get hashCode => Object.hash(query, provider, page, pageSize, licenseType);
}

/// Exception type thrown by [SoundLibraryApiClient] on network, parse, or
/// upstream-provider errors.
class SoundLibraryApiException implements Exception {
  /// Creates a [SoundLibraryApiException].
  const SoundLibraryApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.provider,
  });

  /// Human-readable error message.
  final String message;

  /// Stable machine-readable error code from the proxy response (e.g.
  /// `provider_disabled`, `invalid_query`).
  final String? code;

  /// HTTP status code that produced the error, or `null` if pre-request.
  final int? statusCode;

  /// Provider id (`divine` / `nostr` / `freesound` / `openverse`) the request
  /// was routed to, when applicable.
  final String? provider;

  @override
  String toString() =>
      'SoundLibraryApiException: $message (${statusCode ?? 'no status'})';
}

/// HTTP client for the proxy-backed sound library API.
///
/// The proxy normalizes results across providers (divine, nostr, freesound,
/// openverse) into a single shape; this client just enforces JSON validity
/// and wraps responses in typed models.
class SoundLibraryApiClient {
  /// Creates a [SoundLibraryApiClient].
  ///
  /// [baseUri] is the proxy origin (e.g. `https://api.divine.video`).
  /// [httpClient] and [timeout] are overrideable for tests.
  SoundLibraryApiClient({
    required Uri baseUri,
    http.Client? httpClient,
    Duration? timeout,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUri = baseUri,
       _timeout = timeout ?? const Duration(seconds: 12);

  final http.Client _httpClient;
  final Uri _baseUri;
  final Duration _timeout;

  /// List the providers the proxy will route to, with their enabled state.
  ///
  /// Throws [SoundLibraryApiException] on network / parse / non-2xx response.
  Future<List<SoundLibraryProviderInfo>> fetchProviders() async {
    final response = await _get(_uri('/api/sounds/providers'));
    final decoded = _decodeJson(response);
    if (decoded is! List) {
      throw const SoundLibraryApiException('Provider response was invalid');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SoundLibraryProviderInfo.fromJson)
        .toList(growable: false);
  }

  /// Search the sound library for [query] against [provider].
  ///
  /// Throws [SoundLibraryApiException] on empty query, network failure,
  /// parse failure, or non-2xx response.
  Future<SoundLibrarySearchResponse> search({
    required String query,
    String provider = 'divine',
    int page = 1,
    int pageSize = 20,
    String? licenseType,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      throw const SoundLibraryApiException(
        'Search query is required',
        code: 'invalid_query',
      );
    }

    final response = await _get(
      _uri(
        '/api/sounds/search',
        queryParameters: {
          'q': trimmedQuery,
          'provider': provider,
          'page': page.toString(),
          'page_size': pageSize.toString(),
          if (licenseType != null && licenseType.trim().isNotEmpty)
            'license_type': licenseType.trim(),
        },
      ),
    );
    final decoded = _decodeJson(response);
    if (decoded is! Map<String, dynamic>) {
      throw const SoundLibraryApiException('Search response was invalid');
    }

    final rawResults = decoded['results'];
    if (rawResults is! List) {
      throw const SoundLibraryApiException('Search response was invalid');
    }

    final sounds = <AudioEvent>[];
    for (final row in rawResults.whereType<Map<String, dynamic>>()) {
      sounds.add(_soundFromJson(row));
    }

    return SoundLibrarySearchResponse(
      sounds: List<AudioEvent>.unmodifiable(sounds),
      count: decoded['count'] as int? ?? sounds.length,
      nextPage: decoded['nextPage'] as int?,
    );
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      final response = await _httpClient
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw _exceptionFromResponse(response);
    } on TimeoutException {
      throw const SoundLibraryApiException('Sound library request timed out');
    } on http.ClientException catch (error) {
      throw SoundLibraryApiException('Sound library network error: $error');
    }
  }

  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    return _baseUri.replace(path: path, queryParameters: queryParameters);
  }

  Object? _decodeJson(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw SoundLibraryApiException(
        'Sound library response was not valid JSON',
        statusCode: response.statusCode,
      );
    }
  }

  SoundLibraryApiException _exceptionFromResponse(http.Response response) {
    final decoded = _tryDecodeError(response.body);
    if (decoded != null) {
      return SoundLibraryApiException(
        decoded['message']?.toString() ?? 'Sound library request failed',
        code: decoded['error']?.toString(),
        provider: decoded['provider']?.toString(),
        statusCode: response.statusCode,
      );
    }

    return SoundLibraryApiException(
      'Sound library request failed',
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic>? _tryDecodeError(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Parses one sound row from the search response.
  ///
  /// Throws [SoundLibraryApiException] if a required string field is missing
  /// or has the wrong type, so a single malformed row surfaces as a typed
  /// API error instead of an opaque [TypeError] that aborts the whole map.
  AudioEvent _soundFromJson(Map<String, dynamic> json) {
    final id = _requireString(json, 'id');
    final provider = _requireString(json, 'provider');
    final providerId = _requireString(json, 'providerId');
    final previewUrl = _requireString(json, 'previewUrl');

    final licenseJson = json['license'];
    if (licenseJson is! Map<String, dynamic>) {
      throw SoundLibraryApiException(
        'Sound row "$id" missing license',
        provider: provider,
      );
    }

    final AudioLicenseMetadata license;
    try {
      license = AudioLicenseMetadata.fromJson(licenseJson);
      // AudioLicenseMetadata.fromJson throws raw TypeError on missing /
      // wrong-typed fields; we surface that as our typed API exception so a
      // single malformed row doesn't abort the whole search.
      // ignore: avoid_catching_errors
    } on TypeError catch (error) {
      throw SoundLibraryApiException(
        'Sound row "$id" has invalid license metadata: $error',
        provider: provider,
      );
    }

    return AudioEvent(
      id: id,
      pubkey: AudioEvent.externalProviderMarker,
      createdAt: 0,
      url: previewUrl,
      mimeType: 'audio/mpeg',
      duration: (json['duration'] as num?)?.toDouble(),
      title: json['title'] as String?,
      source: json['source'] as String?,
      externalSource: AudioExternalSource(
        provider: provider,
        providerSoundId: providerId,
        providerName: _providerLabel(provider),
        creatorName: json['creator'] as String?,
        sourceUrl: json['sourceUrl'] as String?,
        previewUrl: previewUrl,
        license: license,
      ),
    );
  }

  String _requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw SoundLibraryApiException(
        'Sound row missing required field "$key"',
      );
    }
    return value;
  }

  String _providerLabel(String provider) {
    return switch (provider) {
      'divine' => 'Divine',
      'nostr' => 'Community',
      'freesound' => 'Freesound',
      'openverse' => 'Openverse',
      _ => provider,
    };
  }
}
