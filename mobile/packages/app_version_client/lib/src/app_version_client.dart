import 'dart:convert';

import 'package:app_version_client/app_version_client.dart';
import 'package:http/http.dart' as http;

/// Fetches the latest release info from the GitHub Releases API.
class AppVersionClient {
  /// Creates an [AppVersionClient].
  ///
  /// An optional [httpClient] can be provided for testing.
  AppVersionClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsHttpClient;

  /// Fetches the latest release from GitHub.
  ///
  /// Throws [AppVersionFetchException] on network or parsing errors.
  Future<AppVersionInfo> fetchLatestRelease() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/'
      '${AppVersionConstants.repoOwner}/'
      '${AppVersionConstants.repoName}/'
      'releases/latest',
    );

    try {
      final response = await _httpClient.get(
        uri,
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) {
        throw AppVersionFetchException(
          'GitHub API returned ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final body = json['body'] as String? ?? '';

      return AppVersionInfo(
        latestVersion: json['tag_name'] as String,
        publishedAt: DateTime.parse(json['published_at'] as String),
        releaseNotesUrl: json['html_url'] as String,
        minimumVersion: _parseMinimumVersion(body),
        releaseHighlights: _parseHighlights(body),
      );
    } on AppVersionFetchException {
      rethrow;
    } catch (e) {
      throw AppVersionFetchException('Failed to fetch release info: $e');
    }
  }

  String? _parseMinimumVersion(String body) {
    final match = AppVersionConstants.minimumVersionPattern.firstMatch(body);
    return match?.group(1);
  }

  List<String> _parseHighlights(String body) {
    return AppVersionConstants.highlightPattern
        .allMatches(body)
        .map((m) => m.group(1)!.trim())
        .take(5)
        .toList();
  }

  /// Disposes the HTTP client if it was created internally.
  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
  }
}

/// Thrown when fetching version info fails.
class AppVersionFetchException implements Exception {
  /// Creates an [AppVersionFetchException] with the given [message].
  const AppVersionFetchException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'AppVersionFetchException: $message';
}
