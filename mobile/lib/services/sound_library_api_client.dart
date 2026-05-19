// ABOUTME: HTTP client for provider-backed sound library search.
// ABOUTME: Maps proxy-normalized provider results into AudioEvent models.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:models/models.dart'
    show AudioEvent, AudioExternalSource, AudioLicenseMetadata;
import 'package:openvine/config/app_config.dart';

@immutable
class SoundLibraryProviderInfo {
  const SoundLibraryProviderInfo({
    required this.id,
    required this.label,
    required this.enabled,
  });

  factory SoundLibraryProviderInfo.fromJson(Map<String, dynamic> json) {
    return SoundLibraryProviderInfo(
      id: json['id'] as String,
      label: json['label'] as String,
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  final String id;
  final String label;
  final bool enabled;
}

@immutable
class SoundLibrarySearchResponse {
  const SoundLibrarySearchResponse({
    required this.sounds,
    required this.count,
    this.nextPage,
  });

  final List<AudioEvent> sounds;
  final int count;
  final int? nextPage;
}

@immutable
class SoundLibrarySearchRequest {
  const SoundLibrarySearchRequest({
    required this.query,
    this.provider = 'divine',
    this.page = 1,
    this.pageSize = 20,
    this.licenseType,
  });

  final String query;
  final String provider;
  final int page;
  final int pageSize;
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

class SoundLibraryApiException implements Exception {
  const SoundLibraryApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.provider,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final String? provider;

  @override
  String toString() =>
      'SoundLibraryApiException: $message (${statusCode ?? 'no status'})';
}

class SoundLibraryApiClient {
  SoundLibraryApiClient({
    http.Client? httpClient,
    Uri? baseUri,
    Duration? timeout,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUri = baseUri ?? Uri.parse(AppConfig.backendBaseUrl),
       _timeout = timeout ?? const Duration(seconds: 12);

  final http.Client _httpClient;
  final Uri _baseUri;
  final Duration _timeout;

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

    return SoundLibrarySearchResponse(
      sounds: rawResults
          .whereType<Map<String, dynamic>>()
          .map(_soundFromJson)
          .toList(growable: false),
      count: decoded['count'] as int? ?? rawResults.length,
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

  AudioEvent _soundFromJson(Map<String, dynamic> json) {
    final provider = json['provider'] as String;
    final providerId = json['providerId'] as String;
    final previewUrl = json['previewUrl'] as String;
    final license = AudioLicenseMetadata.fromJson(
      json['license'] as Map<String, dynamic>,
    );

    return AudioEvent(
      id: json['id'] as String,
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
