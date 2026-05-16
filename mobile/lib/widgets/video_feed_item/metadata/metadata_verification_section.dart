// ABOUTME: Verification section for the metadata expanded sheet.
// ABOUTME: Shows a checklist of ProofMode/C2PA verification signals present
// ABOUTME: on the video, adapting the _ProofCheckList pattern from
// ABOUTME: BadgeExplanationModal.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_section.dart';

/// Verification section showing which ProofMode / C2PA signals are present.
///
/// Returns [SizedBox.shrink] when the video has no proof data at all.
class MetadataVerificationSection extends StatelessWidget {
  const MetadataVerificationSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    if (!video.hasProofMode) return const SizedBox.shrink();

    final l10n = context.l10n;
    return MetadataSection(
      label: l10n.metadataVerificationLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          _VerificationCheckItem(
            label: l10n.metadataDeviceAttestation,
            passed: video.proofModeDeviceAttestation != null,
          ),
          // Reuse the badge-explanation copy — same English value, no
          // dedicated `metadata*` key exists for these two signals.
          _VerificationCheckItem(
            label: l10n.badgeExplanationPgpSignature,
            passed: video.proofModePgpFingerprint != null,
          ),
          _VerificationCheckItem(
            label: l10n.badgeExplanationC2paCredentials,
            passed: video.proofModeC2paManifestId != null,
          ),
          _VerificationCheckItem(
            label: l10n.metadataProofManifest,
            passed: video.proofModeManifest != null,
          ),
        ],
      ),
    );
  }
}

/// A single check item showing pass/fail status.
///
/// Label sits on the left and the status icon on the right with a
/// `space-between` row layout, matching Figma node `15675:27860`.
/// A green check marks a passed signal; a muted X marks a missing one.
class _VerificationCheckItem extends StatelessWidget {
  const _VerificationCheckItem({required this.label, required this.passed});

  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: VineTheme.bodyMediumFont(
              color: passed ? VineTheme.whiteText : VineTheme.onSurfaceMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        DivineIcon(
          icon: passed ? DivineIconName.check : DivineIconName.x,
          color: passed ? VineTheme.success : VineTheme.onSurfaceMuted,
        ),
      ],
    );
  }
}
