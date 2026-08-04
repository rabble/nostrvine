// ABOUTME: Mixin that provides scroll-driven near-bottom pagination
// ABOUTME: Handles listener lifecycle and in-flight request deduplication

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Mixin that triggers [onLoadMore] when a scroll view nears the bottom.
///
/// Attach to any [State] (including [ConsumerState]) and override the three
/// abstract members. Call [initPagination] in [initState] and
/// [disposePagination] in [dispose].
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with ScrollPaginationMixin {
///   final _scrollController = ScrollController();
///
///   @override
///   ScrollController get paginationScrollController => _scrollController;
///
///   @override
///   bool canLoadMore() => hasMore && !isLoading;
///
///   @override
///   FutureOr<void> onLoadMore() => _fetchNextPage();
///
///   @override
///   void initState() {
///     super.initState();
///     initPagination();
///   }
///
///   @override
///   void dispose() {
///     disposePagination();
///     _scrollController.dispose();
///     super.dispose();
///   }
/// }
/// ```
mixin ScrollPaginationMixin<T extends StatefulWidget> on State<T> {
  /// The scroll controller to observe for near-bottom events.
  ScrollController get paginationScrollController;

  /// Whether a new page can be requested right now.
  ///
  /// Typically checks `hasMoreContent && !isLoadingMore`. Called on every
  /// scroll tick so keep it cheap (e.g. [context.read] is fine).
  bool canLoadMore();

  /// Loads the next page. The mixin guards against concurrent calls:
  /// while a returned [Future] is pending, subsequent scroll events are
  /// ignored.
  FutureOr<void> onLoadMore();

  /// How many viewports ahead of the bottom edge the next page is requested.
  ///
  /// Callers that also choose a page size must keep it comfortably above one
  /// viewport, or the prefetch fires again the moment the page lands and the
  /// list never leaves the loading state. `profileTabPageSize` in
  /// `lib/blocs/profile_shared/` is sized against this factor — revisit it if
  /// this changes.
  static const double _viewportPrefetchFactor = 1.5;

  /// Distance from the bottom edge (in logical pixels) at which [onLoadMore]
  /// is triggered.
  ///
  /// Defaults to [_viewportPrefetchFactor] viewports so the next page is
  /// requested well before the user reaches the bottom and is usually merged
  /// in by the time they scroll that far — keeping the loading-more indicator
  /// off screen. A fixed pixel distance is not enough: on a dense grid it is
  /// only a row or two, so the request starts when the user is already at the
  /// bottom. Called on every scroll tick, so keep overrides cheap.
  ///
  /// Only valid while [paginationScrollController] has clients, which the
  /// mixin guarantees at its own call site. Reads the first attached position
  /// rather than [ScrollController.position] because one controller can drive
  /// several viewports (profile tabs share the [PrimaryScrollController] of
  /// their [NestedScrollView]); siblings are the same height, so any of them
  /// answers the question.
  @protected
  double get paginationLoadMoreThreshold =>
      paginationScrollController.positions.first.viewportDimension *
      _viewportPrefetchFactor;

  Future<void>? _pendingPaginationLoad;

  /// Register the scroll listener. Call once from [initState], after the
  /// [paginationScrollController] is available.
  @protected
  void initPagination() {
    paginationScrollController.addListener(_handlePaginationScroll);
  }

  /// Unregister the scroll listener. Call from [dispose], before disposing
  /// the [paginationScrollController].
  @protected
  void disposePagination() {
    paginationScrollController.removeListener(_handlePaginationScroll);
  }

  void _handlePaginationScroll() {
    if (!paginationScrollController.hasClients) return;
    if (_pendingPaginationLoad != null) return;
    if (!canLoadMore()) return;

    final threshold = paginationLoadMoreThreshold;
    final isNearBottom = paginationScrollController.positions.any(
      (position) => position.pixels >= position.maxScrollExtent - threshold,
    );
    if (!isNearBottom) {
      return;
    }

    _pendingPaginationLoad = Future.sync(onLoadMore).whenComplete(() {
      _pendingPaginationLoad = null;
    });
  }
}
