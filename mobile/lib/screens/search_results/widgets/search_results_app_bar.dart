import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/search_filter_pill.dart';

/// App bar for the search results screen.
///
/// Owns the [TextEditingController] and [FocusNode] lifecycle. Dispatches
/// [VideoSearchQueryChanged] to [VideoSearchBloc] on text changes.
class SearchResultsAppBar extends StatefulWidget {
  const SearchResultsAppBar({required this.initialQuery, super.key});

  /// Pre-filled search text. If empty the field requests focus instead.
  final String initialQuery;

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
      context.read<ListSearchBloc>().add(ListSearchQueryChanged(query));
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
              semanticLabel: context.l10n.commonBack,
            ),
            Expanded(
              child: DivineSearchBar(
                controller: _controller,
                focusNode: _focusNode,
                hintText: context.l10n.exploreSearchHint,
                suffixIcon: const SearchFilterPill(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
