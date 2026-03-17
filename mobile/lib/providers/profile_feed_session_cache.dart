import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/state/video_feed_state.dart';

/// Session-scoped cache for the first page of profile feeds.
class ProfileFeedSessionCache {
  final Map<String, VideoFeedState> _snapshots = {};

  VideoFeedState? read(String pubkey) => _snapshots[pubkey];

  void write(String pubkey, VideoFeedState state) {
    _snapshots[pubkey] = state;
  }

  void clear(String pubkey) {
    _snapshots.remove(pubkey);
  }
}

final profileFeedSessionCacheProvider = Provider<ProfileFeedSessionCache>((
  ref,
) {
  return ProfileFeedSessionCache();
});
