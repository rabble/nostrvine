import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';

/// App bar for the search results screen.
///
/// Owns the [TextEditingController] and [FocusNode] lifecycle. Dispatches
/// [VideoSearchQueryChanged] to [VideoSearchBloc] on text changes.
class SearchResultsAppBar extends StatefulWidget {
  const SearchResultsAppBar({
    required this.initialQuery,
    this.filterLabel,
    this.onFilterTap,
    super.key,
  });

  /// Pre-filled search text. If empty the field requests focus instead.
  final String initialQuery;

  /// Label shown in the trailing filter chip (e.g. "All", "People").
  final String? filterLabel;

  /// Called when the user taps the filter chip.
  final VoidCallback? onFilterTap;

  @override
  State<SearchResultsAppBar> createState() => _SearchResultsAppBarState();
}

class _SearchResultsAppBarState extends State<SearchResultsAppBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onSearchChanged);

    if (widget.initialQuery.isNotEmpty) {
      _controller.text = widget.initialQuery;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller
      ..removeListener(_onSearchChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = _controller.text;
      context.read<VideoSearchBloc>().add(VideoSearchQueryChanged(query));
      context.read<UserSearchBloc>().add(UserSearchQueryChanged(query));
      context.read<HashtagSearchBloc>().add(HashtagSearchQueryChanged(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 8,
          children: [
            DivineIconButton(
              icon: DivineIconName.caretLeft,
              type: DivineIconButtonType.secondary,
              size: DivineIconButtonSize.small,
              onPressed: () => Navigator.of(context).maybePop(),
              semanticLabel: 'Back',
            ),
            Expanded(
              child: DivineSearchBar(
                controller: _controller,
                focusNode: _focusNode,
                hintText: 'Search...',
              ),
            ),
            if (widget.filterLabel != null)
              _FilterChip(
                label: widget.filterLabel!,
                onTap: widget.onFilterTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: VineTheme.titleMediumFont(color: VineTheme.vineGreen),
            ),
          ),
        ),
      ),
    );
  }
}
