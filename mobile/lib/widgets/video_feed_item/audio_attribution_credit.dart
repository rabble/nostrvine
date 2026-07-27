// ABOUTME: Shared helpers for unresolved audio attribution credit.
// ABOUTME: Keeps feed-row and metadata-sheet fallback credit logic in sync.

import 'package:models/models.dart';

/// Resolved display credit for an audio attribution fallback.
class AudioAttributionCredit {
  const AudioAttributionCredit({
    required this.creatorPubkey,
    required this.creatorName,
    required this.creditsReusedCreator,
  });

  final String creatorPubkey;
  final String creatorName;
  final bool creditsReusedCreator;
}

/// Shared credit selection for videos whose referenced sound cannot be fetched.
class UnresolvedAudioAttributionCredit {
  const UnresolvedAudioAttributionCredit._();

  /// The reused sound's original creator, carried via inspired-by when a sound
  /// selection auto-populated that field. Null means the best available credit
  /// is the video's author.
  static String? reusedCreatorPubkeyFor(VideoEvent video) {
    final pubkey = video.inspiredByVideo?.creatorPubkey;
    return (pubkey != null && pubkey.isNotEmpty) ? pubkey : null;
  }

  static AudioAttributionCredit resolve({
    required VideoEvent video,
    required UserProfile? creatorProfile,
    String? reusedCreatorPubkey,
  }) {
    final resolvedReusedCreatorPubkey =
        reusedCreatorPubkey ?? reusedCreatorPubkeyFor(video);
    final creatorPubkey = resolvedReusedCreatorPubkey ?? video.pubkey;
    final creatorName =
        creatorProfile?.bestDisplayName ??
        (resolvedReusedCreatorPubkey != null
            ? UserProfile.defaultDisplayNameFor(creatorPubkey)
            : video.displayAuthorName ??
                  UserProfile.generatedNameFor(video.pubkey));

    return AudioAttributionCredit(
      creatorPubkey: creatorPubkey,
      creatorName: creatorName,
      creditsReusedCreator: resolvedReusedCreatorPubkey != null,
    );
  }
}
