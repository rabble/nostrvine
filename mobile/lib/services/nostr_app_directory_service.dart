// ABOUTME: Fetches and caches approved Nostr app manifests for the mobile app directory
// ABOUTME: Falls back to cached manifests when the Cloudflare directory is unavailable

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/config/app_config.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NostrAppDirectoryService {
  NostrAppDirectoryService({
    required SharedPreferences sharedPreferences,
    required http.Client client,
    String? baseUrl,
  }) : _sharedPreferences = sharedPreferences,
       _client = client,
       _baseUrl = _normalizeBaseUrl(baseUrl ?? AppConfig.appsDirectoryBaseUrl);

  static const String cacheKey = 'nostr_app_directory_cache';
  static const String eTagCacheKey = 'nostr_app_directory_etag';

  final SharedPreferences _sharedPreferences;
  final http.Client _client;
  final String _baseUrl;

  Future<List<NostrAppDirectoryEntry>> fetchApprovedApps({
    bool useCacheOnly = false,
  }) async {
    if (useCacheOnly) {
      return _readCachedApps();
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
        return _readCachedApps();
      }

      if (response.statusCode != 200) {
        throw http.ClientException(
          'Directory fetch failed with status ${response.statusCode}',
          uri,
        );
      }

      final apps = _parseApps(response.body);
      await _writeCachedApps(apps);

      final responseETag = response.headers['etag'];
      if (responseETag != null && responseETag.isNotEmpty) {
        await _sharedPreferences.setString(eTagCacheKey, responseETag);
      }

      return apps;
    } catch (error, stackTrace) {
      Log.warning(
        'Falling back to cached Nostr app directory: $error',
        name: 'NostrAppDirectoryService',
        category: LogCategory.system,
      );
      Log.debug(
        '$stackTrace',
        name: 'NostrAppDirectoryService',
        category: LogCategory.system,
      );
      return _readCachedApps();
    }
  }

  List<NostrAppDirectoryEntry> _parseApps(String responseBody) {
    final decoded = jsonDecode(responseBody);
    final rawItems = switch (decoded) {
      {'items': final List<dynamic> items} => items,
      final List<dynamic> items => items,
      _ => throw const FormatException('Unexpected app directory payload'),
    };

    final apps = rawItems
        .whereType<Map<String, dynamic>>()
        .map(NostrAppDirectoryEntry.fromJson)
        .where((app) => app.isApproved)
        .toList();

    apps.sort(_compareApps);
    return List<NostrAppDirectoryEntry>.unmodifiable(apps);
  }

  Future<List<NostrAppDirectoryEntry>> _readCachedApps() async {
    final rawCache = _sharedPreferences.getString(cacheKey);
    if (rawCache == null || rawCache.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawCache) as List<dynamic>;
      final apps = decoded
          .whereType<Map<String, dynamic>>()
          .map(NostrAppDirectoryEntry.fromJson)
          .toList();
      apps.sort(_compareApps);
      return List<NostrAppDirectoryEntry>.unmodifiable(apps);
    } catch (error) {
      Log.warning(
        'Ignoring invalid Nostr app directory cache: $error',
        name: 'NostrAppDirectoryService',
        category: LogCategory.system,
      );
      return const [];
    }
  }

  Future<void> _writeCachedApps(List<NostrAppDirectoryEntry> apps) {
    return _sharedPreferences.setString(
      cacheKey,
      jsonEncode(apps.map((app) => app.toJson()).toList(growable: false)),
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
}
