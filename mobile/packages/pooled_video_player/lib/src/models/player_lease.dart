import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pooled_video_player/src/controllers/player_pool.dart';

/// Priority levels for lease eviction.
///
/// Lower number = higher priority = keep longer.
class PlayerPriority {
  PlayerPriority._();

  /// Currently visible and playing - never evict.
  static const int current = 0;

  /// Detail page - almost never evict.
  static const int detail = 1;

  /// Preloaded adjacent video in the focused feed.
  static const int adjacentFocused = 10;

  /// Preloaded adjacent video in a background feed.
  static const int adjacentBackground = 20;

  /// Preloaded distant video.
  static const int distant = 30;
}

/// A transferable reference to a [PooledPlayer].
///
/// Enables seamless handoff of video players between contexts (e.g., from a
/// feed to a detail page and back) without interrupting playback.
///
/// The lease tracks:
/// - Which video it's playing ([videoId])
/// - Who currently owns it ([ownerId])
/// - Priority for eviction decisions ([priority])
class PlayerLease {
  /// Creates a player lease for the given pooled player and video.
  PlayerLease({
    required this.pooledPlayer,
    required this.videoId,
    required String ownerId,
    this.priority = PlayerPriority.distant,
  }) : _ownerId = ownerId,
       createdAt = DateTime.now();

  /// The underlying pooled player instance.
  final PooledPlayer pooledPlayer;

  /// The ID of the video this lease is playing.
  final String videoId;

  /// When this lease was created.
  final DateTime createdAt;

  /// Current owner ID (feed ID or detail page ID).
  String _ownerId;

  /// Gets the current owner of this lease.
  String get ownerId => _ownerId;

  /// Priority for eviction decisions.
  /// Lower values mean higher priority (keep longer).
  int priority;

  /// Convenience getter for the underlying player.
  Player get player => pooledPlayer.player;

  /// Convenience getter for the video controller.
  VideoController get videoController => pooledPlayer.videoController;

  /// Whether this lease is still valid (player not disposed).
  bool get isValid => !pooledPlayer.isDisposed;

  /// When the underlying player was last used.
  DateTime get lastUsed => pooledPlayer.lastUsed;

  /// Transfer ownership of this lease to a new owner.
  ///
  /// Used during handoff from feed to detail page or vice versa.
  void transferTo(String newOwnerId) {
    _ownerId = newOwnerId;
    pooledPlayer.lastUsed = DateTime.now();
  }

  @override
  String toString() {
    return 'PlayerLease(videoId: $videoId, ownerId: $_ownerId, '
        'priority: $priority, isValid: $isValid)';
  }
}
