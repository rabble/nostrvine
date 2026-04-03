import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:nostr_app_bridge_repository/src/models/nostr_app_directory_entry.dart';
import 'package:nostr_app_bridge_repository/src/preloaded_nostr_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fetches and caches approved Nostr app manifests from the
/// directory worker, falling back to cached or bundled entries.
class NostrAppDirectoryService {
  /// Creates a directory service.
  ///
  /// [baseUrl] is the root URL of the apps directory API
  /// (e.g. `https://apps.divine.video`). It is required.
  NostrAppDirectoryService({
    required SharedPreferences sharedPreferences,
    required http.Client client,
    required String baseUrl,
  }) : _sharedPreferences = sharedPreferences,
       _client = client,
       _baseUrl = _normalizeBaseUrl(baseUrl);

  /// SharedPreferences key for the cached app list.
  static const String cacheKey = 'nostr_app_directory_cache';

  /// SharedPreferences key for the cached ETag.
  static const String eTagCacheKey = 'nostr_app_directory_etag';

  final SharedPreferences _sharedPreferences;
  final http.Client _client;
  final String _baseUrl;

  /// Fetches approved apps, optionally from cache only.
  Future<List<NostrAppDirectoryEntry>> fetchApprovedApps({
    bool useCacheOnly = false,
  }) async {
    if (useCacheOnly) {
      return _mergeWithPreloadedApps(await _readCachedApps());
    }

    final uri = Uri.parse('$_baseUrl/v1/apps');
    final cachedETag = _sharedPreferences.getString(eTagCacheKey);

    try {
      final response = await _client.get(
        uri,
        headers: {
          if (cachedETag != null && cachedETag.isNotEmpty)
            'If-None-Match': cachedETag,
        },
      );

      if (response.statusCode == 304) {
        return _mergeWithPreloadedApps(
          await _readCachedApps(),
        );
      }

      if (response.statusCode != 200) {
        throw http.ClientException(
          'Directory fetch failed with status '
          '${response.statusCode}',
          uri,
        );
      }

      final remoteApps = _parseApps(response.body);
      await _writeCachedApps(remoteApps);

      final responseETag = response.headers['etag'];
      if (responseETag != null && responseETag.isNotEmpty) {
        await _sharedPreferences.setString(
          eTagCacheKey,
          responseETag,
        );
      }

      return _mergeWithPreloadedApps(remoteApps);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Falling back to cached Nostr app directory: $error',
        name: 'NostrAppDirectoryService',
        error: error,
        stackTrace: stackTrace,
      );
      return _mergeWithPreloadedApps(await _readCachedApps());
    }
  }

  List<NostrAppDirectoryEntry> _parseApps(String responseBody) {
    final decoded = jsonDecode(responseBody);
    final rawItems = switch (decoded) {
      {'items': final List<dynamic> items} => items,
      final List<dynamic> items => items,
      _ => throw const FormatException(
        'Unexpected app directory payload',
      ),
    };

    final apps =
        rawItems
            .whereType<Map<String, dynamic>>()
            .map(NostrAppDirectoryEntry.fromJson)
            .toList()
          ..sort(_compareApps);
    return List<NostrAppDirectoryEntry>.unmodifiable(apps);
  }

  Future<List<NostrAppDirectoryEntry>> _readCachedApps() async {
    final rawCache = _sharedPreferences.getString(cacheKey);
    if (rawCache == null || rawCache.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawCache) as List<dynamic>;
      final apps =
          decoded
              .whereType<Map<String, dynamic>>()
              .map(NostrAppDirectoryEntry.fromJson)
              .toList()
            ..sort(_compareApps);
      return List<NostrAppDirectoryEntry>.unmodifiable(apps);
    } on Object catch (error) {
      developer.log(
        'Ignoring invalid Nostr app directory cache: $error',
        name: 'NostrAppDirectoryService',
        error: error,
      );
      return const [];
    }
  }

  Future<void> _writeCachedApps(
    List<NostrAppDirectoryEntry> apps,
  ) {
    return _sharedPreferences.setString(
      cacheKey,
      jsonEncode(
        apps.map((app) => app.toJson()).toList(growable: false),
      ),
    );
  }

  static String _normalizeBaseUrl(String baseUrl) {
    if (baseUrl.endsWith('/')) {
      return baseUrl.substring(0, baseUrl.length - 1);
    }
    return baseUrl;
  }

  static int _compareApps(
    NostrAppDirectoryEntry left,
    NostrAppDirectoryEntry right,
  ) {
    final sortComparison = left.sortOrder.compareTo(right.sortOrder);
    if (sortComparison != 0) {
      return sortComparison;
    }
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  List<NostrAppDirectoryEntry> _mergeWithPreloadedApps(
    List<NostrAppDirectoryEntry> remoteOrCachedApps,
  ) {
    final appsBySlug = <String, NostrAppDirectoryEntry>{
      for (final app in preloadedNostrApps) app.slug: app,
    };

    for (final app in remoteOrCachedApps) {
      if (app.isApproved) {
        appsBySlug[app.slug] = app;
      } else {
        appsBySlug.remove(app.slug);
      }
    }

    final apps = appsBySlug.values.toList(growable: false)..sort(_compareApps);
    return List<NostrAppDirectoryEntry>.unmodifiable(apps);
  }
}
