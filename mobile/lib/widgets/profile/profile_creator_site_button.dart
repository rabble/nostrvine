// ABOUTME: Prominent profile CTA linking to the creator's Divine Space site.
// ABOUTME: Builds a deterministic public URL from the profile's Nostr pubkey.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/monetization/monetization_analytics.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/utils/external_link_launcher.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

const _divineSpaceHost = 'divine.space';

/// Returns the public Divine Space URL for [userIdHex].
///
/// Invalid Nostr public keys return `null` so callers never expose a broken
/// profile destination.
Uri? divineSpaceProfileUri(String userIdHex) {
  if (!NostrKeyUtils.isValidKey(userIdHex)) return null;

  try {
    final npub = NostrKeyUtils.encodePubKey(userIdHex);
    return Uri.https(_divineSpaceHost, '/$npub');
  } on Object {
    return null;
  }
}

/// Whether [rawUrl] is the Divine Space profile URL generated for [userIdHex].
///
/// Scheme and host casing, a missing scheme, and trailing slashes are treated
/// as harmless formatting differences. Query strings, fragments, credentials,
/// ports, subdomains, and a different profile remain distinct websites.
bool isDivineSpaceProfileUrlForPubkey(String? rawUrl, String userIdHex) {
  final expected = divineSpaceProfileUri(userIdHex);
  final trimmed = rawUrl?.trim();
  if (expected == null || trimmed == null || trimmed.isEmpty) return false;

  final withScheme =
      trimmed.startsWith(
        RegExp('https?://', caseSensitive: false),
      )
      ? trimmed
      : 'https://$trimmed';
  final candidate = Uri.tryParse(withScheme);
  final authorityStart = withScheme.indexOf('://') + 3;
  final authorityEnd = withScheme.indexOf(RegExp('[/?#]'), authorityStart);
  final rawAuthority = withScheme.substring(
    authorityStart,
    authorityEnd == -1 ? withScheme.length : authorityEnd,
  );
  if (candidate == null ||
      (candidate.scheme != 'http' && candidate.scheme != 'https') ||
      candidate.host.toLowerCase() != _divineSpaceHost ||
      rawAuthority.toLowerCase() != _divineSpaceHost ||
      candidate.userInfo.isNotEmpty ||
      candidate.hasQuery ||
      candidate.hasFragment) {
    return false;
  }

  final normalizedPath = candidate.path.replaceFirst(RegExp(r'/+$'), '');
  return normalizedPath == expected.path;
}

/// A prominent button that opens a creator's public Divine Space profile.
///
/// Renders without outer padding so callers can place it in a row beside
/// other profile actions.
class ProfileCreatorSiteButton extends ConsumerWidget {
  /// Creates the creator-site CTA for a public Nostr profile.
  const ProfileCreatorSiteButton({
    required this.userIdHex,
    required this.isOwnProfile,
    super.key,
  });

  /// The full hex public key of the displayed profile.
  final String userIdHex;

  /// Whether the displayed profile belongs to the current user.
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = divineSpaceProfileUri(userIdHex);
    if (uri == null) return const SizedBox.shrink();

    return DivineButton(
      key: const Key('profile-creator-site-button'),
      type: DivineButtonType.secondary,
      size: DivineButtonSize.small,
      leadingIcon: DivineIconName.globe,
      expanded: true,
      label: isOwnProfile
          ? context.l10n.profileCreatorSiteOwnLabel
          : context.l10n.profileCreatorSiteVisitLabel,
      onPressed: () => _open(context, ref, uri),
    );
  }

  /// Records the discovery tap, then hands off to the shared launcher.
  ///
  /// `divine.space` is a first-party trusted host, so [openExternalLink]
  /// opens it directly (no confirmation) while still centralizing outbound
  /// launch and trusted-domain policy.
  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    trackCreatorSiteCtaTapped(
      analytics: ref.read(analyticsEventSinkProvider),
      isOwnProfile: isOwnProfile,
    );
    await openExternalLink(context, uri.toString());
  }
}
