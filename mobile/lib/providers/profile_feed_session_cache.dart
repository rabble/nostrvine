import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
import 'package:openvine/state/video_feed_state.dart';

/// Session-scoped cache for the first page of profile feeds.
///
/// Uses a [LinkedHashMap] as an LRU cache with [maxEntries] capacity.
/// On [read], accessed entries are moved to the end (most-recently-used).
/// On [write], the oldest entry is evicted when capacity is exceeded.
class ProfileFeedSessionCache {
  /// Maximum number of profile snapshots to retain.
  static const int maxEntries = 25;

  final LinkedHashMap<String, VideoFeedState> _snapshots =
      LinkedHashMap<String, VideoFeedState>();

  /// Read a cached snapshot, promoting it to most-recently-used.
  VideoFeedState? read(String pubkey) {
    final value = _snapshots.remove(pubkey);
    if (value != null) {
      // Re-insert at the end (most recently used)
      _snapshots[pubkey] = value;
    }
    return value;
  }

  /// Write a snapshot, evicting the oldest entry if at capacity.
  void write(String pubkey, VideoFeedState state) {
    // Remove first so re-insert goes to the end
    _snapshots.remove(pubkey);
    if (_snapshots.length >= maxEntries) {
      _snapshots.remove(_snapshots.keys.first);
    }
    _snapshots[pubkey] = state;
  }

  void clear(String pubkey) {
    _snapshots.remove(pubkey);
  }

  /// Remove all cached snapshots (e.g. on logout).
  void clearAll() => _snapshots.clear();
}

final profileFeedSessionCacheProvider = Provider<ProfileFeedSessionCache>((
  ref,
) {
  final cache = ProfileFeedSessionCache();

  // Clear cached profile feeds when user logs out.
  ref.listen<AuthState>(currentAuthStateProvider, (previous, next) {
    if (next == AuthState.unauthenticated) {
      cache.clearAll();
    }
  });

  return cache;
});
