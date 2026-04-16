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

  /// Distance from the bottom edge (in logical pixels) at which loading
  /// is triggered.
  static const double _threshold = 200;

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

    final isNearBottom = paginationScrollController.positions.any(
      (position) => position.pixels >= position.maxScrollExtent - _threshold,
    );
    if (!isNearBottom) {
      return;
    }

    _pendingPaginationLoad = Future.sync(onLoadMore).whenComplete(() {
      _pendingPaginationLoad = null;
    });
  }
}
