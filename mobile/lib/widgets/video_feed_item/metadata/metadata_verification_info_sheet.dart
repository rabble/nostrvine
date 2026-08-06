// ABOUTME: Explainer sheet for the four verification checks in the metadata
// ABOUTME: sheet. States what each check proves, and what a missing one does
// ABOUTME: not mean.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/external_link_launcher.dart';
import 'package:openvine/widgets/video_recorder/modes/upload/upload_explainer_constants.dart';

/// Bottom sheet explaining the ProofMode / C2PA checks listed by
/// [MetadataVerificationSection].
///
/// The checklist labels ("Device attestation", "PGP signature", …) are
/// domain jargon on their own — four green ticks read as decoration until
/// the viewer knows what each one is evidence of. This sheet supplies that,
/// including the deliberate limit: a missing check is not evidence of
/// forgery.
class MetadataVerificationInfoSheet extends StatelessWidget {
  @visibleForTesting
  const MetadataVerificationInfoSheet({super.key});

  /// Opens the explainer over the metadata sheet.
  ///
  /// Deliberately uses [VineBottomSheet.show] rather than the pause-aware
  /// `showVideoPausingVineBottomSheet`: the metadata sheet underneath has
  /// already flipped `OverlayVisibility.setBottomSheetOpen(true)`, and that
  /// flag is a plain bool rather than a counter — so a nested pause-aware
  /// sheet would clear it on dismiss and resume playback behind the
  /// still-open metadata sheet.
  static Future<void> show(BuildContext context) {
    return VineBottomSheet.show<void>(
      context: context,
      contentTitle: context.l10n.metadataVerificationInfoTitle,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      useRootNavigator: true,
      body: const SingleChildScrollView(
        child: MetadataVerificationInfoSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 20,
        children: [
          Text(
            l10n.metadataVerificationInfoIntro,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          _CheckExplanation(
            label: l10n.metadataDeviceAttestation,
            description: l10n.metadataVerificationInfoDeviceAttestation,
          ),
          _CheckExplanation(
            label: l10n.metadataPgpSignature,
            description: l10n.metadataVerificationInfoPgpSignature,
          ),
          _CheckExplanation(
            label: l10n.metadataC2paCredentials,
            description: l10n.metadataVerificationInfoC2paCredentials,
          ),
          _CheckExplanation(
            label: l10n.metadataProofManifest,
            description: l10n.metadataVerificationInfoProofManifest,
          ),
          Text(
            l10n.metadataVerificationInfoFootnote,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
          const _LearnMoreLink(),
        ],
      ),
    );
  }
}

/// One check: its checklist label, then what that check is evidence of.
class _CheckExplanation extends StatelessWidget {
  const _CheckExplanation({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            label,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          Text(
            description,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Outbound link to the public ProofMode page.
class _LearnMoreLink extends StatelessWidget {
  const _LearnMoreLink();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Shown without the scheme, so the label can never drift from the URL.
    final displayUrl = proofmodeLearnMoreUrl.replaceFirst('https://', '');

    return Semantics(
      button: true,
      link: true,
      label: '${l10n.metadataVerificationInfoLearnMoreAt}$displayUrl',
      child: GestureDetector(
        onTap: () => openExternalLink(context, proofmodeLearnMoreUrl),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: l10n.metadataVerificationInfoLearnMoreAt),
                  TextSpan(
                    text: displayUrl,
                    style:
                        VineTheme.bodyMediumFont(
                          color: context.vineColors.primaryText,
                        ).copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: context.vineColors.primaryText,
                        ),
                  ),
                ],
              ),
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
