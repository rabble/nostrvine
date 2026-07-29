// ABOUTME: Shared helper for audio attribution creator credit.
// ABOUTME: Keeps feed-row and metadata-sheet credit logic in sync.

import 'package:models/models.dart';

/// Shared creator-credit selection for the two visible sound surfaces.
class AudioAttributionCredit {
  const AudioAttributionCredit._();

  /// The reused sound's original creator, carried on the video via its
  /// inspired-by source. Null when absent, so the video's own author is
  /// credited.
  ///
  /// Only call this for a video that actually references a sound. Inspired-by
  /// is a general credit, so on a video with no audio reference it says
  /// nothing about who made the sound.
  ///
  /// Even then it is a best-effort credit rather than a guarantee:
  /// `getActiveDraft` auto-populates inspired-by from the selected sound's
  /// source video only when the draft has none set, so one set for an
  /// unrelated reason is left in place and would be credited here.
  static String? reusedCreatorPubkeyFor(VideoEvent video) {
    final pubkey = video.inspiredByVideo?.creatorPubkey;
    return (pubkey != null && pubkey.isNotEmpty) ? pubkey : null;
  }

  /// The name to credit for [video]'s sound.
  ///
  /// [reusedCreatorPubkey] is the reused sound's creator, or null when the
  /// video has no reused sound. Callers pass it explicitly — a null must stay
  /// "no reused creator" so a video carrying inspired-by for an unrelated
  /// reason still credits its own author.
  ///
  /// [creatorProfile] is the profile of whoever that resolves to, so the
  /// generated-name fallbacks below are only reached before it loads.
  static String creatorNameFor({
    required VideoEvent video,
    required UserProfile? creatorProfile,
    required String? reusedCreatorPubkey,
  }) =>
      creatorProfile?.bestDisplayName ??
      (reusedCreatorPubkey != null
          ? UserProfile.defaultDisplayNameFor(reusedCreatorPubkey)
          : video.displayAuthorName ??
                UserProfile.generatedNameFor(video.pubkey));
}
