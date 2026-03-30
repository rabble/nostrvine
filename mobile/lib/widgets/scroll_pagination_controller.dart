import 'dart:async';

import 'package:flutter/widgets.dart';

typedef ScrollPaginationCallback = FutureOr<void> Function();
typedef CanLoadMoreCallback = bool Function();

/// Reusable near-bottom pagination trigger for scroll-driven feeds and lists.
class ScrollPaginationController {
  ScrollPaginationController({
    required ScrollController scrollController,
    required CanLoadMoreCallback canLoadMore,
    required ScrollPaginationCallback onLoadMore,
    this.threshold = 200,
  }) : _scrollController = scrollController,
       _canLoadMore = canLoadMore,
       _onLoadMore = onLoadMore {
    _scrollController.addListener(_handleScroll);
  }

  final ScrollController _scrollController;
  final CanLoadMoreCallback _canLoadMore;
  final ScrollPaginationCallback _onLoadMore;
  final double threshold;

  Future<void>? _pendingLoad;

  void dispose() {
    _scrollController.removeListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_pendingLoad != null) return;
    if (!_canLoadMore()) return;

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - threshold) {
      return;
    }

    _pendingLoad = Future.sync(_onLoadMore).whenComplete(() {
      _pendingLoad = null;
    });
  }
}
