/// Client-pinned navigation origins for first-party Nostr apps.
///
/// These origins may be loaded in the sandbox without receiving NIP-07 bridge
/// capability. The expected app origin prevents a remote directory entry from
/// claiming a first-party slug and inheriting these navigation exceptions.
class FirstPartyNostrAppNavigation {
  /// Creates a first-party navigation exception config.
  const FirstPartyNostrAppNavigation({
    required this.expectedOrigin,
    required this.allowedNavigationOrigins,
  });

  /// Origin that must match the app entry before applying exceptions.
  final String expectedOrigin;

  /// Extra origins the sandbox may navigate to without bridge capability.
  final List<String> allowedNavigationOrigins;
}

/// First-party navigation exception configs keyed by app slug.
const Map<String, FirstPartyNostrAppNavigation>
firstPartyNostrAppNavigationBySlug = {
  'badges': FirstPartyNostrAppNavigation(
    expectedOrigin: 'https://badges.divine.video',
    allowedNavigationOrigins: ['https://login.divine.video'],
  ),
};
