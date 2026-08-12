// ABOUTME: OAuth configuration for Keycast authentication
// ABOUTME: Holds server URL, client ID, redirect URI, and default scopes

class OAuthConfig {
  const OAuthConfig({
    required this.serverUrl,
    required this.clientId,
    required this.redirectUri,
    this.defaultScopes = const ['policy:social'],
  });
  final String serverUrl;
  final String clientId;
  final String redirectUri;
  final List<String> defaultScopes;

  String get authorizeUrl => '$serverUrl/api/oauth/authorize';
  String get tokenUrl => '$serverUrl/api/oauth/token';
  String get nostrApiUrl => '$serverUrl/api/nostr';

  /// NIP-05 document for this Keycast tenant.
  ///
  /// Keycast derives the tenant from the request Host, so this resolves to
  /// whichever tenant [serverUrl] names. Callers append `?name=<username>`.
  String get nip05Url => '$serverUrl/.well-known/nostr.json';
}
