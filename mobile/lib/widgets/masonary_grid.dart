// ABOUTME: Masonry/Pinterest-style grid layout widget with synchronized scrolling
// ABOUTME: Distributes children across columns with variable heights and linked scroll controllers

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

/// A masonry grid layout that displays children in columns with synchronized
/// scrolling.
///
/// Children are distributed evenly across columns, and each column can have
/// different heights based on its content. All columns scroll together as one.
class MasonryGrid extends StatefulWidget {
  /// Creates a masonry grid with the specified number of columns and children.
  const MasonryGrid({
    required this.columnCount,
    required this.children,
    this.itemAspectRatios,
    this.columnGap = 0.0,
    this.rowGap = 0.0,
    super.key,
  });

  /// The number of columns in the grid.
  final int columnCount;

  /// Horizontal gap between columns.
  final double columnGap;

  /// Vertical gap between items in a column.
  final double rowGap;

  /// The widgets to display in the grid.
  final List<Widget> children;

  /// Optional aspect ratios for each child widget (width/height).
  /// When provided, items are distributed to columns based on their heights
  /// to create a more balanced layout. If null, items are distributed evenly
  /// by count.
  final List<double>? itemAspectRatios;

  @override
  State<MasonryGrid> createState() => _MasonryGridState();
}

class _MasonryGridState extends State<MasonryGrid> {
  late LinkedScrollControllerGroup _controllers;
  late List<ScrollController> _scrollControllers;

  late List<double> helperRowHeight;
  late VoidCallback _scrollCallback;

  /// Cached column distribution to avoid recalculating on every build.
  late List<List<int>> _columnItems;

  @override
  void initState() {
    super.initState();

    // Calculate initial column distribution
    _columnItems = _distributeItemsToColumns();

    // Initialize linked scroll controller group for synchronized scrolling
    _controllers = LinkedScrollControllerGroup();

    // Initialize helper heights for each column
    // (used to equalize scroll extents)
    helperRowHeight = List.generate(widget.columnCount, (_) => 0.0);

    // Create individual scroll controllers for each column
    _scrollControllers = List.generate(
      widget.columnCount,
      (_) => _controllers.addAndGet(),
    );

    _scrollCallback = _calculateHelperRowHeights;

    // Listen to scroll changes across all linked controllers
    _controllers.addOffsetChangedListener(_scrollCallback);

    // Calculate initial heights after first frame when widgets are laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _calculateHelperRowHeights();
      }
    });
  }

  @override
  void didUpdateWidget(MasonryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recalculate distribution if children or aspect ratios changed
    if (oldWidget.children.length != widget.children.length ||
        !listEquals(widget.itemAspectRatios, oldWidget.itemAspectRatios)) {
      _columnItems = _distributeItemsToColumns();
    }
  }

  @override
  void dispose() {
    _controllers.removeOffsetChangedListener(_scrollCallback);

    for (final scrollController in _scrollControllers) {
      scrollController.dispose();
    }

    super.dispose();
  }

  void _calculateHelperRowHeights() {
    // Early return if all columns already have equal scroll extents
    final firstMaxExtent = _scrollControllers[0].position.maxScrollExtent;
    if (_scrollControllers.every(
      (c) => c.position.maxScrollExtent == firstMaxExtent,
    )) {
      return;
    }

    var hasReachedEnd = false;
    var maxContentOffset = 0.0;

    // Find the tallest column (excluding helper boxes) and check if scrolled
    // to end
    for (var i = 0; i < _scrollControllers.length; i++) {
      final maxExtent = _scrollControllers[i].position.maxScrollExtent;
      final contentOffset = maxExtent - helperRowHeight[i];

      if (contentOffset > maxContentOffset) {
        maxContentOffset = contentOffset;
      }

      if (_controllers.offset >= maxExtent) {
        hasReachedEnd = true;
      }
    }

    // Only recalculate heights when user has scrolled near or to the bottom
    // Check if within 100 pixels of the end to prepare helper boxes early
    const threshold = 100.0;
    final isNearEnd = _controllers.offset >= (firstMaxExtent - threshold);
    if (!hasReachedEnd && !isNearEnd) return;

    // Calculate required helper box heights to equalize all columns
    List<double>? updatedHeights;
    for (var i = 0; i < _scrollControllers.length; i++) {
      final maxExtent = _scrollControllers[i].position.maxScrollExtent;
      final contentOffset = maxExtent - helperRowHeight[i];
      final requiredHeight = maxContentOffset - contentOffset;

      if (requiredHeight > 0) {
        updatedHeights ??= List.filled(widget.columnCount, 0);
        updatedHeights[i] = requiredHeight;
      }
    }

    // Update state only if heights changed
    if (updatedHeights != null && mounted) {
      setState(() {
        helperRowHeight = updatedHeights!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: widget.columnGap,
      crossAxisAlignment: .start,
      children: List.generate(widget.columnCount, (columnIndex) {
        final items = _columnItems[columnIndex];
        // +1 for helper height box
        final itemCount = items.length + 1;

        return Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            controller: _scrollControllers[columnIndex],
            itemCount: itemCount,
            separatorBuilder: (_, _) => SizedBox(height: widget.rowGap),
            itemBuilder: (_, int itemIndex) {
              // Last item is a helper box to equalize column heights for
              // synchronized scrolling
              if (itemIndex == itemCount - 1) {
                return SizedBox(height: helperRowHeight[columnIndex]);
              }

              final childIndex = items[itemIndex];
              return widget.children[childIndex];
            },
          ),
        );
      }),
    );
  }

  /// Distributes items to columns by assigning each item to the
  /// shortest column.
  List<List<int>> _distributeItemsToColumns() {
    final itemCount = widget.children.length;
    final columnCount = widget.columnCount;

    // If no aspect ratios provided, use simple even distribution
    if (widget.itemAspectRatios == null) {
      final columns = List.generate(columnCount, (_) => <int>[]);
      for (var i = 0; i < itemCount; i++) {
        columns[i % columnCount].add(i);
      }
      return columns;
    }

    // Initialize empty lists for each column
    final columns = List.generate(columnCount, (_) => <int>[]);

    // Track total height of each column based on aspect ratios
    final columnHeights = List<double>.filled(columnCount, 0);

    // Distribute each item to the shortest column
    for (var i = 0; i < itemCount; i++) {
      // Find the column with minimum height
      var minHeight = columnHeights[0];
      var minIndex = 0;

      for (var j = 1; j < columnCount; j++) {
        if (columnHeights[j] < minHeight) {
          minHeight = columnHeights[j];
          minIndex = j;
        }
      }

      // Add item to shortest column
      columns[minIndex].add(i);

      // Add height based on aspect ratio (height = 1 / aspectRatio)
      // For example: 9:16 (0.5625) -> height ~1.78, 1:1 (1.0) -> height 1.0
      final aspectRatio = widget.itemAspectRatios![i];
      final itemHeight = 1.0 / aspectRatio;
      columnHeights[minIndex] +=
          itemHeight + (widget.rowGap / 100); // Add small gap contribution
    }

    return columns;
  }
}
