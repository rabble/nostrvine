// ABOUTME: Passive cache of community content-warning labels per video (#4771).
// ABOUTME: Prefetches crossed-threshold labels and exposes warn labels sync.

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/repositories/community_content_label_repository.dart';
import 'package:openvine/services/content_filter_service.dart';

/// Caches community-suggested content-warning labels per video and exposes
/// which of them should surface a warning for the current viewer.
///
/// Same shape as the sanctioned `OgVinerCacheService` per-key cache:
/// [prefetch] populates the cache in the background (bounded to videos the
/// UI actually asks about) and [warnLabelsFor] is a synchronous read used
/// during rendering. It is a [ChangeNotifier] because the feed must rebuild
/// (overlay + autoplay gate) when a background prefetch resolves with labels.
///
/// Community labels are advisory and unverified, so they only ever **warn**
/// (blur + "View Anyway"); they never hard-hide content. A label is dropped
/// only when the viewer has explicitly set it to [ContentFilterPreference.show].
class CommunityContentLabelService extends ChangeNotifier {
  /// Creates the service.
  ///
  /// [repository] is nullable so the app-level provider can hand over a live
  /// instance only once the signer-backed repository is ready; until then
  /// [prefetch] is a no-op.
  CommunityContentLabelService({
    required CommunityContentLabelRepository? repository,
    required ContentFilterService contentFilterService,
  }) : _repository = repository,
       _contentFilterService = contentFilterService;

  final CommunityContentLabelRepository? _repository;
  final ContentFilterService _contentFilterService;

  final Map<String, Set<String>> _cache = {};
  final Set<String> _inFlight = {};

  /// Maximum cached videos; oldest-inserted evicted first so a long session
  /// can't grow the map without bound.
  static const _cacheMax = 500;

  /// Fetches and caches the community-surfaced labels for [video], once.
  ///
  /// Idempotent: a video already cached or in flight is skipped, so this is
  /// safe to call on every render of a feed item.
  Future<void> prefetch(VideoEvent video) async {
    final repository = _repository;
    if (repository == null) return;
    final id = video.id;
    if (_cache.containsKey(id) || _inFlight.contains(id)) return;
    _inFlight.add(id);
    try {
      final labels = await repository.communityLabelsForVideo(video);
      if (_cache.length >= _cacheMax) {
        _cache.remove(_cache.keys.first);
      }
      _cache[id] = labels;
      // Only notify when something visible changed. Empty is the common
      // case while scrolling; notifying then would rebuild every mounted
      // feed item for nothing.
      if (labels.isNotEmpty) {
        notifyListeners();
      }
    } finally {
      _inFlight.remove(id);
    }
  }

  /// Community labels for [video] that should surface a warning for the
  /// current viewer.
  ///
  /// Returns the cached crossed-threshold labels minus any the viewer set to
  /// [ContentFilterPreference.show]. Empty until [prefetch] completes.
  Set<String> warnLabelsFor(VideoEvent video) {
    final labels = _cache[video.id];
    if (labels == null || labels.isEmpty) return const {};
    return labels.where((value) {
      final label = ContentLabel.fromValue(value);
      if (label == null) return true;
      return _contentFilterService.getPreference(label) !=
          ContentFilterPreference.show;
    }).toSet();
  }
}
