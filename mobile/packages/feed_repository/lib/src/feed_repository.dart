// ABOUTME: Abstract contract for resolving a ViewSource into a live video
// ABOUTME: feed. Implementations own pagination + filtering; callers pass a
// ABOUTME: ViewSource.

import 'package:feed_repository/src/view_source.dart';
import 'package:models/models.dart';

/// A lifecycle-stable source of truth for a video feed.
///
/// Replaces the per-caller `Stream<List<VideoEvent>>` that fullscreen surfaces
/// used to receive from whichever widget opened them. A [FeedRepository]
/// resolves a [ViewSource] into:
///
/// * a live, filtered list stream ([watchView]) — deletion / block / mute are
///   already applied at the boundary, so a source re-push can never
///   re-introduce a removed video;
/// * a pagination trigger ([loadMore]);
/// * a "can paginate further" stream ([watchHasMore]).
///
/// Implementations must be safe to subscribe to for the lifetime of the
/// consuming bloc — independent of whichever widget created the [ViewSource]
/// (see issue #3383).
abstract class FeedRepository {
  /// A live, filtered stream of the videos for [source].
  ///
  /// Emits the current list immediately on subscription and again whenever the
  /// underlying feed changes (new page, removal, blocklist sweep).
  Stream<List<VideoEvent>> watchView(ViewSource source);

  /// Requests the next page for [source], if the source paginates.
  ///
  /// A no-op for static sources (e.g. [SingleVideoViewSource],
  /// [VideoListViewSource]).
  Future<void> loadMore(ViewSource source);

  /// A stream of whether [source] can paginate further.
  ///
  /// Static sources emit a single `false`.
  Stream<bool> watchHasMore(ViewSource source);
}
