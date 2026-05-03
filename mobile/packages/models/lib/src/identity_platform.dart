// ABOUTME: Enum of NIP-39 identity platforms supported by
// divine-identify-verification-service.
// ABOUTME: Plus tag-prefix parser and canonical profile-URL builder per
// platform.

/// Identity platforms supported by `divine-identify-verification-service`.
///
/// The string used in NIP-39 `["i", "<prefix>:<identity>", "<proof>"]`
/// tags is the lowercase enum name, except `twitter` which also accepts
/// the alias `x`.
enum IdentityPlatform {
  github,
  twitter,
  bluesky,
  mastodon,
  telegram,
  discord,
  youtube,
  tiktok
  ;

  /// Parses a NIP-39 platform prefix. Returns `null` for unknown values.
  static IdentityPlatform? fromTagPrefix(String prefix) {
    final normalized = prefix.toLowerCase();
    if (normalized == 'x') return IdentityPlatform.twitter;
    for (final p in IdentityPlatform.values) {
      if (p.name == normalized) return p;
    }
    return null;
  }

  /// Human-readable platform name.
  String get displayName => switch (this) {
    IdentityPlatform.github => 'GitHub',
    IdentityPlatform.twitter => 'X',
    IdentityPlatform.bluesky => 'Bluesky',
    IdentityPlatform.mastodon => 'Mastodon',
    IdentityPlatform.telegram => 'Telegram',
    IdentityPlatform.discord => 'Discord',
    IdentityPlatform.youtube => 'YouTube',
    IdentityPlatform.tiktok => 'TikTok',
  };

  /// Canonical browser URL for [identity] on this platform.
  Uri canonicalProfileUrl(String identity) => switch (this) {
    IdentityPlatform.github => Uri.parse('https://github.com/$identity'),
    IdentityPlatform.twitter => Uri.parse('https://x.com/$identity'),
    IdentityPlatform.bluesky => Uri.parse('https://bsky.app/profile/$identity'),
    IdentityPlatform.mastodon => _mastodonUrl(identity),
    IdentityPlatform.telegram => Uri.parse('https://t.me/$identity'),
    IdentityPlatform.discord => Uri.parse(
      'https://discord.com/users/$identity',
    ),
    IdentityPlatform.youtube => Uri.parse('https://youtube.com/@$identity'),
    IdentityPlatform.tiktok => Uri.parse('https://tiktok.com/@$identity'),
  };

  static Uri _mastodonUrl(String identity) {
    final atIndex = identity.indexOf('@');
    if (atIndex == -1) {
      return Uri.parse('https://mastodon.social/@$identity');
    }
    final user = identity.substring(0, atIndex);
    final host = identity.substring(atIndex + 1);
    return Uri.parse('https://$host/@$user');
  }
}
