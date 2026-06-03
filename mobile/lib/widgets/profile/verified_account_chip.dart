// ABOUTME: VerifiedAccountChip — single chip for one verified identity claim.
// ABOUTME: Tapping opens the platform profile in the system browser.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pluggable URL launcher for tests.
typedef ChipUrlLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLauncher(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Chip rendering a single verified [IdentityClaim].
///
/// Tapping opens the platform profile via [launchUrl] (override [launcher] in
/// tests). Platforms without a clean public URL fall through to the verifier
/// lookup page.
class VerifiedAccountChip extends StatelessWidget {
  /// Creates a chip for [claim]. [launcher] defaults to the system browser.
  const VerifiedAccountChip({
    required this.claim,
    super.key,
    this.launcher = _defaultLauncher,
  });

  /// The verified claim this chip represents.
  final IdentityClaim claim;

  /// URL launcher hook for tests.
  final ChipUrlLauncher launcher;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final url = _platformUrl(claim);
    return Semantics(
      button: true,
      label: l10n.verifiedAccountChipSemanticLabel(
        claim.platform,
        claim.identity,
      ),
      child: Material(
        color: VineTheme.surfaceBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: VineTheme.neutral10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => launcher(Uri.parse(url)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DivineIcon(
                  icon: DivineIconName.globe,
                  size: 14,
                  color: VineTheme.lightText,
                ),
                const SizedBox(width: 6),
                Text(
                  '${claim.platform}/${claim.identity}',
                  style: VineTheme.labelMediumFont(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds an external URL for [claim].
///
/// Platforms with a stable public profile URL (`github`, `twitter`, `bluesky`,
/// `youtube`, `tiktok`) get a direct link. Everything else (mastodon, discord,
/// telegram, unknown) routes through the verifier lookup page so the
/// verifier itself can resolve the canonical URL.
String _platformUrl(IdentityClaim claim) {
  switch (claim.platform.toLowerCase()) {
    case 'github':
      return 'https://github.com/${claim.identity}';
    case 'twitter':
      return 'https://twitter.com/${claim.identity}';
    case 'bluesky':
      return 'https://bsky.app/profile/${claim.identity}';
    case 'youtube':
      return 'https://youtube.com/@${claim.identity}';
    case 'tiktok':
      return 'https://tiktok.com/@${claim.identity}';
    case 'mastodon':
    case 'discord':
    case 'telegram':
    default:
      return 'https://verifyer.divine.video/u'
          '?platform=${claim.platform}'
          '&identity=${Uri.encodeComponent(claim.identity)}';
  }
}
