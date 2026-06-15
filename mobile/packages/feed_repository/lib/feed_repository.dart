/// Lifecycle-stable abstraction over the app's video feeds.
///
/// This package provides:
/// - `ViewSource` - immutable descriptor of which feed a surface wants to view
/// - `FeedRepository` - resolves a `ViewSource` into a live, filtered stream
///
/// The concrete implementation that delegates to the app's existing feed
/// providers / blocs lives in the app layer (`mobile/lib`), because it needs
/// Riverpod / Flutter wiring that this Flutter-free package intentionally
/// avoids. See issue #3383.
library;

export 'src/feed_repository.dart';
export 'src/feed_repository_adapters.dart';
export 'src/view_source.dart';
