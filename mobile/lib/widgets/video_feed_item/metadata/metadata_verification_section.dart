// ABOUTME: Verification section for the metadata expanded sheet.
// ABOUTME: Shows a checklist of ProofMode/C2PA verification signals present
// ABOUTME: on the video, adapting the _ProofCheckList pattern from
// ABOUTME: BadgeExplanationModal.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
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

    return MetadataSection(
      label: 'Verification',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          _VerificationCheckItem(
            label: 'Device attestation',
            passed: video.proofModeDeviceAttestation != null,
          ),
          _VerificationCheckItem(
            label: 'PGP signature',
            passed: video.proofModePgpFingerprint != null,
          ),
          _VerificationCheckItem(
            label: 'C2PA Content Credentials',
            passed: video.proofModeC2paManifestId != null,
          ),
          _VerificationCheckItem(
            label: 'Proof manifest',
            passed: video.proofModeManifest != null,
          ),
        ],
      ),
    );
  }
}

/// A single check item showing pass/fail status.
class _VerificationCheckItem extends StatelessWidget {
  const _VerificationCheckItem({
    required this.label,
    required this.passed,
  });

  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [
        DivineIcon(
          icon: passed ? DivineIconName.checkCircle : DivineIconName.prohibit,
          size: 14,
          color: passed ? VineTheme.success : VineTheme.onSurfaceMuted,
        ),
        Expanded(
          child: Text(
            label,
            style: VineTheme.bodySmallFont(
              color: passed
                  ? VineTheme.onSurfaceVariant
                  : VineTheme.onSurfaceMuted,
            ),
          ),
        ),
      ],
    );
  }
}
