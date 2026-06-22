import 'package:models/src/video_event.dart';

/// The minimum ProofMode signal a video must carry to pass the serving policy.
enum ProofModeServingLevel {
  /// Require a backend/user-verifiable certified ProofMode level.
  certified,

  /// Allow any usable ProofMode evidence, including the basic proof tier.
  anyProof,
}

/// Decides whether a video may be shown by Divine feed and lookup surfaces.
///
/// The policy is intentionally independent from user preferences such as
/// blocklists, content labels, host filters, and aspect-ratio filters. Those
/// filters still apply after this baseline serving eligibility check.
class VideoServingPolicy {
  const VideoServingPolicy({
    required Set<String> allowedClassicVinePubkeys,
    this.proofModeLevel = ProofModeServingLevel.certified,
  }) : _allowedClassicVinePubkeys = allowedClassicVinePubkeys;

  /// No-op policy for tests and contexts that do not want serving restriction.
  static const VideoServingPolicy unrestricted =
      _UnrestrictedVideoServingPolicy();

  final Set<String> _allowedClassicVinePubkeys;
  final ProofModeServingLevel proofModeLevel;

  /// Returns true when [video] is eligible for Divine to serve/display.
  bool allows(VideoEvent video) {
    return isAllowedProofModeVideo(video) || isAllowedClassicVine(video);
  }

  /// Returns true when [video] satisfies the configured ProofMode threshold.
  bool isAllowedProofModeVideo(VideoEvent video) {
    return switch (proofModeLevel) {
      ProofModeServingLevel.certified =>
        video.isVerifiedMobile || video.isVerifiedWeb,
      ProofModeServingLevel.anyProof => video.hasProofMode,
    };
  }

  /// Returns true when [video] is a recovered Vine from a curated account.
  bool isAllowedClassicVine(VideoEvent video) {
    return video.isOriginalVine &&
        _allowedClassicVinePubkeys.contains(video.pubkey.toLowerCase());
  }
}

class _UnrestrictedVideoServingPolicy extends VideoServingPolicy {
  const _UnrestrictedVideoServingPolicy()
    : super(
        allowedClassicVinePubkeys: const {},
        proofModeLevel: ProofModeServingLevel.anyProof,
      );

  @override
  bool allows(VideoEvent video) => true;
}
