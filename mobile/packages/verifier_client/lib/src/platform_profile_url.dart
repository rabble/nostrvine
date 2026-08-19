// ABOUTME: Builds public profile URLs for verified identity platforms.
// ABOUTME: Returns null when a platform has no stable public profile URL.

/// Builds the public profile URI for a verified platform [identity].
///
/// Returns `null` when the identity is malformed or the platform does not
/// expose a stable public profile URL.
Uri? platformProfileUrl(String platform, String identity) {
  final normalizedIdentity = identity.trim();
  if (normalizedIdentity.isEmpty) return null;

  return switch (platform.trim().toLowerCase()) {
    'github' => _httpsUri('github.com', [normalizedIdentity]),
    'twitter' => _handleUri('x.com', normalizedIdentity),
    'bluesky' => _httpsUri('bsky.app', ['profile', normalizedIdentity]),
    'tiktok' => _handleUri(
      'www.tiktok.com',
      normalizedIdentity,
      prefix: '@',
    ),
    'telegram' => _handleUri('t.me', normalizedIdentity),
    'youtube' =>
      normalizedIdentity.startsWith('UC')
          ? _httpsUri('www.youtube.com', ['channel', normalizedIdentity])
          : _handleUri(
              'www.youtube.com',
              normalizedIdentity,
              prefix: '@',
            ),
    'mastodon' => _mastodonUri(normalizedIdentity),
    _ => null,
  };
}

Uri? _handleUri(String host, String identity, {String prefix = ''}) {
  final handle = identity.startsWith('@') ? identity.substring(1) : identity;
  if (handle.isEmpty || handle.contains('/')) return null;
  return _httpsUri(host, ['$prefix$handle']);
}

Uri? _mastodonUri(String identity) {
  final separator = identity.indexOf('/');
  if (separator <= 0 || separator == identity.length - 1) return null;

  final instance = identity.substring(0, separator);
  final rawUsername = identity.substring(separator + 1);
  final username = rawUsername.startsWith('@')
      ? rawUsername.substring(1)
      : rawUsername;
  if (username.isEmpty || username.contains('/')) return null;

  final origin = Uri.tryParse('https://$instance');
  if (origin == null ||
      origin.scheme != 'https' ||
      origin.host.isEmpty ||
      origin.userInfo.isNotEmpty ||
      origin.path.isNotEmpty ||
      origin.hasQuery ||
      origin.hasFragment ||
      origin.authority != instance) {
    return null;
  }

  return origin.replace(pathSegments: ['@$username']);
}

Uri _httpsUri(String host, List<String> pathSegments) =>
    Uri(scheme: 'https', host: host, pathSegments: pathSegments);
